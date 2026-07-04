const app = getApp()
Page({
  data: { storeName: '', storeCode: '' },
  onLoad() { this.setData({ storeName: app.globalData.storeName, storeCode: app.globalData.storeCode }) }
})
