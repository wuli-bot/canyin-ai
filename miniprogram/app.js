// app.js - 餐饮AI店长小程序入口
App({
  globalData: {
    supabaseUrl: 'https://vovzgflfdwngfuqnxjc.supabase.co',
    supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvdnpnZmxmZHduZ2Z1cW54amMiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTc4MTU5ODQ5NiwiZXhwIjoyMDk3MTc0NDk2fQ.p8e3LcWgBqWxQ3jYk7mN2vR4sT8uY6zA9bC1dE5fG3h',
    storeCode: 'WM001',
    storeName: '望月湖店',
    agents: [
      { id: 'boss', name: '成本核算', botId: '7651922196432338995', icon: '💰', desc: '菜品成本、毛利率、定价分析' },
      { id: 'review', name: '差评处理', botId: '7651944084466794550', icon: '📝', desc: '差评回复、预警、话术' },
      { id: 'traffic', name: '私域引流', botId: '7651952126398054435', icon: '🌊', desc: '加微信、社群运营、复购' },
      { id: 'service', name: '小哇客服', botId: '7651953305891405870', icon: '🤖', desc: '智能客服问答' }
    ],
    currentAgentIndex: 0,
    cloudEnv: 'canyin-ai',
    userInfo: null
  },

  onLaunch() {
    if (!wx.cloud) {
      console.error('请使用 2.2.3 或以上的基础库以使用云能力')
    } else {
      wx.cloud.init({
        env: this.globalData.cloudEnv,
        traceUser: true
      })
    }
    const sysInfo = wx.getWindowInfo()
    this.globalData.statusBarHeight = sysInfo.statusBarHeight
    this.globalData.windowHeight = sysInfo.windowHeight
    this.globalData.windowWidth = sysInfo.windowWidth

    const updateManager = wx.getUpdateManager()
    updateManager.onUpdateReady(() => {
      wx.showModal({
        title: '更新提示',
        content: '新版本已就绪，是否重启应用？',
        success(res) {
          if (res.confirm) updateManager.applyUpdate()
        }
      })
    })
  }
})
