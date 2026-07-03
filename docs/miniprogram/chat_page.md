# 微信小程序 - AI对话页面完整代码

> 核心页面：支持4大智能体切换 + 语音输入 + Coze API调用

---

## 1. chat/index.wxml

```xml
<!-- pages/chat/index.wxml -->
<view class="chat-page">
  <!-- 智能体切换Tab -->
  <view class="agent-tabs">
    <view 
      class="agent-tab {{currentIndex === index ? 'active' : ''}}" 
      wx:for="{{agents}}" 
      wx:key="id" 
      data-index="{{index}}" 
      bindtap="onAgentSwitch"
    >
      <text class="tab-icon">{{item.icon}}</text>
      <text class="tab-name">{{item.name}}</text>
    </view>
  </view>

  <!-- 消息列表 -->
  <scroll-view 
    class="msg-list" 
    scroll-y 
    scroll-into-view="{{scrollToView}}" 
    scroll-with-animation
    enhanced
    show-scrollbar="{{false}}"
  >
    <!-- 欢迎语 -->
    <view class="welcome-card" wx:if="{{messages.length === 0}}">
      <view class="welcome-icon">{{currentAgent.icon}}</view>
      <text class="welcome-title">{{currentAgent.name}}</text>
      <text class="welcome-desc">{{currentAgent.desc}}</text>
      <text class="welcome-hint">下方输入框可直接打字或点击🎤语音输入</text>
    </view>

    <!-- 消息气泡 -->
    <view 
      class="msg-item {{msg.role === 'user' ? 'msg-user' : 'msg-ai'}}" 
      wx:for="{{messages}}" 
      wx:key="id"
      id="msg-{{item.id}}"
    >
      <!-- AI头像 -->
      <view class="msg-avatar" wx:if="{{msg.role === 'ai'}}">{{currentAgent.icon}}</view>
      
      <view class="msg-bubble {{msg.role === 'user' ? 'bubble-user' : 'bubble-ai'}}">
        <text class="msg-text">{{msg.content}}</text>
      </view>
      
      <!-- 用户头像 -->
      <view class="msg-avatar user-avatar" wx:if="{{msg.role === 'user'}}">我</view>
    </view>

    <!-- AI加载中 -->
    <view class="msg-item msg-ai" wx:if="{{loading}}" id="msg-loading">
      <view class="msg-avatar">{{currentAgent.icon}}</view>
      <view class="msg-bubble bubble-ai">
        <view class="loading-dots">
          <view class="dot"></view>
          <view class="dot"></view>
          <view class="dot"></view>
        </view>
      </view>
    </view>

    <!-- 底部留白 -->
    <view style="height: 40rpx;"></view>
  </scroll-view>

  <!-- 输入区 -->
  <view class="input-area">
    <!-- 键盘模式 -->
    <view class="input-keyboard" wx:if="{{inputMode === 'keyboard'}}">
      <view class="mode-switch" bindtap="toggleInputMode">
        <text class="switch-icon">🎤</text>
      </view>
      <input 
        class="text-input" 
        placeholder="输入消息..." 
        value="{{inputText}}" 
        bindinput="onInput" 
        confirm-type="send" 
        bindconfirm="onSend" 
        adjust-position="{{true}}"
        cursor-spacing="20"
      />
      <view 
        class="send-btn {{inputText ? 'active' : ''}}" 
        bindtap="onSend"
      >↑</view>
    </view>

    <!-- 语音模式 -->
    <view class="input-voice" wx:if="{{inputMode === 'voice'}}">
      <view class="mode-switch" bindtap="toggleInputMode">
        <text class="switch-icon">⌨️</text>
      </view>
      <view 
        class="voice-btn {{recording ? 'recording' : ''}} {{cancelMode ? 'cancel' : ''}}"
        bindtouchstart="onVoiceStart"
        bindtouchmove="onVoiceMove"
        bindtouchend="onVoiceEnd"
        bindtouchcancel="onVoiceEnd"
      >
        <text class="voice-btn-text">{{recording ? (cancelMode ? '松开取消' : '松开发送') : '按住说话'}}</text>
      </view>
    </view>

    <!-- 录音提示蒙层 -->
    <view class="record-overlay" wx:if="{{recording}}">
      <view class="record-mask">
        <view class="record-icon-wrap">
          <text class="record-icon">{{cancelMode ? '✕' : '🎙️'}}</text>
        </view>
        <text class="record-tip">{{cancelMode ? '松开取消发送' : '上滑取消，松开发送'}}</text>
        <view class="record-wave">
          <view class="wave-bar" wx:for="{{[1,2,3,4,5,6,7,8,9]}}" wx:key="*this" style="animation-delay: {{index * 0.1}}s"></view>
        </view>
      </view>
    </view>
  </view>
</view>
```

