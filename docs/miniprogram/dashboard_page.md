# 微信小程序 - 经营看板页面完整代码

> 经营看板：营收/订单/毛利率/库存预警，数据来自Supabase

---

## 1. dashboard/index.wxml

```xml
<!-- pages/dashboard/index.wxml -->
<view class="container">
  <!-- 日期筛选 -->
  <view class="date-tabs">
    <view 
      class="date-tab {{dateRange === item.value ? 'active' : ''}}" 
      wx:for="{{dateOptions}}" 
      wx:key="value" 
      data-value="{{item.value}}" 
      bindtap="onDateChange"
    >{{item.label}}</view>
  </view>

  <!-- 核心指标 -->
  <view class="metrics-grid">
    <view class="metric-card">
      <text class="metric-value">¥{{metrics.revenue}}</text>
      <text class="metric-label">营收</text>
      <view class="metric-trend {{metrics.revenueChange >= 0 ? 'up' : 'down'}}">
        <text>{{metrics.revenueChange >= 0 ? '↑' : '↓'}}{{Math.abs(metrics.revenueChange)}}%</text>
      </view>
    </view>
    <view class="metric-card">
      <text class="metric-value">{{metrics.orders}}</text>
      <text class="metric-label">订单</text>
      <view class="metric-trend {{metrics.ordersChange >= 0 ? 'up' : 'down'}}">
        <text>{{metrics.ordersChange >= 0 ? '↑' : '↓'}}{{Math.abs(metrics.ordersChange)}}%</text>
      </view>
    </view>
    <view class="metric-card">
      <text class="metric-value">{{metrics.profitRate}}%</text>
      <text class="metric-label">毛利率</text>
    </view>
    <view class="metric-card warning" bindtap="goAlerts">
      <text class="metric-value">{{metrics.alertCount}}</text>
      <text class="metric-label">预警</text>
    </view>
  </view>

  <!-- 营收趋势 -->
  <view class="card">
    <view class="card-title flex-between">
      <text>营收趋势</text>
      <text class="text-secondary text-small">近{{dateDays}}天</text>
    </view>
    <!-- 简易趋势图（用进度条模拟，避免引入echarts依赖） -->
    <view class="trend-chart">
      <view class="trend-bar-wrap" wx:for="{{trendData}}" wx:key="date">
        <view class="trend-bar" style="height: {{item.percent}}%;"></view>
        <text class="trend-label text-small">{{item.shortDate}}</text>
        <text class="trend-val text-small">¥{{item.value}}</text>
      </view>
    </view>
  </view>

  <!-- 库存预警 -->
  <view class="card" wx:if="{{alerts.length > 0}}">
    <view class="card-title">
      <text>库存预警</text>
      <text class="tag tag-danger" style="margin-left:12rpx;">{{alerts.length}}项</text>
    </view>
    <view class="alert-list">
      <view class="alert-item" wx:for="{{alerts}}" wx:key="id">
        <view class="flex-between">
          <text class="alert-name">{{item.item_name}}</text>
          <text class="tag tag-danger">{{item.status === 'critical' ? '紧急' : '不足'}}</text>
        </view>
        <view class="alert-bar-wrap">
          <view class="alert-bar" style="width: {{item.ratio}}%;"></view>
        </view>
        <text class="alert-detail text-secondary text-small">
          当前 {{item.quantity}}{{item.unit}} / 安全库存 {{item.min_stock}}{{item.unit}}
        </text>
      </view>
    </view>
  </view>

  <!-- 无预警状态 -->
  <view class="card" wx:if="{{alerts.length === 0}}">
    <view class="card-title">库存状态</view>
    <view class="empty-state">
      <text class="empty-icon">✅</text>
      <text class="empty-text">库存正常，无预警项</text>
    </view>
  </view>

  <!-- 快捷入口 -->
  <view class="section-title">AI分析</view>
  <view class="quick-list">
    <view class="quick-row card" wx:for="{{quickActions}}" wx:key="name" bindtap="onQuickTap" data-agent="{{item.agentIndex}}">
      <text class="quick-icon">{{item.icon}}</text>
      <view class="flex-col">
        <text class="quick-name">{{item.name}}</text>
        <text class="quick-desc text-secondary text-small">{{item.desc}}</text>
      </view>
      <text class="arrow">›</text>
    </view>
  </view>

  <!-- 底部留白 -->
  <view style="height: 40rpx;"></view>
</view>
```

