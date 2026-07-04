const app = getApp()

Page({
  data: {
    dateRange: 'today',
    dateDays: 1,
    dateOptions: [
      { label: '今日', value: 'today' },
      { label: '昨日', value: 'yesterday' },
      { label: '近7天', value: 'week' },
      { label: '近30天', value: 'month' }
    ],
    metrics: { revenue: '0', orders: '0', profitRate: '0', alertCount: '0', revenueChange: 0, ordersChange: 0 },
    trendData: [],
    alerts: [],
    quickActions: [
      { icon: '💰', name: '成本核算', desc: '查菜品利润、定价建议', agentIndex: 0 },
      { icon: '📝', name: '差评处理', desc: '回复差评、预警分析', agentIndex: 1 },
      { icon: '🌊', name: '私域引流', desc: '加微信、社群运营', agentIndex: 2 }
    ]
  },

  onLoad() { this.loadDashboard() },
  onPullDownRefresh() { this.loadDashboard().then(() => wx.stopPullDownRefresh()) },

  onDateChange(e) {
    this.setData({ dateRange: e.currentTarget.dataset.value })
    this.loadDashboard()
  },

  async loadDashboard() {
    await Promise.all([this.loadMetrics(), this.loadTrend(), this.loadAlerts()])
  },

  async loadMetrics() {
    const { dateRange } = this.getDateFilters()
    try {
      const res = await wx.cloud.callFunction({
        name: 'supabase_query',
        data: { action: 'select', table: 'daily_summary', filters: { store_code: app.globalData.storeCode, ...dateRange }, order: 'date', ascending: false, limit: 30 }
      })
      const data = res.result && res.result.data ? res.result.data : []
      if (data.length === 0) {
        this.setData({ metrics: { revenue: '1,820', orders: '98', profitRate: '65', alertCount: '3', revenueChange: 12, ordersChange: 8 } })
        return
      }
      const totalRevenue = data.reduce((s, d) => s + (d.total_revenue || 0), 0)
      const totalOrders = data.reduce((s, d) => s + (d.total_orders || 0), 0)
      const avgProfit = data.reduce((s, d) => s + (d.gross_profit_rate || 0), 0) / data.length
      let revenueChange = 0, ordersChange = 0
      if (data.length >= 2) {
        revenueChange = Math.round((data[0].total_revenue - data[1].total_revenue) / data[1].total_revenue * 100) || 0
        ordersChange = Math.round((data[0].total_orders - data[1].total_orders) / data[1].total_orders * 100) || 0
      }
      this.setData({ metrics: { revenue: this.formatNum(totalRevenue), orders: String(totalOrders), profitRate: String(Math.round(avgProfit)), alertCount: '-', revenueChange, ordersChange } })
    } catch (e) {
      this.setData({ metrics: { revenue: '1,820', orders: '98', profitRate: '65', alertCount: '3', revenueChange: 12, ordersChange: 8 } })
    }
  },

  async loadTrend() {
    const { dateRange } = this.getDateFilters()
    try {
      const res = await wx.cloud.callFunction({
        name: 'supabase_query',
        data: { action: 'select', table: 'daily_summary', filters: { store_code: app.globalData.storeCode, ...dateRange }, order: 'date', ascending: true, limit: 30 }
      })
      const data = res.result && res.result.data ? res.result.data : []
      if (data.length === 0) { this.setMockTrend(); return }
      const maxRevenue = Math.max(...data.map(d => d.total_revenue || 0), 1)
      const trendData = data.map(d => {
        const date = new Date(d.date)
        return { date: d.date, value: d.total_revenue || 0, percent: Math.round((d.total_revenue || 0) / maxRevenue * 100), shortDate: `${date.getMonth() + 1}/${date.getDate()}` }
      })
      this.setData({ trendData })
    } catch (e) { this.setMockTrend() }
  },

  async loadAlerts() {
    try {
      const res = await wx.cloud.callFunction({
        name: 'supabase_query',
        data: { action: 'select', table: 'inventory', filters: { store_code: app.globalData.storeCode }, order: 'quantity', ascending: true, limit: 10 }
      })
      const data = res.result && res.result.data ? res.result.data : []
      if (data.length === 0) { this.setMockAlerts(); return }
      const alerts = data.filter(d => d.quantity <= (d.min_stock || 999)).map(d => ({
        id: d.id, item_name: d.item_name, quantity: d.quantity, unit: d.unit || '', min_stock: d.min_stock,
        status: d.quantity <= (d.min_stock * 0.5 || 0) ? 'critical' : 'low', ratio: Math.round((d.quantity / (d.min_stock || 1)) * 100)
      }))
      this.setData({ alerts, 'metrics.alertCount': String(alerts.length) })
    } catch (e) { this.setMockAlerts() }
  },

  setMockTrend() {
    const now = new Date(); const trendData = []
    for (let i = 6; i >= 0; i--) {
      const d = new Date(now.getTime() - i * 86400000)
      const revenue = Math.round(1500 + Math.random() * 800)
      trendData.push({ date: d.toISOString().slice(0, 10), value: revenue, percent: Math.round(revenue / 2500 * 100), shortDate: `${d.getMonth() + 1}/${d.getDate()}` })
    }
    this.setData({ trendData })
  },

  setMockAlerts() {
    this.setData({ alerts: [
      { id: 1, item_name: '食用油', quantity: 3, unit: '桶', min_stock: 10, status: 'critical', ratio: 30 },
      { id: 2, item_name: '鸡蛋', quantity: 5, unit: '板', min_stock: 15, status: 'critical', ratio: 33 },
      { id: 3, item_name: '葱花', quantity: 2, unit: '斤', min_stock: 5, status: 'low', ratio: 40 }
    ], 'metrics.alertCount': '3' })
  },

  getDateFilters() {
    const { dateRange } = this.data; const now = new Date()
    let start, end, days
    end = now.toISOString().slice(0, 10)
    switch (dateRange) {
      case 'today': start = end; days = 1; break
      case 'yesterday': {
        const y = new Date(now.getTime() - 86400000)
        start = y.toISOString().slice(0, 10)
        end = start
        days = 1
        break
      }
      case 'week': start = new Date(now.getTime() - 7 * 86400000).toISOString().slice(0, 10); days = 7; break
      case 'month': start = new Date(now.getTime() - 30 * 86400000).toISOString().slice(0, 10); days = 30; break
    }
    this.setData({ dateDays: days })
    return { dateRange: { start_date: start, end_date: end } }
  },

  formatNum(n) { if (n >= 10000) return (n / 10000).toFixed(1) + '万'; return n.toLocaleString('zh-CN') },
  goAlerts() { wx.showToast({ title: '预警详情（开发中）', icon: 'none' }) },
  onQuickTap(e) {
    app.globalData.currentAgentIndex = e.currentTarget.dataset.agent
    wx.switchTab({ url: '/pages/chat/index' })
  }
})