---

## 2. chat/index.js

```javascript
// pages/chat/index.js
const app = getApp()

// 获取同声传译插件
const plugin = requirePlugin('WechatSI')
const manager = plugin.getRecordRecognitionManager()

Page({
  data: {
    agents: [],
    currentIndex: 0,
    currentAgent: {},
    messages: [],
    inputText: '',
    inputMode: 'keyboard', // 'keyboard' | 'voice'
    loading: false,
    recording: false,
    cancelMode: false,
    scrollToView: '',
    conversationId: '',
    touchStartY: 0
  },

  // 消息ID自增
  msgId: 0,
  // 语音识别结果
  voiceResult: '',

  onLoad() {
    const agents = app.globalData.agents
    const index = app.globalData.currentAgentIndex || 0
    this.setData({
      agents,
      currentIndex: index,
      currentAgent: agents[index]
    })
    
    // 初始化语音识别回调
    this.initVoiceRecognition()
    
    // 加载历史消息
    this.loadHistory()
  },

  onShow() {
    // 如果从首页切换了智能体，同步更新
    const newIndex = app.globalData.currentAgentIndex
    if (newIndex !== this.data.currentIndex) {
      this.setData({ currentIndex: newIndex, currentAgent: this.data.agents[newIndex] })
      this.loadHistory()
    }
  },

  // ===== 语音识别初始化 =====
  initVoiceRecognition() {
    manager.onRecognize = (res) => {
      // 实时识别结果
      this.voiceResult = res.result || ''
    }
    
    manager.onStop = (res) => {
      // 识别结束
      const text = res.result || this.voiceResult
      this.voiceResult = ''
      
      if (this.data.cancelMode) {
        // 取消发送
        wx.showToast({ title: '已取消', icon: 'none', duration: 800 })
        return
      }
      
      if (text && text.trim()) {
        this.setData({ inputText: text })
        // 自动发送
        this.onSend()
      } else {
        wx.showToast({ title: '没听清，请重试', icon: 'none', duration: 1500 })
      }
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

  // ===== 智能体切换 =====
  onAgentSwitch(e) {
    const index = e.currentTarget.dataset.index
    if (index === this.data.currentIndex) return
    
    app.globalData.currentAgentIndex = index
    this.setData({
      currentIndex: index,
      currentAgent: this.data.agents[index],
      messages: [],
      conversationId: ''
    })
    this.loadHistory()
  },

  // ===== 输入模式切换 =====
  toggleInputMode() {
    this.setData({
      inputMode: this.data.inputMode === 'keyboard' ? 'voice' : 'keyboard'
    })
  },

  // ===== 语音输入控制 =====
  onVoiceStart(e) {
    this.setData({
      recording: true,
      cancelMode: false
    })
    this.touchStartY = e.touches[0].clientY
    this.voiceResult = ''
    
    // 开始语音识别
    manager.start({
      lang: 'zh_CN',
      duration: 60000 // 最长60秒
    })
  },

  onVoiceMove(e) {
    const moveY = e.touches[0].clientY
    const diff = this.touchStartY - moveY
    
    // 上滑超过40px触发取消
    if (diff > 40 && !this.data.cancelMode) {
      this.setData({ cancelMode: true })
    } else if (diff <= 40 && this.data.cancelMode) {
      this.setData({ cancelMode: false })
    }
  },

  onVoiceEnd() {
    if (!this.data.recording) return
    this.setData({ recording: false })
    manager.stop()
  },

  // ===== 文字输入 =====
  onInput(e) {
    this.setData({ inputText: e.detail.value })
  },

  // ===== 发送消息 =====
  async onSend() {
    const text = this.data.inputText.trim()
    if (!text || this.data.loading) return

    // 添加用户消息
    const userMsg = {
      id: ++this.msgId,
      role: 'user',
      content: text,
      time: Date.now()
    }
    this.setData({
      inputText: '',
      loading: true,
      [`messages[${this.data.messages.length}]`]: userMsg
    })
    this.scrollToBottom()

    try {
      // 调用云函数代理Coze API
      const res = await wx.cloud.callFunction({
        name: 'coze_proxy',
        data: {
          bot_id: this.data.currentAgent.botId,
          query: text,
          conversation_id: this.data.conversationId,
          store_code: app.globalData.storeCode
        }
      })

      const result = res.result || {}
      
      if (result.code === 0) {
        // 保存conversation_id
        if (result.conversation_id) {
          this.setData({ conversationId: result.conversation_id })
        }
        
        // 添加AI回复
        const aiMsg = {
          id: ++this.msgId,
          role: 'ai',
          content: result.answer || '收到，我理解了。',
          time: Date.now()
        }
        this.setData({
          loading: false,
          [`messages[${this.data.messages.length}]`]: aiMsg
        })
      } else {
        throw new Error(result.message || 'API调用失败')
      }
    } catch (err) {
      console.error('发送失败', err)
      const errMsg = {
        id: ++this.msgId,
        role: 'ai',
        content: '网络有点问题，请稍后重试 🔄',
        time: Date.now()
      }
      this.setData({
        loading: false,
        [`messages[${this.data.messages.length}]`]: errMsg
      })
    }
    
    this.scrollToBottom()
  },

  // ===== 加载历史消息 =====
  async loadHistory() {
    try {
      const res = await wx.cloud.callFunction({
        name: 'supabase_query',
        data: {
          action: 'select',
          table: 'chat_messages',
          filters: {
            store_code: app.globalData.storeCode,
            agent_id: this.data.currentAgent.id
          },
          order: 'created_at',
          ascending: true,
          limit: 20
        }
      })

      if (res.result && res.result.data) {
        const msgs = res.result.data.map(m => ({
          id: m.id || this.msgId++,
          role: m.role,
          content: m.content,
          time: new Date(m.created_at).getTime()
        }))
        this.setData({ messages: msgs })
        if (msgs.length > 0) {
          this.scrollToBottom()
        }
      }
    } catch (e) {
      // 表不存在或查询失败，静默处理
      console.log('历史消息加载失败', e)
    }
  },

  // ===== 滚动到底部 =====
  scrollToBottom() {
    setTimeout(() => {
      const lastId = this.data.messages.length > 0 
        ? `msg-${this.data.messages[this.data.messages.length - 1].id}` 
        : 'msg-loading'
      this.setData({ scrollToView: lastId })
    }, 100)
  }
})
```

