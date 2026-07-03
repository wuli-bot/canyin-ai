# 微信小程序 - 订单管理页面完整代码

> 订单列表 + 订单详情 + 状态更新，京东外卖API预留接口

---

## 1. orders/list.wxml

```xml
<!-- pages/orders/list.wxml -->
<view class="container">
  <!-- 状态Tab -->
  <view class="status-tabs">
    <view 
      class="status-tab {{currentTab === item.value ? 'active' : ''}}" 
      wx:for="{{statusTabs}}" 
      wx:key="value" 
      data-value="{{item.value}}" 
      bindtap="onTabChange"
    >
      <text>{{item.label}}</text>
      <text class="tab-count" wx:if="{{item.count > 0}}">{{item.count}}</text>
    </view>
  </view>

  <!-- 订单列表 -->
  <view class="order-list" wx:if="{{orders.length > 0}}">
    <view 
      class="order-card card" 
      wx:for="{{orders}}" 
      wx:key="id" 
      data-id="{{item.id}}" 
      bindtap="onOrderTap"
    >
      <view class="flex-between">
        <text class="order-no text-small text-secondary">单号：{{item.order_no}}</text>
        <text class="tag {{item.statusClass}}">{{item.statusText}}</text>
      </view>
      <view class="order-items">
        <text class="order-items-text">{{item.itemsText}}</text>
      </view>
      <view class="flex-between">
        <text class="order-time text-small text-secondary">{{item.timeText}}</text>
        <text class="order-amount">¥{{item.total_amount}}</text>
      </view>
    </view>
  </view>

  <!-- 空状态 -->
  <view class="empty-state" wx:if="{{orders.length === 0 && !loading}}">
    <text class="empty-icon">📦</text>
    <text class="empty-text">{{currentTab === 'all' ? '暂无订单' : '暂无' + currentTabText + '订单'}}</text>
  </view>

  <!-- 加载中 -->
  <view class="loading-more" wx:if="{{loading}}">
    <view class="loading-dots">
      <view class="dot"></view>
      <view class="dot"></view>
      <view class="dot"></view>
    </view>
  </view>

  <!-- 上拉加载更多 -->
  <view class="load-more" wx:if="{{hasMore && orders.length > 0 && !loading}}" bindtap="loadMore">
    <text class="text-secondary text-small">上拉加载更多</text>
  </view>
  
  <view class="no-more" wx:if="{{!hasMore && orders.length > 0}}">
    <text class="text-secondary text-small">没有更多了</text>
  </view>
</view>
```

---

## 2. orders/list.js