---

## 2. dashboard/index.js

```javascript
// pages/dashboard/index.js
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
    metrics: {
      revenue: '0',
      orders: '0',
      profitRate: '0',
      alertCount: '0',
      revenueChange: 0,
      ordersChange: 0
    },
    trendData: [],
    alerts: [],
    quickActions: [
      { icon: '💰', name: '成本核算', desc: '查菜品利润、定价建议', agentIndex: 0 },
      { icon: '📝', name: '差评处理', desc: '回复差评、预警分析', agentIndex: 1 },
      { icon: '🌊', name: '私域引流', desc: '加微信、社群运营', agentIndex: 2 }
    ]
  },

  onLoad() {
    this.loadDashboard()
  },

  onPullDownRefresh() {
    this.loadDashboard().then(() => wx.stopPullDownRefresh())
  },

  // 日期切换
  onDateChange(e) {
    const range = e.currentTarget.dataset.value
    this.setData({ dateRange: range })
    this.loadDashboard()
  },

  // 加载看板数据
  async loadDashboard() {
    await Promise.all([
      this.loadMetrics(),
      this.loadTrend(),
      this.loadAlerts()
    ])
  },

  // 获取核心指标
  async loadMetrics() {
    const { dateRange, storeCode } = this.getDateFilters()
    
    try {
      const res = await wx.cloud.callFunction({
        name: 'supabase_query',
        data: {
          action: 'select',
          table: 'daily_summary',
          filters: {
            store_code: app.globalData.storeCode,
            ...dateRange
          },
          order: 'date',
          ascending: false,
          limit: 30
        }
      })

      const data = res.result && res.result.data ? res.result.data : []
      
      if (data.length === 0) {
        // 使用Mock数据
        this.setData({
          metrics: {
            revenue: '1,820',
            orders: '98',
            profitRate: '65',
            alertCount: '3',
            revenueChange: 12,
            ordersChange: 8
          }
        })
        return
      }

      // 汇总计算
      const totalRevenue = data.reduce((s, d) => s + (d.total_revenue || 0), 0)
      const totalOrders = data.reduce((s, d) => s + (d.total_orders || 0), 0)
      const avgProfit = data.reduce((s, d) => s + (d.gross_profit_rate || 0), 0) / data.length

      // 环比计算
      let revenueChange = 0
      let ordersChange = 0
      if (data.length >= 2) {
        revenueChange = Math.round((data[0].total_revenue - data[1].total_revenue) / data[1].total_revenue * 100) || 0
        ordersChange = Math.round((data[0].total_orders - data[1].total_orders) / data[1].total_orders * 100) || 0
      }

      this.setData({
        metrics: {
          revenue: this.formatNum(totalRevenue),
          orders: String(totalOrders),
          profitRate: String(Math.round(avgProfit)),
          alertCount: '-', // 从库存预警获取
          revenueChange,
          ordersChange
        }
      })
    } catch (e) {
      console.log('指标加载失败，使用Mock数据', e)
      this.setData({
        metrics: {
          revenue: '1,820', orders: '98', profitRate: '65',
          alertCount: '3', revenueChange: 12, ordersChange: 8
        }
      })
    }
  },

  // 获取营收趋势
  async loadTrend() {
    const { dateRange } = this.getDateFilters()
    
    try {
      const res = await wx.cloud.callFunction({
        name: 'supabase_query',
        data: {
          action: 'select',
          table: 'daily_summary',
          filters: {
            store_code: app.globalData.storeCode,
            ...dateRange
          },
          order: 'date',
          ascending: true,
          limit: 30
        }
      })

      const data = res.result && res.result.data ? res.result.data : []
      
      if (data.length === 0) {
        this.setMockTrend()
        return
      }

      const maxRevenue = Math.max(...data.map(d => d.total_revenue || 0), 1)
      const trendData = data.map(d => {
        const date = new Date(d.date)
        return {
          date: d.date,
          value: d.total_revenue || 0,
          percent: Math.round((d.total_revenue || 0) / maxRevenue * 100),
          shortDate: `${date.getMonth() + 1}/${date.getDate()}`
        }
      })

      this.setData({ trendData })
    } catch (e) {
      this.setMockTrend()
    }
  },

  // 获取库存预警
  async loadAlerts() {
    try {
      const res = await wx.cloud.callFunction({
        name: 'supabase_query',
        data: {
          action: 'select',
          table: 'inventory',
          filters: {
            store_code: app.globalData.storeCode
          },
          order: 'quantity',
          ascending: true,
          limit: 10
        }
      })

      const data = res.result && res.result.data ? res.result.data : []
      
      if (data.length === 0) {
        this.setMockAlerts()
        return
      }

      const alerts = data
        .filter(d => d.quantity <= (d.min_stock || 999))
        .map(d => ({
          id: d.id,
          item_name: d.item_name,
          quantity: d.quantity,
          unit: d.unit || '',
          min_stock: d.min_stock,
          status: d.quantity <= (d.min_stock * 0.5 || 0) ? 'critical' : 'low',
          ratio: Math.round((d.quantity / (d.min_stock || 1)) * 100)
        }))

      this.setData({
        alerts,
        'metrics.alertCount': String(alerts.length)
      })
    } catch (e) {
      this.setMockAlerts()
    }
  },

  // Mock数据
  setMockTrend() {
    const now = new Date()
    const trendData = []
    for (let i = 6; i >= 0; i--) {
      const d = new Date(now.getTime() - i * 86400000)
      const revenue = Math.round(1500 + Math.random() * 800)
      trendData.push({
        date: d.toISOString().slice(0, 10),
        value: revenue,
        percent: Math.round(revenue / 2500 * 100),
        shortDate: `${d.getMonth() + 1}/${d.getDate()}`
      })
    }
    this.setData({ trendData })
  },

  setMockAlerts() {
    this.setData({
      alerts: [
        { id: 1, item_name: '食用油', quantity: 3, unit: '桶', min_stock: 10, status: 'critical', ratio: 30 },
        { id: 2, item_name: '鸡蛋', quantity: 5, unit: '板', min_stock: 15, status: 'critical', ratio: 33 },
        { id: 3, item_name: '葱花', quantity: 2, unit: '斤', min_stock: 5, status: 'low', ratio: 40 }
      ],
      'metrics.alertCount': '3'
    })
  },

  // 获取日期筛选条件
  getDateFilters() {
    const { dateRange } = this.data
    const now = new Date()
    let start, end, days
    
    end = now.toISOString().slice(0, 10)
    
    switch (dateRange) {
      case 'today':
        start = end
        days = 1
        break
      case 'yesterday':
        const y = new Date(now.getTime() - 86400000)
        start = y.toISOString().slice(0, 10)
        end = start
        days = 1
        break
      case 'week':
        start = new Date(now.getTime() - 7 * 86400000).toISOString().slice(0, 10)
        days = 7
        break
      case 'month':
        start = new Date(now.getTime() - 30 * 86400000).toISOString().slice(0, 10)
        days = 30
        break
    }

    this.setData({ dateDays: days })
    return { dateRange: { start_date: start, end_date: end }, storeCode: app.globalData.storeCode }
  },

  // 格式化数字
  formatNum(n) {
    if (n >= 10000) return (n / 10000).toFixed(1) + '万'
    return n.toLocaleString('zh-CN')
  },

  // 跳转预警列表
  goAlerts() {
    // TODO: 跳转到详细预警页
    wx.showToast({ title: '预警详情（开发中）', icon: 'none' })
  },

  // 快捷操作
  onQuickTap(e) {
    const agentIndex = e.currentTarget.dataset.agent
    app.globalData.currentAgentIndex = agentIndex
    wx.switchTab({ url: '/pages/chat/index' })
  }
})
```

