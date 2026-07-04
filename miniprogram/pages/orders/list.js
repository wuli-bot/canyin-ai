const app = getApp()

Page({
  data: {
    currentTab: 'all',
    statusTabs: [
      { label: '全部', value: 'all', count: 0 },
      { label: '待处理', value: 'pending', count: 0 },
      { label: '进行中', value: 'processing', count: 0 },
      { label: '已完成', value: 'completed', count: 0 }
    ],
    orders: [],
    loading: false,
    hasMore: true,
    page: 0,
    pageSize: 10
  },

  onLoad() { this.loadOrders() },
  onShow() { if (this.data.orders.length > 0) this.refreshOrders() },
  onPullDownRefresh() { this.refreshOrders().then(() => wx.stopPullDownRefresh()) },
  onReachBottom() { if (this.data.hasMore && !this.data.loading) this.loadMore() },

  onTabChange(e) {
    this.setData({ currentTab: e.currentTarget.dataset.value, orders: [], page: 0, hasMore: true })
    this.loadOrders()
  },

  async refreshOrders() { this.setData({ page: 0, hasMore: true, orders: [] }); await this.loadOrders() },

  async loadOrders() {
    if (this.data.loading) return
    this.setData({ loading: true })
    const { currentTab, page, pageSize } = this.data
    const filters = { store_code: app.globalData.storeCode }
    if (currentTab !== 'all') filters.status = currentTab
    try {
      const res = await wx.cloud.callFunction({
        name: 'supabase_query',
        data: { action: 'select', table: 'orders', filters, order: 'created_at', ascending: false, limit: pageSize, offset: page * pageSize }
      })
      const data = res.result && res.result.data ? res.result.data : []
      const newOrders = data.map(o => this.formatOrder(o))
      this.setData({ orders: [...this.data.orders, ...newOrders], hasMore: data.length >= pageSize, loading: false })
    } catch (e) { this.setMockOrders() }
  },

  loadMore() { this.setData({ page: this.data.page + 1 }); this.loadOrders() },

  formatOrder(o) {
    const statusMap = {
      'pending': { text: '待处理', class: 'tag-warning' },
      'processing': { text: '进行中', class: 'tag-info' },
      'completed': { text: '已完成', class: 'tag-success' },
      'cancelled': { text: '已取消', class: 'tag-danger' }
    }
    const status = statusMap[o.status] || { text: o.status, class: 'tag-info' }
    let itemsText = ''
    if (Array.isArray(o.items)) {
      const items = o.items.slice(0, 3)
      itemsText = items.map(i => `${i.name}×${i.qty}`).join('，')
      if (o.items.length > 3) itemsText += `等${o.items.length}件`
    } else if (typeof o.items === 'string') { itemsText = o.items }
    const time = new Date(o.created_at || Date.now())
    const now = new Date(); const diff = now - time
    let timeText
    if (diff < 3600000) timeText = `${Math.floor(diff / 60000)}分钟前`
    else if (diff < 86400000) timeText = `${Math.floor(diff / 3600000)}小时前`
    else timeText = `${time.getMonth() + 1}/${time.getDate()}`
    return { id: o.id, order_no: o.order_no || ('#' + o.id), itemsText: itemsText || '—', total_amount: o.total_amount || 0, statusText: status.text, statusClass: status.class, timeText }
  },

  setMockOrders() {
    const mockData = [
      { id: 1, order_no: 'WM001-001', items: [{ name: '猪油炒饭', qty: 2 }, { name: '番茄炒蛋', qty: 1 }], total_amount: 45, status: 'pending', created_at: new Date(Date.now() - 300000).toISOString() },
      { id: 2, order_no: 'WM001-002', items: [{ name: '辣椒炒肉', qty: 1 }, { name: '紫菜蛋汤', qty: 2 }], total_amount: 38, status: 'processing', created_at: new Date(Date.now() - 1800000).toISOString() },
      { id: 3, order_no: 'WM001-003', items: [{ name: '猪油炒饭', qty: 3 }, { name: '蒜蓉青菜', qty: 1 }, { name: '番茄炒蛋', qty: 1 }, { name: '紫菜蛋汤', qty: 1 }], total_amount: 72, status: 'completed', created_at: new Date(Date.now() - 7200000).toISOString() }
    ]
    this.setData({ orders: mockData.map(o => this.formatOrder(o)), loading: false, hasMore: false })
  },

  onOrderTap(e) { wx.navigateTo({ url: `/pages/orders/detail?id=${e.currentTarget.dataset.id}` }) }
})