```javascript
// pages/orders/list.js
const app = getApp()

Page({
  data: {
    currentTab: 'all',
    currentTabText: '',
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

  onLoad() {
    this.loadOrders()
  },

  onShow() {
    // 从详情页返回时刷新
    if (this.data.orders.length > 0) {
      this.refreshOrders()
    }
  },

  onPullDownRefresh() {
    this.refreshOrders().then(() => wx.stopPullDownRefresh())
  },

  onReachBottom() {
    if (this.data.hasMore && !this.data.loading) {
      this.loadMore()
    }
  },

  // Tab切换
  onTabChange(e) {
    const value = e.currentTarget.dataset.value
    this.setData({ currentTab: value, orders: [], page: 0, hasMore: true })
    
    const tab = this.data.statusTabs.find(t => t.value === value)
    this.setData({ currentTabText: tab ? tab.label : '' })
    
    this.loadOrders()
  },

  // 刷新订单
  async refreshOrders() {
    this.setData({ page: 0, hasMore: true, orders: [] })
    await this.loadOrders()
  },

  // 加载订单
  async loadOrders() {
    if (this.data.loading) return
    this.setData({ loading: true })

    const { currentTab, page, pageSize } = this.data
    const offset = page * pageSize

    const filters = { store_code: app.globalData.storeCode }
    if (currentTab !== 'all') {
      filters.status = currentTab
    }

    try {
      const res = await wx.cloud.callFunction({
        name: 'supabase_query',
        data: {
          action: 'select',
          table: 'orders',
          filters,
          order: 'created_at',
          ascending: false,
          limit: pageSize,
          offset
        }
      })

      const data = res.result && res.result.data ? res.result.data : []
      const newOrders = data.map(o => this.formatOrder(o))
      
      this.setData({
        orders: [...this.data.orders, ...newOrders],
        hasMore: data.length >= pageSize,
        loading: false
      })

      // 加载各状态计数
      this.loadStatusCounts()
    } catch (e) {
      console.log('订单加载失败，使用Mock数据', e)
      this.setMockOrders()
    }
  },

  // 加载更多
  loadMore() {
    this.setData({ page: this.data.page + 1 })
    this.loadOrders()
  },

  // 加载状态计数
  async loadStatusCounts() {
    const statusList = ['pending', 'processing', 'completed']
    const counts = {}
    
    for (const status of statusList) {
      try {
        const res = await wx.cloud.callFunction({
          name: 'supabase_query',
          data: {
            action: 'count',
            table: 'orders',
            filters: { store_code: app.globalData.storeCode, status }
          }
        })
        const count = res.result && res.result[0] ? res.result[0].count : 0
        counts[status] = count
      } catch (e) {
        counts[status] = 0
      }
    }

    this.setData({
      'statusTabs[0].count': (counts.pending || 0) + (counts.processing || 0) + (counts.completed || 0),
      'statusTabs[1].count': counts.pending || 0,
      'statusTabs[2].count': counts.processing || 0,
      'statusTabs[3].count': counts.completed || 0
    })
  },

  // 格式化订单
  formatOrder(o) {
    const statusMap = {
      'pending': { text: '待处理', class: 'tag-warning' },
      'processing': { text: '进行中', class: 'tag-info' },
      'completed': { text: '已完成', class: 'tag-success' },
      'cancelled': { text: '已取消', class: 'tag-danger' }
    }
    const status = statusMap[o.status] || { text: o.status, class: 'tag-info' }
    
    // 格式化菜品列表
    let itemsText = ''
    if (Array.isArray(o.items)) {
      const items = o.items.slice(0, 3)
      itemsText = items.map(i => `${i.name}×${i.qty}`).join('，')
      if (o.items.length > 3) itemsText += `等${o.items.length}件`
    } else if (typeof o.items === 'string') {
      itemsText = o.items
    }

    // 格式化时间
    const time = new Date(o.created_at || Date.now())
    const now = new Date()
    const diff = now - time
    let timeText
    if (diff < 3600000) timeText = `${Math.floor(diff / 60000)}分钟前`
    else if (diff < 86400000) timeText = `${Math.floor(diff / 3600000)}小时前`
    else timeText = `${time.getMonth() + 1}/${time.getDate()}`

    return {
      id: o.id,
      order_no: o.order_no || ('#' + o.id),
      itemsText: itemsText || '—',
      total_amount: o.total_amount || 0,
      statusText: status.text,
      statusClass: status.class,
      timeText
    }
  },

  // Mock订单数据
  setMockOrders() {
    const mockData = [
      { id: 1, order_no: 'WM001-001', items: [{ name: '猪油炒饭', qty: 2 }, { name: '番茄炒蛋', qty: 1 }], total_amount: 45, status: 'pending', created_at: new Date(Date.now() - 300000).toISOString() },
      { id: 2, order_no: 'WM001-002', items: [{ name: '辣椒炒肉', qty: 1 }, { name: '紫菜蛋汤', qty: 2 }], total_amount: 38, status: 'processing', created_at: new Date(Date.now() - 1800000).toISOString() },
      { id: 3, order_no: 'WM001-003', items: [{ name: '猪油炒饭', qty: 3 }, { name: '蒜蓉青菜', qty: 1 }, { name: '番茄炒蛋', qty: 1 }, { name: '紫菜蛋汤', qty: 1 }], total_amount: 72, status: 'completed', created_at: new Date(Date.now() - 7200000).toISOString() }
    ]
    const orders = mockData.map(o => this.formatOrder(o))
    this.setData({ orders, loading: false, hasMore: false })
  },

  // 点击订单
  onOrderTap(e) {
    const id = e.currentTarget.dataset.id
    wx.navigateTo({ url: `/pages/orders/detail?id=${id}` })
  }
})
```

---

## 3. orders/list.wxss