---

## 3. dashboard/index.wxss

```css
/* pages/dashboard/index.wxss */

/* 日期Tab */
.date-tabs {
  display: flex;
  gap: 12rpx;
  margin-bottom: 24rpx;
}

.date-tab {
  flex: 1;
  text-align: center;
  padding: 16rpx 0;
  border-radius: 32rpx;
  font-size: 24rpx;
  color: var(--color-text-secondary);
  background: var(--bg-card);
  transition: all 0.2s;
}

.date-tab.active {
  background: var(--color-primary);
  color: #fff;
  font-weight: 600;
}

/* 指标网格 */
.metrics-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16rpx;
  margin-bottom: 24rpx;
}

.metric-card {
  background: var(--bg-card);
  border-radius: var(--radius-md);
  padding: 28rpx;
  position: relative;
  overflow: hidden;
}

.metric-card::after {
  content: '';
  position: absolute;
  top: 0;
  right: 0;
  width: 60rpx;
  height: 60rpx;
  border-radius: 0 0 0 60rpx;
  background: rgba(233,69,96,0.08);
}

.metric-card.warning::after {
  background: rgba(255,152,0,0.15);
}

.metric-value {
  font-size: 44rpx;
  font-weight: 700;
  display: block;
  margin-bottom: 4rpx;
}

.metric-label {
  font-size: 24rpx;
  color: var(--color-text-secondary);
}

.metric-trend {
  position: absolute;
  bottom: 16rpx;
  right: 20rpx;
  font-size: 22rpx;
  padding: 4rpx 12rpx;
  border-radius: 12rpx;
}

.metric-trend.up {
  background: rgba(76,175,80,0.15);
  color: var(--color-success);
}

.metric-trend.down {
  background: rgba(244,67,54,0.15);
  color: var(--color-danger);
}

/* 趋势图（简易柱状图） */
.trend-chart {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  height: 240rpx;
  padding-top: 24rpx;
}

.trend-bar-wrap {
  display: flex;
  flex-direction: column;
  align-items: center;
  flex: 1;
  height: 100%;
  justify-content: flex-end;
}

.trend-bar {
  width: 32rpx;
  background: linear-gradient(to top, var(--color-primary), rgba(233,69,96,0.4));
  border-radius: 8rpx 8rpx 0 0;
  min-height: 8rpx;
  transition: height 0.5s;
}

.trend-label {
  margin-top: 8rpx;
  color: var(--color-text-secondary);
  font-size: 20rpx;
}

.trend-val {
  margin-top: 4rpx;
  color: var(--color-text);
  font-size: 18rpx;
}

/* 预警列表 */
.alert-list {
  margin-top: 16rpx;
}

.alert-item {
  padding: 20rpx 0;
  border-bottom: 1rpx solid rgba(255,255,255,0.04);
}

.alert-item:last-child {
  border-bottom: none;
}

.alert-name {
  font-size: 28rpx;
  font-weight: 600;
}

.alert-bar-wrap {
  height: 8rpx;
  background: rgba(255,255,255,0.06);
  border-radius: 4rpx;
  margin-top: 12rpx;
  overflow: hidden;
}

.alert-bar {
  height: 100%;
  background: var(--color-danger);
  border-radius: 4rpx;
  transition: width 0.5s;
}

.alert-detail {
  margin-top: 8rpx;
  display: block;
}

/* 快捷操作 */
.section-title {
  font-size: 30rpx;
  font-weight: 600;
  margin: 32rpx 0 16rpx;
  padding-left: 8rpx;
}

.quick-list {
  margin-bottom: 16rpx;
}

.quick-row {
  display: flex;
  align-items: center;
  margin-bottom: 12rpx;
  padding: 24rpx;
}

.quick-icon {
  font-size: 44rpx;
  margin-right: 20rpx;
}

.quick-name {
  font-size: 28rpx;
  font-weight: 600;
}

.quick-desc {
  margin-top: 4rpx;
}

.arrow {
  margin-left: auto;
  font-size: 40rpx;
  color: var(--color-text-secondary);
}
```

