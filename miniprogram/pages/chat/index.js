const app = getApp()
let plugin = null
let manager = null
try {
  plugin = requirePlugin('WechatSI')
  manager = plugin.getRecordRecognitionManager()
} catch (e) {
  console.warn('同声传译插件未安装，语音功能暂不可用。请在微信公众平台后台添加插件后使用。')
}

Page({
  data: {
    agents: [],
    currentIndex: 0,
    currentAgent: {},
    messages: [],
    inputText: '',
    inputMode: 'keyboard',
    loading: false,
    recording: false,
    cancelMode: false,
    scrollToView: '',
    conversationId: '',
    touchStartY: 0
  },

  msgId: 0,
  voiceResult: '',

  onLoad() {
    const agents = app.globalData.agents
    const index = app.globalData.currentAgentIndex || 0
    this.setData({ agents, currentIndex: index, currentAgent: agents[index] })
    this.initVoiceRecognition()
  },

  onShow() {
    const newIndex = app.globalData.currentAgentIndex
    if (newIndex !== this.data.currentIndex) {
      this.setData({ currentIndex: newIndex, currentAgent: this.data.agents[newIndex], messages: [], conversationId: '' })
    }
  },

  initVoiceRecognition() {
    if (!manager) {
      console.warn('语音识别管理器未初始化')
      return
    }
    manager.onRecognize = (res) => { this.voiceResult = res.result || '' }
    manager.onStop = (res) => {
      const text = res.result || this.voiceResult
      this.voiceResult = ''
      if (this.data.cancelMode) { wx.showToast({ title: '已取消', icon: 'none', duration: 800 }); return }
      if (text && text.trim()) { this.setData({ inputText: text }); this.onSend() }
      else { wx.showToast({ title: '没听清，请重试', icon: 'none', duration: 1500 }) }
    }
    manager.onError = (res) => {
      console.error('语音识别错误', res)
      this.setData({ recording: false, cancelMode: false })
      let msg = '语音识别失败'
      if (res.retcode === -30003) msg = '麦克风权限被拒绝，请前往设置开启'
      else if (res.retcode === -30002) msg = '录音太短'
      wx.showToast({ title: msg, icon: 'none', duration: 2000 })
    }
  },

  onAgentSwitch(e) {
    const index = e.currentTarget.dataset.index
    if (index === this.data.currentIndex) return
    app.globalData.currentAgentIndex = index
    this.setData({ currentIndex: index, currentAgent: this.data.agents[index], messages: [], conversationId: '' })
  },

  toggleInputMode() {
    this.setData({ inputMode: this.data.inputMode === 'keyboard' ? 'voice' : 'keyboard' })
  },

  onVoiceStart(e) {
    if (!manager) {
      wx.showToast({ title: '语音插件未安装，请先用文字输入', icon: 'none', duration: 2000 })
      return
    }
    this.setData({ recording: true, cancelMode: false })
    this.touchStartY = e.touches[0].clientY
    this.voiceResult = ''
    manager.start({ lang: 'zh_CN', duration: 60000 })
  },

  onVoiceMove(e) {
    const diff = this.touchStartY - e.touches[0].clientY
    if (diff > 40 && !this.data.cancelMode) this.setData({ cancelMode: true })
    else if (diff <= 40 && this.data.cancelMode) this.setData({ cancelMode: false })
  },

  onVoiceEnd() {
    if (!this.data.recording) return
    this.setData({ recording: false })
    if (manager) manager.stop()
  },

  onInput(e) { this.setData({ inputText: e.detail.value }) },

  async onSend() {
    const text = this.data.inputText.trim()
    if (!text || this.data.loading) return
    const userMsg = { id: ++this.msgId, role: 'user', content: text, time: Date.now() }
    this.setData({ inputText: '', loading: true, [`messages[${this.data.messages.length}]`]: userMsg })
    this.scrollToBottom()
    try {
      const res = await wx.cloud.callFunction({
        name: 'coze_proxy',
        data: { bot_id: this.data.currentAgent.botId, query: text, conversation_id: this.data.conversationId, store_code: app.globalData.storeCode }
      })
      const result = res.result || {}
      if (result.code === 0) {
        if (result.conversation_id) this.setData({ conversationId: result.conversation_id })
        const aiMsg = { id: ++this.msgId, role: 'ai', content: result.answer || '收到，我理解了。', time: Date.now() }
        this.setData({ loading: false, [`messages[${this.data.messages.length}]`]: aiMsg })
      } else { throw new Error(result.message || 'API调用失败') }
    } catch (err) {
      console.error('发送失败', err)
      const errMsg = { id: ++this.msgId, role: 'ai', content: '网络有点问题，请稍后重试 🔄', time: Date.now() }
      this.setData({ loading: false, [`messages[${this.data.messages.length}]`]: errMsg })
    }
    this.scrollToBottom()
  },

  scrollToBottom() {
    setTimeout(() => {
      const lastId = this.data.messages.length > 0 ? `msg-${this.data.messages[this.data.messages.length - 1].id}` : 'msg-loading'
      this.setData({ scrollToView: lastId })
    }, 100)
  }
})