```css
/* pages/orders/list.wxss */

/* 状态Tab */
.status-tabs {
  display: flex;
  background: var(--bg-card);
  border-radius: var(--radius-md);
  padding: 8rpx;
  margin-bottom: 24rpx;
}

.status-tab {
  flex: 1;
  text-align: center;
  padding: 16rpx 0;
  font-size: 26rpx;
  color: var(--color-text-secondary);
  border-radius: 24rpx;
  transition: all 0.2s;
  position: relative;
}

.status-tab.active {
  background: var(--color-primary);
  color: #fff;
  font-weight: 600;
}

.tab-count {
  display: inline-block;
  background: rgba(255,255,255,0.2);
  color: #fff;
  font-size: 20rpx;
  padding: 2rpx 10rpx;
  border-radius: 16rpx;
  margin-left: 4rpx;
  min-width: 28rpx;
}

.status-tab:not(.active) .tab-count {
  background: rgba(233,69,96,0.15);
  color: var(--color-primary);
}

/* 订单卡片 */
.order-card {
  margin-bottom: 16rpx;
  padding: 24rpx;
}

.order-no {
  font-family: monospace;
}

.order-items {
  margin: 16rpx 0;
}

.order-items-text {
  font-size: 28rpx;
  color: var(--color-text);
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.order-time {
  margin-top: 4rpx;
}

.order-amount {
  font-size: 36rpx;
  font-weight: 700;
  color: var(--color-primary);
}

/* 加载更多 */
.load-more, .no-more, .loading-more {
  text-align: center;
  padding: 24rpx 0;
}

.loading-more {
  display: flex;
  justify-content: center;
}
```

---

## 4. orders/detail.wxml

```xml
<!-- pages/orders/detail.wxml -->
<view class="container" wx:if="{{order}}">
  <!-- 订单状态 -->
  <view class="card status-card">
    <view class="status-icon-wrap">
      <text class="status-icon">{{order.statusIcon}}</text>
      <text class="status-text">{{order.statusText}}</text>
    </view>
  </view>

  <!-- 订单信息 -->
  <view class="card">
    <view class="card-title">订单信息</view>
    <view class="info-row">
      <text class="info-label">订单号</text>
      <text class="info-value">{{order.order_no}}</text>
    </view>
    <view class="divider"></view>
    <view class="info-row">
      <text class="info-label">下单时间</text>
      <text class="info-value text-secondary">{{order.timeText}}</text>
    </view>
    <view class="divider"></view>
    <view class="info-row">
      <text class="info-label">客户</text>
      <text class="info-value">{{order.customer_name || '匿名'}}</text>
    </view>
    <view class="divider"></view>
    <view class="info-row">
      <text class="info-label">联系电话</text>
      <text class="info-value">{{order.customer_phone || '—'}}</text>
    </view>
    <view class="divider"></view>
      <text class="info-label">配送地址</text>
      <text class="info-value text-small">{{order.address || '—'}}</text>
    </view>
  </view>

  <!-- 菜品明细 -->
  <view class="card">
    <view class="card-title">菜品明细</view>
    <view class="item-row" wx:for="{{order.itemList}}" wx:key="name">
      <view class="flex-between">
        <view class="flex-row">
          <text class="item-name">{{item.name}}</text>
          <text class="item-qty text-secondary text-small">×{{item.qty}}</text>
        </view>
        <text class="item-price">¥{{item.subtotal}}</text>
      </view>
    </view>
    <view class="divider"></view>
    <view class="info-row">
      <text class="info-label">商品总额</text>
      <text class="info-value">¥{{order.subtotal}}</text>
    </view>
    <view class="info-row" wx:if="{{order.delivery_fee > 0}}">
      <text class="info-label">配送费</text>
      <text class="info-value">¥{{order.delivery_fee}}</text>
    </view>
    <view class="info-row" wx:if="{{order.discount > 0}}">
      <text class="info-label">优惠</text>
      <text class="info-value text-success">-¥{{order.discount}}</text>
    </view>
    <view class="divider"></view>
    <view class="total-row">
      <text class="total-label">实付</text>
      <text class="total-amount">¥{{order.total_amount}}</text>
    </view>
  </view>

  <!-- 状态时间线 -->
  <view class="card">
    <view class="card-title">订单进度</view>
    <view class="timeline">
      <view class="timeline-item {{item.active ? 'active' : ''}}" wx:for="{{timeline}}" wx:key="step">
        <view class="timeline-dot"></view>
        <view class="timeline-content">
          <text class="timeline-title">{{item.title}}</text>
          <text class="timeline-time text-secondary text-small" wx:if="{{item.time}}">{{item.time}}</text>
        </view>
      </view>
    </view>
  </view>

  <!-- 操作按钮 -->
  <view class="action-bar" wx:if="{{order.status === 'pending' || order.status === 'processing'}}">
    <button class="btn-secondary action-btn" bindtap="onReject" wx:if="{{order.status === 'pending'}}">拒单</button>
    <button class="btn-primary action-btn" bindtap="onAccept" wx:if="{{order.status === 'pending'}}">接单</button>
    <button class="btn-primary action-btn" bindtap="onComplete" wx:if="{{order.status === 'processing'}}">标记完成</button>
  </view>
</view>

<!-- 加载中 -->
<view class="container" wx:if="{{!order && loading}}">
  <view class="empty-state">
    <view class="loading-dots">
      <view class="dot"></view>
      <view class="dot"></view>
      <view class="dot"></view>
    </view>
  </view>
</view>
```

