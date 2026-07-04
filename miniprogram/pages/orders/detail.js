const app = getApp()

Page({
  data: { orderId: null, order: null, loading: true, timeline: [] },

  onLoad(options) {
    this.setData({ orderId: options.id })
    this.loadOrderDetail(options.id)
  },

  async loadOrderDetail(id) {
    try {
      const res = await wx.cloud.callFunction({
        name: 'supabase_query',
        data: { action: 'select', table: 'orders', filters: { id }, limit: 1 }
      })
      const data = res.result && res.result.data && res.result.data[0] ? res.result.data[0] : null
      if (data) {
        this.setData({ order: this.formatOrder(data), loading: false })
        this.buildTimeline(data)
      } else { this.setMockDetail() }
    } catch (e) { this.setMockDetail() }
  },

  formatOrder(o) {
    const statusMap = {
      'pending': { text: '待处理', icon: '⏳' },
      'processing': { text: '制作中', icon: '🔥' },
      'completed': { text: '已完成', icon: '✅' },
      'cancelled': { text: '已取消', icon: '❌' }
    }
    const status = statusMap[o.status] || { text: o.status, icon: '📋' }
    let itemList = [], subtotal = 0
    if (Array.isArray(o.items)) {
      itemList = o.items.map(i => ({ name: i.name, qty: i.qty, price: i.price, subtotal: (i.price * i.qty).toFixed(2) }))
      subtotal = o.items.reduce((s, i) => s + i.price * i.qty, 0)
    }
    const time = new Date(o.created_at || Date.now())
    const timeText = `${time.getMonth() + 1}月${time.getDate()}日 ${String(time.getHours()).padStart(2,'0')}:${String(time.getMinutes()).padStart(2,'0')}`
    return { ...o, statusText: status.text, statusIcon: status.icon, itemList, subtotal: subtotal.toFixed(2), delivery_fee: o.delivery_fee || 0, discount: o.discount || 0, timeText }
  },

  buildTimeline(o) {
    const status = o.status
    const time = new Date(o.created_at || Date.now())
    const timeStr = `${time.getMonth() + 1}/${time.getDate()} ${String(time.getHours()).padStart(2,'0')}:${String(time.getMinutes()).padStart(2,'0')}`
    const steps = [
      { step: 1, title: '已下单', active: true, time: timeStr },
      { step: 2, title: '已接单', active: ['processing', 'completed'].includes(status), time: status !== 'pending' ? timeStr : '' },
      { step: 3, title: '制作中', active: ['processing', 'completed'].includes(status), time: status === 'processing' || status === 'completed' ? timeStr : '' },
      { step: 4, title: '已完成', active: status === 'completed', time: status === 'completed' ? timeStr : '' }
    ]
    this.setData({ timeline: steps })
  },

  async onAccept() { if (await this.updateStatus('processing')) { wx.showToast({ title: '已接单', icon: 'success' }); this.refreshDetail() } },
  async onReject() { if (await this.updateStatus('cancelled')) { wx.showToast({ title: '已拒单', icon: 'none' }); this.refreshDetail() } },
  async onComplete() { if (await this.updateStatus('completed')) { wx.showToast({ title: '已完成', icon: 'success' }); this.refreshDetail() } },

  async updateStatus(newStatus) {
    try {
      const res = await wx.cloud.callFunction({
        name: 'supabase_query',
        data: { action: 'update_order_status', table: 'orders', data: { order_id: this.data.orderId, new_status: newStatus } }
      })
      if (res.result && res.result.code === 0) {
        // TODO: 京东外卖API同步预留 - POST https://openapi.jddj.com/djapi/order/updateStatus
        return true
      }
      return false
    } catch (e) { wx.showToast({ title: '操作失败', icon: 'none' }); return false }
  },

  refreshDetail() { this.setData({ loading: true, order: null }); this.loadOrderDetail(this.data.orderId) },

  setMockDetail() {
    const mock = {
      id: this.data.orderId, order_no: 'WM001-' + this.data.orderId,
      customer_name: '张先生', customer_phone: '138****8888', address: '望月湖小区2栋301室',
      status: 'pending', created_at: new Date(Date.now() - 300000).toISOString(),
      items: [{ name: '猪油猛火炒饭', qty: 2, price: 15 }, { name: '番茄炒蛋', qty: 1, price: 12 }, { name: '紫菜蛋花汤', qty: 1, price: 8 }],
      total_amount: 50, delivery_fee: 3, discount: 0
    }
    this.setData({ order: this.formatOrder(mock), loading: false })
    this.buildTimeline(mock)
  }
})