---

## 3. chat/index.wxss

```css
/* pages/chat/index.wxss */
.chat-page {
  display: flex;
  flex-direction: column;
  height: 100vh;
  background: var(--bg-primary);
}

/* ===== 智能体切换Tab ===== */
.agent-tabs {
  display: flex;
  background: var(--bg-card);
  padding: 12rpx 8rpx;
  border-bottom: 1rpx solid rgba(255,255,255,0.06);
  flex-shrink: 0;
}

.agent-tab {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 16rpx 8rpx;
  border-radius: 12rpx;
  transition: all 0.2s;
}

.agent-tab.active {
  background: rgba(233,69,96,0.15);
}

.agent-tab.active .tab-name {
  color: var(--color-primary);
  font-weight: 600;
}

.tab-icon {
  font-size: 40rpx;
  margin-bottom: 4rpx;
}

.tab-name {
  font-size: 22rpx;
  color: var(--color-text-secondary);
}

/* ===== 消息列表 ===== */
.msg-list {
  flex: 1;
  padding: 24rpx;
  overflow-y: auto;
}

/* 欢迎卡片 */
.welcome-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 80rpx 32rpx;
}

.welcome-icon {
  font-size: 96rpx;
  margin-bottom: 24rpx;
}

.welcome-title {
  font-size: 36rpx;
  font-weight: 700;
  margin-bottom: 12rpx;
}

.welcome-desc {
  font-size: 26rpx;
  color: var(--color-text-secondary);
  text-align: center;
  margin-bottom: 32rpx;
}

.welcome-hint {
  font-size: 24rpx;
  color: var(--color-text-secondary);
  opacity: 0.6;
}

/* 消息项 */
.msg-item {
  display: flex;
  margin-bottom: 24rpx;
  align-items: flex-start;
}

.msg-user {
  flex-direction: row-reverse;
}

.msg-avatar {
  width: 64rpx;
  height: 64rpx;
  border-radius: 50%;
  background: var(--bg-input);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 32rpx;
  flex-shrink: 0;
}

.msg-user .msg-avatar {
  margin-left: 16rpx;
  background: rgba(233,69,96,0.2);
  font-size: 24rpx;
}

.msg-ai .msg-avatar {
  margin-right: 16rpx;
}

/* 消息气泡 */
.msg-bubble {
  max-width: 72%;
  padding: 20rpx 28rpx;
  border-radius: 20rpx;
  font-size: 28rpx;
  line-height: 1.6;
  word-break: break-all;
}

.bubble-ai {
  background: var(--bg-card);
  color: var(--color-text);
  border-top-left-radius: 4rpx;
}

.bubble-user {
  background: linear-gradient(135deg, #e94560, #c73650);
  color: #fff;
  border-top-right-radius: 4rpx;
}

.msg-text {
  white-space: pre-wrap;
}

/* 加载动画 */
.loading-dots {
  display: flex;
  gap: 8rpx;
  padding: 8rpx 0;
}

.loading-dots .dot {
  width: 12rpx;
  height: 12rpx;
  border-radius: 50%;
  background: var(--color-text-secondary);
  animation: dotBounce 1.4s infinite ease-in-out both;
}

.loading-dots .dot:nth-child(1) { animation-delay: -0.32s; }
.loading-dots .dot:nth-child(2) { animation-delay: -0.16s; }

@keyframes dotBounce {
  0%, 80%, 100% { transform: scale(0.6); opacity: 0.4; }
  40% { transform: scale(1); opacity: 1; }
}

/* ===== 输入区 ===== */
.input-area {
  flex-shrink: 0;
  background: var(--bg-card);
  padding: 16rpx 24rpx;
  padding-bottom: calc(16rpx + env(safe-area-inset-bottom));
  border-top: 1rpx solid rgba(255,255,255,0.06);
}

/* 键盘模式 */
.input-keyboard {
  display: flex;
  align-items: center;
  gap: 16rpx;
}

.mode-switch {
  width: 72rpx;
  height: 72rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.switch-icon {
  font-size: 40rpx;
}

.text-input {
  flex: 1;
  background: var(--bg-input);
  border: 1rpx solid rgba(255,255,255,0.08);
  border-radius: 36rpx;
  padding: 20rpx 28rpx;
  font-size: 28rpx;
  color: var(--color-text);
  height: 72rpx;
}

.send-btn {
  width: 72rpx;
  height: 72rpx;
  border-radius: 50%;
  background: var(--bg-input);
  color: var(--color-text-secondary);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 36rpx;
  font-weight: 700;
  flex-shrink: 0;
  transition: all 0.2s;
}

.send-btn.active {
  background: var(--color-primary);
  color: #fff;
  transform: scale(1.05);
}

/* 语音模式 */
.input-voice {
  display: flex;
  align-items: center;
  gap: 16rpx;
}

.voice-btn {
  flex: 1;
  height: 72rpx;
  background: var(--bg-input);
  border-radius: 36rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
  border: 1rpx solid rgba(255,255,255,0.08);
}

.voice-btn.recording {
  background: rgba(233,69,96,0.15);
  border-color: var(--color-primary);
}

.voice-btn.cancel {
  background: rgba(244,67,54,0.15);
  border-color: var(--color-danger);
}

.voice-btn-text {
  font-size: 28rpx;
  color: var(--color-text-secondary);
}

.voice-btn.recording .voice-btn-text {
  color: var(--color-primary);
  font-weight: 600;
}

.voice-btn.cancel .voice-btn-text {
  color: var(--color-danger);
}

/* 录音蒙层 */
.record-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 999;
  pointer-events: none;
}

.record-mask {
  display: flex;
  flex-direction: column;
  align-items: center;
  background: rgba(0,0,0,0.7);
  border-radius: 32rpx;
  padding: 48rpx 64rpx;
  backdrop-filter: blur(10rpx);
}

.record-icon-wrap {
  width: 120rpx;
  height: 120rpx;
  border-radius: 50%;
  background: rgba(255,255,255,0.1);
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 24rpx;
}

.record-icon {
  font-size: 64rpx;
}

.record-tip {
  font-size: 26rpx;
  color: #fff;
  margin-bottom: 24rpx;
}

/* 波形动画 */
.record-wave {
  display: flex;
  gap: 6rpx;
  align-items: center;
  height: 48rpx;
}

.wave-bar {
  width: 6rpx;
  height: 24rpx;
  background: var(--color-primary);
  border-radius: 3rpx;
  animation: waveAnim 0.8s infinite ease-in-out alternate;
}

@keyframes waveAnim {
  0% { height: 12rpx; opacity: 0.4; }
  100% { height: 48rpx; opacity: 1; }
}
```

