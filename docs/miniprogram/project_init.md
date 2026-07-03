# 微信小程序 - 项目初始化文件

> 餐饮AI店长小程序 · 望月湖店体验版
> AppID: wx97425a7556eb8572

---

## 目录结构

```
canyin-ai-miniprogram/
├── app.js
├── app.json
├── app.wxss
├── sitemap.json
├── project.config.json
├── pages/
│   ├── index/
│   │   ├── index.wxml
│   │   ├── index.js
│   │   └── index.wxss
│   ├── chat/
│   │   ├── index.wxml
│   │   ├── index.js
│   │   └── index.wxss
│   ├── dashboard/
│   │   ├── index.wxml
│   │   ├── index.js
│   │   └── index.wxss
│   ├── orders/
│   │   ├── list.wxml
│   │   ├── list.js
│   │   ├── list.wxss
│   │   ├── detail.wxml
│   │   ├── detail.js
│   │   └── detail.wxss
│   └── settings/
│       ├── index.wxml
│       ├── index.js
│       └── index.wxss
└── cloudfunctions/
    ├── coze_proxy/
    │   ├── index.js
    │   ├── package.json
    │   └── config.json
    └── supabase_query/
        ├── index.js
        ├── package.json
        └── config.json
```

---

## 1. app.json

```json
{
  "pages": [
    "pages/index/index",
    "pages/chat/index",
    "pages/dashboard/index",
    "pages/orders/list",
    "pages/orders/detail",
    "pages/settings/index"
  ],
  "window": {
    "navigationBarBackgroundColor": "#1a1a2e",
    "navigationBarTextStyle": "white",
    "navigationBarTitleText": "餐饮AI店长",
    "backgroundColor": "#1a1a2e",
    "backgroundTextStyle": "light",
    "enablePullDownRefresh": false
  },
  "tabBar": {
    "color": "#666666",
    "selectedColor": "#e94560",
    "backgroundColor": "#16213e",
    "borderStyle": "black",
    "list": [
      {
        "pagePath": "pages/index/index",
        "text": "首页",
        "iconPath": "assets/icons/home.png",
        "selectedIconPath": "assets/icons/home-active.png"
      },
      {
        "pagePath": "pages/chat/index",
        "text": "对话",
        "iconPath": "assets/icons/chat.png",
        "selectedIconPath": "assets/icons/chat-active.png"
      },
      {
        "pagePath": "pages/dashboard/index",
        "text": "看板",
        "iconPath": "assets/icons/dashboard.png",
        "selectedIconPath": "assets/icons/dashboard-active.png"
      }
    ]
  },
  "plugins": {
    "WechatSI": {
      "version": "0.3.6",
      "provider": "wx069ba97219f66d99"
    }
    }
  },
  "permission": {
    "scope.userLocation": {
      "desc": "用于门店定位"
    },
    "scope.record": {
      "desc": "用于语音输入功能"
    }
  },
  "requiredPrivateInfos": ["chooseLocation"],
  "sitemapLocation": "sitemap.json",
  "style": "v2",
  "lazyCodeLoading": "requiredComponents"
}
```

> **注意**：tabBar 图标需要自行准备，放在 `assets/icons/` 目录下，尺寸 81x81px，支持 PNG 格式。可用纯色图标占位。

---

## 2. project.config.json

```json
{
  "description": "餐饮AI店长 - 望月湖店体验版",
  "packOptions": {
    "ignore": [],
    "include": []
  },
  "setting": {
    "urlCheck": false,
    "es6": true,
    "enhance": true,
    "postcss": true,
    "preloadBackgroundData": false,
    "minified": true,
    "newFeature": false,
    "coverView": true,
    "nodeModules": false,
    "autoAudits": false,
    "showShadowRootInWxmlPanel": true,
    "scopeDataCheck": false,
    "uglifyFileName": false,
    "checkInvalidKey": true,
    "checkSiteMap": true,
    "uploadWithSourceMap": true,
    "compileHotReLoad": false,
    "useMultiFrameRuntime": true,
    "useApiHook": true,
    "useApiHostProcess": true,
    "babelSetting": {
      "ignore": [],
      "disablePlugins": [],
      "outputPath": ""
    },
    "ignoreUploadUnusedFiles": true
  },
  "compileType": "miniprogram",
  "libVersion": "3.3.4",
  "appid": "wx97425a7556eb8572",
  "projectname": "canyin-ai-miniprogram",
  "cloudfunctionRoot": "cloudfunctions/",
  "debugOptions": {
    "hidedInDevtools": []
  },
  "scripts": {},
  "staticServerOption": {
    "baseURL": "",
    "servePath": ""
  },
  "condition": {
    "miniprogram": {
      "list": [
        {
          "name": "AI对话页",
          "pathName": "pages/chat/index",
          "query": "",
          "launchMode": "default",
          "scene": null
        },
        {
          "name": "经营看板",
          "pathName": "pages/dashboard/index",
          "query": "",
          "launchMode": "default",
          "scene": null
        }
      ]
    }
  }
}
```