---

## 5. orders/detail.js

```javascript
// pages/orders/detail.js
const app = getApp()

Page({
  data: {
    orderId: null,
    order: null,
    loading: true,
    timeline: []
  },

  onLoad(options) {
    this.setData({ orderId: options.id })
    this.loadOrderDetail(options.id)
  },

  // 加载订单详情
  async loadOrderDetail(id) {
    try {
      const res = await wx.cloud.callFunction({
        name: 'supabase_query',
        data: {
          action: 'select',
          table: 'orders',
          filters: { id },
          limit: 1
        }
      })

      const data = res.result && res.result.data && res.result.data[0] ? res.result.data[0] : null
      
      if (data) {
        this.setData({ order: this.formatOrder(data), loading: false })
        this.buildTimeline(data)
      } else {
        this.setMockDetail()
      }
    } catch (e) {
      console.log('订单详情加载失败', e)
      this.setMockDetail()
    }
  },

  // 格式化订单详情
  formatOrder(o) {
    const statusMap = {
      'pending': { text: '待处理', icon: '⏳' },
      'processing': { text: '制作中', icon: '🔥' },
      'completed': { text: '已完成', icon: '✅' },
      'cancelled': { text: '已取消', icon: '❌' }
    }
    const status = statusMap[o.status] || { text: o.status, icon: '📋' }

    let itemList = []
    let subtotal = 0
    if (Array.isArray(o.items)) {
      itemList = o.items.map(i => ({
        name: i.name,
        qty: i.qty,
        price: i.price,
        subtotal: (i.price * i.qty).toFixed(2)
      }))
      subtotal = o.items.reduce((s, i) => s + i.price * i.qty, 0)
    }

    const time = new Date(o.created_at || Date.now())
    const timeText = `${time.getMonth() + 1}月${time.getDate()}日 ${String(time.getHours()).padStart(2,'0')}:${String(time.getMinutes()).padStart(2,'0')}`

    return {
      ...o,
      statusText: status.text,
      statusIcon: status.icon,
      itemList,
      subtotal: subtotal.toFixed(2),
      delivery_fee: o.delivery_fee || 0,
      discount: o.discount || 0,
      timeText
    }
  },

  // 构建时间线
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

  // 接单
  async onAccept() {
    const ok = await this.updateStatus('processing')
    if (ok) {
      wx.showToast({ title: '已接单', icon: 'success' })
      this.refreshDetail()
    }
  },

  // 拒单
  async onReject() {
    const ok = await this.updateStatus('cancelled')
    if (ok) {
      wx.showToast({ title: '已拒单', icon: 'none' })
      this.refreshDetail()
    }
  },

  // 标记完成
  async onComplete() {
    const ok = await this.updateStatus('completed')
    if (ok) {
      wx.showToast({ title: '已完成', icon: 'success' })
      this.refreshDetail()
    }
  },

  // 更新订单状态
  async updateStatus(newStatus) {
    try {
      const res = await wx.cloud.callFunction({
        name: 'supabase_query',
        data: {
          action: 'update_order_status',
          table: 'orders',
          data: { order_id: this.data.orderId, new_status: newStatus }
        }
      })
      
      if (res.result && res.result.code === 0) {
        // ===== 京东外卖API对接预留 =====
        // TODO: 如果订单来自京东外卖，需同步更新京东侧订单状态
        // await this.syncJingdongOrder(this.data.orderId, newStatus)
        // 接口：POST https://openapi.jddj.com/djapi/order/updateStatus
        // 参数：{ orderId, status, timestamp, sign }
        // 需要先完成京东外卖开放平台接入申请
        return true
      }
      return false
    } catch (e) {
      wx.showToast({ title: '操作失败', icon: 'none' })
      return false
    }
  },

  // 刷新详情
  refreshDetail() {
    this.setData({ loading: true, order: null })
    this.loadOrderDetail(this.data.orderId)
  },

  // Mock详情
  setMockDetail() {
    const mock = {
      id: this.data.orderId,
      order_no: 'WM001-' + this.data.orderId,
      customer_name: '张先生',
      customer_phone: '138****8888',
      address: '望月湖小区2栋301室',
      status: 'pending',
      created_at: new Date(Date.now() - 300000).toISOString(),
      items: [
        { name: '猪油猛火炒饭', qty: 2, price: 15 },
        { name: '番茄炒蛋', qty: 1, price: 12 },
        { name: '紫菜蛋花汤', qty: 1, price: 8 }
      ],
      total_amount: 50,
      delivery_fee: 3,
      discount: 0
    }
    this.setData({ order: this.formatOrder(mock), loading: false })
    this.buildTimeline(mock)
  }
})
```