---

## 4. 云函数 cloudfunctions/coze_proxy/index.js

```javascript
// cloudfunctions/coze_proxy/index.js
// Coze API 代理云函数 - 保护API Key不在前端暴露

const https = require('https')

// 从云函数环境变量读取
const COZE_API_TOKEN = process.env.COZE_API_TOKEN || 'sat_LvCuUkueRmeZlNEJFdSBf1qXCu61fPi32jkbpTWKpktSUkTVY6oH16QKqYLQNIfY'
const COZE_API_BASE = 'https://api.coze.cn'

/**
 * 调用Coze v3 chat接口
 * @param {string} botId - Bot ID
 * @param {string} query - 用户消息
 * @param {string} conversationId - 会话ID（可选）
 * @returns {Promise} - { code, answer, conversation_id }
 */
function callCoze(botId, query, conversationId) {
  return new Promise((resolve, reject) => {
    // 构建请求体
    const payload = JSON.stringify({
      bot_id: botId,
      user_id: 'miniprogram_wm001',
      stream: false,
      auto_save_history: true,
      additional_messages: [{
        role: 'user',
        content: query,
        content_type: 'text'
      }]
    })

    const path = conversationId 
      ? `/v1/chat?conversation_id=${conversationId}` 
      : '/v1/chat'

    const options = {
      hostname: 'api.coze.cn',
      port: 443,
      path: path,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${COZE_API_TOKEN}`,
        'Content-Length': Buffer.byteLength(payload)
      }
    }

    const req = https.request(options, (res) => {
      let data = ''
      res.on('data', (chunk) => { data += chunk })
      res.on('end', () => {
        try {
          const json = JSON.parse(data)
          if (json.code === 0 && json.data) {
            // Coze返回的是chat任务，需要轮询结果
            resolve({
              chatId: json.data.id,
              conversationId: json.data.conversation_id
            })
          } else {
            reject(new Error(json.msg || 'Coze API调用失败'))
          }
        } catch (e) {
          reject(new Error('解析Coze响应失败: ' + e.message))
        }
      })
    })

    req.on('error', (e) => reject(e))
    req.setTimeout(30000, () => {
      req.destroy()
      reject(new Error('请求超时'))
    })
    req.write(payload)
    req.end()
  })
}