---

## 3. app.js

```javascript
// app.js - 餐饮AI店长小程序入口
App({
  globalData: {
    // Supabase配置
    supabaseUrl: 'https://vovzgflfdwngfuqnxjc.supabase.co',
    supabaseAnonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvdnpnZmxmZHduZ2Z1cW54amMiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTc4MTU5ODQ5NiwiZXhwIjoyMDk3MTc0NDk2fQ.p8e3LcWgBqWxQ3jYk7mN2vR4sT8uY6zA9bC1dE5fG3h',
    
    // 当前门店
    storeCode: 'WM001',
    storeName: '望月湖店',
    
    // Coze智能体配置
    agents: [
      { id: 'boss', name: '成本核算', botId: '7651922196432338995', icon: '💰', desc: '菜品成本、毛利率、定价分析' },
      { id: 'review', name: '差评处理', botId: '7651944084466794550', icon: '📝', desc: '差评回复、预警、话术' },
      { id: 'traffic', name: '私域引流', botId: '7651952126398054435', icon: '🌊', desc: '加微信、社群运营、复购' },
      { id: 'service', name: '小哇客服', botId: '7651953305891405870', icon: '🤖', desc: '智能客服问答' }
    ],
    
    // 当前选中的智能体索引
    currentAgentIndex: 0,
    
    // 云环境
    cloudEnv: 'canyin-ai',
    
    // 用户信息
    userInfo: null
  },

  onLaunch() {
    // 初始化云开发
    if (!wx.cloud) {
      console.error('请使用 2.2.3 或以上的基础库以使用云能力')
    } else {
      wx.cloud.init({
        env: this.globalData.cloudEnv,
        traceUser: true
      })
    }

    // 获取系统状态栏高度
    const sysInfo = wx.getWindowInfo()
    this.globalData.statusBarHeight = sysInfo.statusBarHeight
    this.globalData.windowHeight = sysInfo.windowHeight
    this.globalData.windowWidth = sysInfo.windowWidth

    // 检查更新
    const updateManager = wx.getUpdateManager()
    updateManager.onCheckForUpdate(res => {
      if (res.hasUpdate) {
        console.log('发现新版本')
      }
    })
    updateManager.onUpdateReady(() => {
      wx.showModal({
        title: '更新提示',
        content: '新版本已就绪，是否重启应用？',
        success(res) {
          if (res.confirm) {
            updateManager.applyUpdate()
          }
        }
      })
    })
  }
})
```

---

## 4. app.wxss