---

## 6. orders/detail.wxss

```css
/* pages/orders/detail.wxss */

/* 状态卡片 */
.status-card {
  text-align: center;
  padding: 40rpx;
}

.status-icon-wrap {
  display: flex;
  flex-direction: column;
  align-items: center;
}

.status-icon {
  font-size: 80rpx;
  margin-bottom: 12rpx;
}

.status-text {
  font-size: 32rpx;
  font-weight: 600;
}

/* 信息行 */
.info-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 20rpx 0;
}

.info-label {
  font-size: 28rpx;
  color: var(--color-text-secondary);
  flex-shrink: 0;
}

.info-value {
  font-size: 28rpx;
  color: var(--color-text);
  text-align: right;
  max-width: 60%;
}

/* 菜品行 */
.item-row {
  padding: 20rpx 0;
  border-bottom: 1rpx solid rgba(255,255,255,0.04);
}

.item-name {
  font-size: 28rpx;
  margin-right: 12rpx;
}

.item-qty {
  font-size: 24rpx;
}

.item-price {
  font-size: 28rpx;
  font-weight: 600;
}

/* 合计 */
.total-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16rpx 0;
}

.total-label {
  font-size: 30rpx;
  font-weight: 600;
}

.total-amount {
  font-size: 40rpx;
  font-weight: 700;
  color: var(--color-primary);
}

/* 时间线 */
.timeline {
  padding: 16rpx 0;
}

.timeline-item {
  display: flex;
  align-items: flex-start;
  margin-bottom: 32rpx;
  position: relative;
}

.timeline-item::before {
  content: '';
  position: absolute;
  left: 12rpx;
  top: 32rpx;
  bottom: -32rpx;
  width: 2rpx;
  background: rgba(255,255,255,0.1);
}

.timeline-item:last-child::before {
  display: none;
}

.timeline-dot {
  width: 24rpx;
  height: 24rpx;
  border-radius: 50%;
  background: rgba(255,255,255,0.15);
  margin-right: 24rpx;
  margin-top: 4rpx;
  flex-shrink: 0;
  z-index: 1;
}

.timeline-item.active .timeline-dot {
  background: var(--color-primary);
  box-shadow: 0 0 8rpx rgba(233,69,96,0.4);
}

.timeline-content {
  display: flex;
  flex-direction: column;
}

.timeline-title {
  font-size: 28rpx;
  color: var(--color-text);
  margin-bottom: 4rpx;
}

.timeline-item.active .timeline-title {
  color: var(--color-primary);
  font-weight: 600;
}

.timeline-time {
  font-size: 24rpx;
}

/* 底部操作 */
.action-bar {
  display: flex;
  gap: 16rpx;
  padding: 24rpx 0;
  padding-bottom: calc(24rpx + env(safe-area-inset-bottom));
}

.action-btn {
  flex: 1;
}
```

---

> **京东外卖API对接预留说明**：
> 
> 在 `detail.js` 的 `updateStatus` 方法中已预留京东外卖API同步接口：
> ```javascript
> // 接口：POST https://openapi.jddj.com/djapi/order/updateStatus
> // 参数：{ orderId, status, timestamp, sign }
> // 需要先完成京东外卖开放平台接入申请
> ```
> 
> 对接步骤（后续实现）：
> 1. 在京东外卖开放平台注册开发者账号
> 2. 创建应用获取 AppKey 和 AppSecret
> 3. 在云函数中实现签名算法和API调用
> 4. 订单状态变更时双写（Supabase + 京东外卖）
> 5. 通过 webhook 接收京东外卖订单推送