/**
 * 轮询获取chat结果
 * @param {string} chatId - chat任务ID
 * @param {string} conversationId - 会话ID
 */
function pollChatResult(chatId, conversationId) {
  return new Promise((resolve, reject) => {
    let attempts = 0
    const maxAttempts = 30 // 最多轮询30次（约30秒）
    
    const poll = () => {
      attempts++
      if (attempts > maxAttempts) {
        reject(new Error('等待AI回复超时'))
        return
      }

      const path = `/v1/chat/retrieve?chat_id=${chatId}&conversation_id=${conversationId}`
      const options = {
        hostname: 'api.coze.cn',
        port: 443,
        path: path,
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${COZE_API_TOKEN}`
        }
      }

      const req = https.request(options, (res) => {
        let data = ''
        res.on('data', (chunk) => { data += chunk })
        res.on('end', () => {
          try {
            const json = JSON.parse(data)
            if (json.code === 0 && json.data) {
              if (json.data.status === 'completed') {
                // 获取消息列表
                fetchMessages(chatId, conversationId).then(resolve).catch(reject)
              } else if (json.data.status === 'failed') {
                reject(new Error('AI处理失败'))
              } else {
                // still in_progress, continue polling
                setTimeout(poll, 1000)
              }
            } else {
              reject(new Error(json.msg || '查询状态失败'))
            }
          } catch (e) {
            reject(new Error('解析状态响应失败'))
          }
        })
      })

      req.on('error', (e) => reject(e))
      req.setTimeout(10000, () => {
        req.destroy()
        reject(new Error('查询超时'))
      })
      req.end()
    }

    // 首次延迟1秒再开始轮询
    setTimeout(poll, 1000)
  })
}

/**
 * 获取消息列表
 */
function fetchMessages(chatId, conversationId) {
  return new Promise((resolve, reject) => {
    const path = `/v1/chat/message/list?chat_id=${chatId}&conversation_id=${conversationId}`
    const options = {
      hostname: 'api.coze.cn',
      port: 443,
      path: path,
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${COZE_API_TOKEN}`
      }
    }

    const req = https.request(options, (res) => {
      let data = ''
      res.on('data', (chunk) => { data += chunk })
      res.on('end', () => {
        try {
          const json = JSON.parse(data)
          if (json.code === 0 && json.data) {
            // 找到assistant的回复
            const assistantMsg = json.data.find(m => m.role === 'assistant' && m.type === 'answer')
            resolve({
              answer: assistantMsg ? assistantMsg.content : '收到',
              conversationId: conversationId
            })
          } else {
            reject(new Error(json.msg || '获取消息失败'))
          }
        } catch (e) {
          reject(new Error('解析消息失败'))
        }
      })
    })

    req.on('error', (e) => reject(e))
    req.setTimeout(10000, () => {
      req.destroy()
      reject(new Error('获取消息超时'))
    })
    req.end()
  })
}