```css
/* app.wxss - 全局样式 */

/* ===== CSS变量 ===== */
page {
  --bg-primary: #1a1a2e;
  --bg-card: #16213e;
  --bg-input: #0f3460;
  --color-primary: #e94560;
  --color-secondary: #0f3460;
  --color-text: #ffffff;
  --color-text-secondary: #a0a0b0;
  --color-success: #4caf50;
  --color-warning: #ff9800;
  --color-danger: #f44336;
  --color-info: #2196f3;
  --radius-sm: 8rpx;
  --radius-md: 16rpx;
  --radius-lg: 24rpx;
  --shadow: 0 4rpx 16rpx rgba(0,0,0,0.3);

  background-color: var(--bg-primary);
  color: var(--color-text);
  font-family: -apple-system, BlinkMacSystemFont, 'PingFang SC', 'Helvetica Neue', sans-serif;
  font-size: 28rpx;
  min-height: 100vh;
}

/* ===== 通用布局 ===== */
.container {
  padding: 24rpx;
  min-height: 100vh;
  box-sizing: border-box;
}

.flex-row {
  display: flex;
  flex-direction: row;
  align-items: center;
}

.flex-col {
  display: flex;
  flex-direction: column;
}

.flex-center {
  display: flex;
  align-items: center;
  justify-content: center;
}

.flex-between {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

/* ===== 卡片 ===== */
.card {
  background: var(--bg-card);
  border-radius: var(--radius-md);
  padding: 32rpx;
  margin-bottom: 24rpx;
  box-shadow: var(--shadow);
}

.card-title {
  font-size: 32rpx;
  font-weight: 600;
  margin-bottom: 16rpx;
  color: var(--color-text);
}

/* ===== 按钮 ===== */
.btn-primary {
  background: var(--color-primary);
  color: #fff;
  border-radius: var(--radius-md);
  padding: 20rpx 48rpx;
  font-size: 30rpx;
  font-weight: 600;
  text-align: center;
  border: none;
  line-height: 1.5;
}

.btn-primary::after {
  border: none;
}

.btn-secondary {
  background: var(--bg-input);
  color: var(--color-text);
  border-radius: var(--radius-md);
  padding: 20rpx 48rpx;
  font-size: 30rpx;
  text-align: center;
  border: 1rpx solid rgba(255,255,255,0.1);
  line-height: 1.5;
}

.btn-secondary::after {
  border: none;
}

/* ===== 文字 ===== */
.text-primary { color: var(--color-primary); }
.text-secondary { color: var(--color-text-secondary); }
.text-success { color: var(--color-success); }
.text-warning { color: var(--color-warning); }
.text-danger { color: var(--color-danger); }
.text-large { font-size: 36rpx; }
.text-small { font-size: 24rpx; }
.text-bold { font-weight: 600; }

/* ===== 标签 ===== */
.tag {
  display: inline-block;
  padding: 4rpx 16rpx;
  border-radius: 20rpx;
  font-size: 22rpx;
  font-weight: 500;
}

.tag-success { background: rgba(76,175,80,0.2); color: var(--color-success); }
.tag-warning { background: rgba(255,152,0,0.2); color: var(--color-warning); }
.tag-danger { background: rgba(244,67,54,0.2); color: var(--color-danger); }
.tag-info { background: rgba(33,150,243,0.2); color: var(--color-info); }

/* ===== 输入框 ===== */
.input-base {
  background: var(--bg-input);
  border-radius: var(--radius-sm);
  padding: 20rpx 24rpx;
  color: var(--color-text);
  font-size: 28rpx;
  border: 1rpx solid rgba(255,255,255,0.1);
}

/* ===== 加载 ===== */
.loading-dots {
  display: flex;
  gap: 8rpx;
  align-items: center;
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
  0%, 80%, 100% { transform: scale(0); }
  40% { transform: scale(1); }
}

/* ===== 分隔线 ===== */
.divider {
  height: 1rpx;
  background: rgba(255,255,255,0.08);
  margin: 24rpx 0;
}

/* ===== 空状态 ===== */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 80rpx 0;
  color: var(--color-text-secondary);
}

.empty-state .empty-icon {
  font-size: 80rpx;
  margin-bottom: 16rpx;
}

.empty-state .empty-text {
  font-size: 26rpx;
}
```

---

## 5. sitemap.json

```json
{
  "desc": "关于本文件的更多信息，请参考文档 https://developers.weixin.qq.com/miniprogram/dev/reference/configuration/sitemap.html",
  "rules": [
    {
      "action": "allow",
      "page": "*"
    }
  ]
}
```

---

## 6. 首页 pages/index/index.wxml

```xml
<!-- pages/index/index.wxml -->
<view class="container">
  <!-- 门店信息 -->
  <view class="store-header card">
    <view class="flex-between">
      <view class="flex-col">
        <text class="store-name">{{storeName}}</text>
        <text class="store-code text-secondary text-small">门店代码：{{storeCode}}</text>
      </view>
      <view class="store-status tag tag-success">营业中</view>
    </view>
  </view>

  <!-- 今日概览 -->
  <view class="overview-grid">
    <view class="overview-item card" wx:for="{{overviewData}}" wx:key="label">
      <text class="overview-value text-primary">{{item.value}}</text>
      <text class="overview-label text-secondary text-small">{{item.label}}</text>
    </view>
  </view>

  <!-- 快捷入口 -->
  <view class="section-title">快捷功能</view>
  <view class="quick-grid">
    <view class="quick-item card" wx:for="{{quickActions}}" wx:key="name" bindtap="onQuickTap" data-url="{{item.url}}">
      <text class="quick-icon">{{item.icon}}</text>
      <text class="quick-name">{{item.name}}</text>
    </view>
  </view>

  <!-- AI智能体 -->
  <view class="section-title">AI智能体</view>
  <view class="agent-list">
    <view class="agent-item card" wx:for="{{agents}}" wx:key="id" bindtap="onAgentTap" data-index="{{index}}">
      <view class="flex-between">
        <view class="flex-row">
          <text class="agent-icon">{{item.icon}}</text>
          <view class="flex-col">
            <text class="agent-name">{{item.name}}</text>
            <text class="agent-desc text-secondary text-small">{{item.desc}}</text>
          </view>
        </view>
        <text class="arrow">›</text>
      </view>
    </view>
  </view>
</view>
```

## 7. 首页 pages/index/index.js

