const app = getApp()

Page({
  data: {
    storeName: '',
    storeCode: '',
    overviewData: [
      { label: '今日营收', value: '¥1,820' },
      { label: '今日订单', value: '98' },
      { label: '毛利率', value: '65%' },
      { label: '预警项', value: '3' }
    ],
    quickActions: [
      { icon: '📊', name: '经营看板', url: '/pages/dashboard/index' },
      { icon: '📦', name: '订单管理', url: '/pages/orders/list' },
      { icon: '💬', name: 'AI对话', url: '/pages/chat/index' },
      { icon: '⚙️', name: '设置', url: '/pages/settings/index' }
    ],
    agents: []
  },

  onLoad() {
    const g = app.globalData
    this.setData({ storeName: g.storeName, storeCode: g.storeCode, agents: g.agents })
  },

  onShow() {
    this.loadOverview()
  },

  async loadOverview() {
    try {
      const res = await wx.cloud.callFunction({
        name: 'supabase_query',
        data: {
          action: 'select',
          table: 'daily_summary',
          filters: { store_code: app.globalData.storeCode },
          order: 'date',
          ascending: false,
          limit: 1
        }
      })
      if (res.result && res.result.data && res.result.data.length > 0) {
        const today = res.result.data[0]
        this.setData({
          'overviewData[0].value': '¥' + (today.total_revenue || 0),
          'overviewData[1].value': String(today.total_orders || 0),
          'overviewData[2].value': (today.gross_profit_rate || 0) + '%'
        })
      }
    } catch (e) {
      console.log('概览数据加载失败，使用Mock数据', e)
    }
  },

  onQuickTap(e) {
    const url = e.currentTarget.dataset.url
    if (url.includes('chat') || url.includes('dashboard')) {
      wx.switchTab({ url })
    } else {
      wx.navigateTo({ url })
    }
  },

  onAgentTap(e) {
    const index = e.currentTarget.dataset.index
    app.globalData.currentAgentIndex = index
    wx.switchTab({ url: '/pages/chat/index' })
  },

  onPullDownRefresh() {
    this.loadOverview().then(() => wx.stopPullDownRefresh())
  }
})