// 云函数入口
exports.main = async (event, context) => {
  const { bot_id, query, conversation_id } = event

  if (!bot_id || !query) {
    return {
      code: -1,
      message: '缺少必要参数: bot_id, query'
    }
  }

  try {
    // 1. 发送消息
    const { chatId, conversationId } = await callCoze(bot_id, query, conversation_id)
    
    // 2. 轮询等待结果
    const result = await pollChatResult(chatId, conversationId)
    
    return {
      code: 0,
      answer: result.answer,
      conversation_id: result.conversationId
    }
  } catch (err) {
    console.error('coze_proxy error:', err)
    return {
      code: -1,
      message: err.message || '服务异常'
    }
  }
}
```

---

## 5. 云函数 cloudfunctions/coze_proxy/package.json

```json
{
  "name": "coze_proxy",
  "version": "1.0.0",
  "description": "Coze API代理云函数",
  "main": "index.js",
  "dependencies": {}
}
```

## 6. 云函数 cloudfunctions/coze_proxy/config.json

```json
{
  "permissions": {
    "openapi": []
  }
}
```

---

> **使用说明**：
> 1. 在微信公众平台后台「设置」→「第三方设置」→「插件管理」中添加「同声传译」插件
> 2. 部署 coze_proxy 云函数后，在云开发控制台设置环境变量 `COZE_API_TOKEN`
> 3. 真机调试时才能测试语音输入功能（开发者工具模拟器不支持）
> 4. 首次使用语音功能会弹出麦克风权限请求