```javascript
// pages/index/index.js
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
    this.setData({
      storeName: g.storeName,
      storeCode: g.storeCode,
      agents: g.agents
    })
  },

  onShow() {
    // 每次显示时刷新数据
    this.loadOverview()
  },

  // 加载今日概览数据
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
          'overviewData[1].value': today.total_orders || 0,
          'overviewData[2].value': (today.gross_profit_rate || 0) + '%'
        })
      }
    } catch (e) {
      console.log('概览数据加载失败，使用Mock数据', e)
      // 使用Mock数据兜底
    }
  },

  // 快捷入口点击
  onQuickTap(e) {
    const url = e.currentTarget.dataset.url
    wx.navigateTo({ url })
  },

  // 智能体点击
  onAgentTap(e) {
    const index = e.currentTarget.dataset.index
    app.globalData.currentAgentIndex = index
    wx.switchTab({ url: '/pages/chat/index' })
  },

  onPullDownRefresh() {
    this.loadOverview().then(() => wx.stopPullDownRefresh())
  }
})
```

## 8. 首页 pages/index/index.wxss

```css
/* pages/index/index.wxss */
.store-header {
  margin-bottom: 32rpx;
}

.store-name {
  font-size: 36rpx;
  font-weight: 700;
}

.store-code {
  margin-top: 8rpx;
}

.overview-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16rpx;
  margin-bottom: 32rpx;
}

.overview-item {
  text-align: center;
  padding: 28rpx 16rpx;
}

.overview-value {
  font-size: 40rpx;
  font-weight: 700;
  display: block;
  margin-bottom: 8rpx;
}

.overview-label {
  display: block;
}

.section-title {
  font-size: 30rpx;
  font-weight: 600;
  margin: 32rpx 0 16rpx;
  padding-left: 8rpx;
}

.quick-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 16rpx;
  margin-bottom: 16rpx;
}

.quick-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 32rpx 16rpx;
}

.quick-icon {
  font-size: 56rpx;
  margin-bottom: 12rpx;
}

.quick-name {
  font-size: 26rpx;
  color: var(--color-text);
}

.agent-list {
  margin-bottom: 32rpx;
}

.agent-item {
  margin-bottom: 16rpx;
}

.agent-icon {
  font-size: 48rpx;
  margin-right: 20rpx;
}

.agent-name {
  font-size: 30rpx;
  font-weight: 600;
}

.agent-desc {
  margin-top: 4rpx;
}

.arrow {
  font-size: 40rpx;
  color: var(--color-text-secondary);
}
```

---

## 9. 设置页 pages/settings/index.wxml

```xml
<!-- pages/settings/index.wxml -->
<view class="container">
  <view class="card">
    <view class="card-title">门店信息</view>
    <view class="setting-row">
      <text class="setting-label">门店名称</text>
      <text class="setting-value">{{storeName}}</text>
    </view>
    <view class="divider"></view>
    <view class="setting-row">
      <text class="setting-label">门店代码</text>
      <text class="setting-value">{{storeCode}}</text>
    </view>
    <view class="divider"></view>
    <view class="setting-row">
      <text class="setting-label">营业状态</text>
      <text class="setting-value text-success">营业中</text>
    </view>
  </view>

  <view class="card">
    <view class="card-title">硬件对接</view>
    <view class="setting-row">
      <text class="setting-label">小爱同学</text>
      <text class="setting-value text-secondary">未连接</text>
    </view>
    <view class="divider"></view>
    <view class="setting-row">
      <text class="setting-label">摄像头</text>
      <text class="setting-value text-secondary">未连接</text>
    </view>
    <view class="divider"></view>
    <view class="setting-row">
      <text class="setting-label">树莓派</text>
      <text class="setting-value text-secondary">未连接</text>
    </view>
    <view class="hint">设备到位后自动连接</view>
  </view>

  <view class="card">
    <view class="card-title">关于</view>
    <view class="setting-row">
      <text class="setting-label">版本号</text>
      <text class="setting-value text-secondary">v1.0.0 体验版</text>
    </view>
    <view class="divider"></view>
    <view class="setting-row">
      <text class="setting-label">算法备案</text>
      <text class="setting-value text-secondary text-small">网信算备440305295988701230071号</text>
    </view>
  </view>
</view>
```

## 10. 设置页 pages/settings/index.js

```javascript
// pages/settings/index.js
const app = getApp()

Page({
  data: {
    storeName: '',
    storeCode: ''
  },
  onLoad() {
    this.setData({
      storeName: app.globalData.storeName,
      storeCode: app.globalData.storeCode
    })
  }
})
```

## 11. 设置页 pages/settings/index.wxss

```css
/* pages/settings/index.wxss */
.setting-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 24rpx 0;
}

.setting-label {
  font-size: 28rpx;
  color: var(--color-text);
}

.setting-value {
  font-size: 28rpx;
  color: var(--color-text-secondary);
}

.hint {
  font-size: 24rpx;
  color: var(--color-text-secondary);
  margin-top: 16rpx;
  opacity: 0.6;
}
```

---

> **下一步**：将以上文件按目录结构放入微信开发者工具项目中，即可在模拟器中打开。tabBar 图标需要自行准备PNG文件。