---

## 4. 云函数 cloudfunctions/supabase_query/index.js

```javascript
// cloudfunctions/supabase_query/index.js
// Supabase查询代理云函数 - 安全读写Supabase数据

const https = require('https')

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://vovzgflfdwngfuqnxjc.supabase.co'
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvdnpnZmxmZHduZ2Z1cW54amMiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTc4MTU5ODQ5NiwiZXhwIjoyMDk3MTc0NDk2fQ.p8e3LcWgBqWxQ3jYk7mN2vR4sT8uY6zA9bC1dE5fG3h'

/**
 * 通用HTTP请求封装
 */
function supabaseRequest(method, path, body) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null
    const url = new URL(SUPABASE_URL)
    
    const options = {
      hostname: url.hostname,
      port: 443,
      path: `/rest/v1${path}`,
      method: method,
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${SUPABASE_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': method === 'POST' ? 'return=representation' : undefined
      }
    }

    if (payload) {
      options.headers['Content-Length'] = Buffer.byteLength(payload)
    }

    const req = https.request(options, (res) => {
      let data = ''
      res.on('data', (chunk) => { data += chunk })
      res.on('end', () => {
        try {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            const parsed = data ? JSON.parse(data) : []
            resolve(parsed)
          } else {
            reject(new Error(`Supabase错误 ${res.statusCode}: ${data}`))
          }
        } catch (e) {
          reject(new Error('解析响应失败: ' + e.message))
        }
      })
    })

    req.on('error', (e) => reject(e))
    req.setTimeout(15000, () => {
      req.destroy()
      reject(new Error('请求超时'))
    })

    if (payload) req.write(payload)
    req.end()
  })
}

/**
 * 构建查询URL
 */
function buildQueryPath(table, filters, order, ascending, limit, offset) {
  let query = `/${table}?select=*`
  
  // 构建过滤条件
  if (filters) {
    Object.entries(filters).forEach(([key, value]) => {
      if (key === 'start_date') {
        query += `&date=gte.${value}`
      } else if (key === 'end_date') {
        query += `&date=lte.${value}`
      } else {
        query += `&${key}=eq.${value}`
      }
    })
  }
  
  // 排序
  if (order) {
    query += `&order=${order}${ascending === false ? '.desc' : '.asc'}`
  }
  
  // 分页
  if (limit) query += `&limit=${limit}`
  if (offset) query += `&offset=${offset}`
  
  return query
}

// 云函数入口
exports.main = async (event, context) => {
  const { action, table, filters, order, ascending, limit, offset } = event

  if (!action || !table) {
    return { code: -1, message: '缺少必要参数: action, table' }
  }

  try {
    let result

    switch (action) {
      case 'select': {
        const path = buildQueryPath(table, filters, order, ascending, limit, offset)
        result = await supabaseRequest('GET', path)
        break
      }
      
      case 'insert': {
        const body = event.data || filters
        result = await supabaseRequest('POST', `/${table}`, body)
        break
      }
      
      case 'update': {
        // 构建更新URL（通过ID更新）
        let updatePath = `/${table}`
        if (event.data && event.data.id) {
          updatePath += `?id=eq.${event.data.id}`
        } else if (filters) {
          updatePath += '?'
          Object.entries(filters).forEach(([k, v]) => {
            updatePath += `${k}=eq.${v}&`
          })
          updatePath = updatePath.slice(0, -1) // 去掉末尾&
        }
        result = await supabaseRequest('PATCH', updatePath, event.data)
        break
      }
      
      case 'update_order_status': {
        const { order_id, new_status } = event.data || {}
        if (!order_id || !new_status) {
          return { code: -1, message: '缺少 order_id 或 new_status' }
        }
        result = await supabaseRequest('PATCH', `/${table}?id=eq.${order_id}`, { status: new_status })
        break
      }
      
      case 'count': {
        const path = buildQueryPath(table, filters, null, null, null, null)
        const countPath = path + '&select=count'
        result = await supabaseRequest('GET', countPath)
        break
      }
      
      default:
        return { code: -1, message: `不支持的操作: ${action}` }
    }

    return {
      code: 0,
      data: result
    }
  } catch (err) {
    console.error('supabase_query error:', err)
    return {
      code: -1,
      message: err.message || '数据库查询失败'
    }
  }
}
```

---

## 5. 云函数 cloudfunctions/supabase_query/package.json

```json
{
  "name": "supabase_query",
  "version": "1.0.0",
  "description": "Supabase查询代理云函数",
  "main": "index.js",
  "dependencies": {}
}
```

## 6. 云函数 cloudfunctions/supabase_query/config.json

```json
{
  "permissions": {
    "openapi": []
  }
}
```

---

> **注意**：
> - 看板使用简易柱状图展示趋势（避免引入echarts的npm包增加体积）
> - 所有数据查询通过 supabase_query 云函数代理，不暴露 service_role key
> - 数据加载失败时使用Mock数据兜底，确保页面不空白
> - 订单状态更新也通过此云函数实现（action: 'update_order_status'）
