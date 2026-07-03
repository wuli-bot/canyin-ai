# 微信小程序 - 部署与测试指南

> 餐饮AI店长小程序 · 望月湖店体验版
> AppID: wx97425a7556eb8572

---

## 一、环境准备

### 1.1 下载微信开发者工具

- 下载地址：https://developers.weixin.qq.com/miniprogram/dev/devtools/download.html
- 选择 **稳定版 Stable Build**（Windows/Mac按系统选择）
- 安装后打开，使用微信扫码登录

### 1.2 创建项目

1. 打开微信开发者工具 → 点击 **「+」新建项目**
2. 填写信息：
   - **项目名称**：`canyin-ai-miniprogram`
   - **目录**：新建一个空文件夹，将 `docs/miniprogram/` 下的代码按目录结构放入
   - **AppID**：`wx97425a7556eb8572`（选择已有AppID，不要选"测试号"）
   - **后端服务**：选择 **「微信云开发」**
3. 点击 **「确定」** 创建项目

### 1.3 目录结构确认

创建后项目应包含以下文件：

```
canyin-ai-miniprogram/
├── app.js          ← 从 project_init.md 复制
├── app.json        ← 从 project_init.md 复制
├── app.wxss        ← 从 project_init.md 复制
├── sitemap.json    ← 从 project_init.md 复制
├── project.config.json ← 从 project_init.md 复制
├── pages/
│   ├── index/      ← 首页（project_init.md 中）
│   ├── chat/       ← AI对话（chat_page.md 中）
│   ├── dashboard/  ← 经营看板（dashboard_page.md 中）
│   ├── orders/     ← 订单管理（orders_page.md 中）
│   └── settings/   ← 设置（project_init.md 中）
├── cloudfunctions/
│   ├── coze_proxy/       ← AI对话代理云函数
│   └── supabase_query/   ← 数据查询代理云函数
└── assets/
    └── icons/      ← tabBar图标（需自行准备）
```

> **tabBar图标**：需要准备6个PNG文件（home/home-active、chat/chat-active、dashboard/dashboard-active），尺寸 81×81px，放在 `assets/icons/` 目录下。可用纯色图标占位。

---

## 二、同声传译插件开通

语音输入功能依赖微信官方「同声传译」插件。

### 2.1 添加插件

1. 登录 **[微信公众平台](https://mp.weixin.qq.com)**
2. 使用绑定小程序的微信扫码登录
3. 左侧菜单 → **「设置」** → **「第三方设置」**
4. 找到 **「插件管理」** → 点击 **「添加插件」**
5. 搜索 **「同声传译」** → 找到 **微信同声传译**（AppID: `wx069ba97219f66d99`）
6. 点击 **添加** → 等待审核（通常即时通过）

### 2.2 确认配置

添加成功后，确认 `app.json` 中的插件声明：

```json
"plugins": {
  "WechatSI": {
    "version": "0.3.6",
    "provider": "wx069ba97219f66d99"
  }
}
```

> 如果版本号有更新，以插件详情页显示的最新版本为准。

### 2.3 权限说明

插件使用以下权限（已在 app.json 中声明）：
- `scope.record`：麦克风权限（用于语音输入）
- 首次使用语音功能时，小程序会自动弹窗请求权限

---

## 三、云函数部署

### 3.1 开通云开发

1. 在微信开发者工具中，点击工具栏 **「云开发」** 按钮
2. 弹出开通窗口 → 点击 **「开通」**
3. 创建云环境：
   - **环境名称**：`canyin-ai`
   - **套餐**：选择 **免费基础版**（足够体验版使用）
4. 等待创建完成（约1-2分钟）

### 3.2 部署 coze_proxy 云函数

1. 在开发者工具左侧文件树中，找到 `cloudfunctions/coze_proxy/`
2. **右键** `coze_proxy` 文件夹 → 选择 **「上传并部署：云端安装依赖」**
3. 等待上传完成（底部状态栏会显示进度）

**设置环境变量：**

1. 打开 **云开发控制台** → 左侧选择 **「云函数」**
2. 找到 `coze_proxy` → 点击进入详情
3. 找到 **「环境变量」** → 点击编辑
4. 添加环境变量：
   ```
   COZE_API_TOKEN = sat_LvCuUkueRmeZlNEJFdSBf1qXCu61fPi32jkbpTWKpktSUkTVY6oH16QKqYLQNIfY
   ```
5. 保存

### 3.3 部署 supabase_query 云函数

1. 同样 **右键** `cloudfunctions/supabase_query/` → **「上传并部署：云端安装依赖」**
2. 设置环境变量：
   ```
   SUPABASE_URL = https://vovzgflfdwngfuqnxjc.supabase.co
   SUPABASE_SERVICE_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvdnpnZmxmZHduZ2Z1cW54amMiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTc4MTU5ODQ5NiwiZXhwIjoyMDk3MTc0NDk2fQ.p8e3LcWgBqWxQ3jYk7mN2vR4sT8uY6zA9bC1dE5fG3h
   ```

> **安全提示**：service_role key 具有绕过 RLS 的权限，只放在云函数环境变量中，**绝不**写在前端代码里。

### 3.4 云函数测试

在云开发控制台 → 云函数 → 点击 `coze_proxy` → **「测试」**

测试参数：
```json
{
  "bot_id": "7651922196432338995",
  "query": "猪油炒饭成本多少？",
  "conversation_id": ""
}
```

预期返回：
```json
{
  "code": 0,
  "answer": "猪油炒饭的成本大约在...",
  "conversation_id": "xxx"
}
```

---

## 四、Supabase 配置

### 4.1 确认表结构

登录 **[Supabase Dashboard](https://supabase.com/dashboard/project/vovzgflfdwngfuqnxjc)**

左侧 → **Table Editor**，确认以下表已存在：

| 表名 | 用途 | 关键字段 |
|------|------|----------|
| `stores` | 门店信息 | store_code, store_name |
| `menu_items` | 菜品 | store_code, name, price, cost |
| `inventory` | 库存 | store_code, item_name, quantity, min_stock |
| `daily_summary` | 日报 | store_code, date, total_revenue, total_orders |
| `orders` | 订单 | store_code, order_no, items, total_amount, status |
| `chat_messages` | 对话记录 | store_code, agent_id, role, content |

> **如果表不存在**：在 Dashboard → **SQL Editor** 中依次执行：
> 1. `v2_schema.sql`（建表）
> 2. `supabase_build.sql`（扩展表）
> 3. `v2_default_data.sql`（默认数据）
> 4. `mock_data_wangyuehu.sql`（望月湖店模拟数据）
> 
> SQL文件内容从以下地址获取（浏览器打开复制）：
> - https://raw.githubusercontent.com/wuli-bot/canyin-ai/main/v2_schema.sql
> - https://raw.githubusercontent.com/wuli-bot/canyin-ai/main/supabase_build.sql
> - https://raw.githubusercontent.com/wuli-bot/canyin-ai/main/v2_default_data.sql
> - https://raw.githubusercontent.com/wuli-bot/canyin-ai/main/mock_data_wangyuehu.sql

### 4.2 数据灌入（替代方案）

也可以在手机浏览器打开数据加载器一键灌入：
**https://wuli-bot.github.io/canyin-ai/data-loader.html**

### 4.3 RLS 策略（可选）

如果需要数据隔离，在 SQL Editor 中执行：

```sql
-- 限制只能查看自己门店的数据
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "store_isolation" ON orders
  FOR SELECT USING (store_code = current_setting('app.store_code', true));
```

> 体验版阶段可以不启用 RLS，云函数已通过 service_role key 绕过。

---

## 五、本地调试

### 5.1 模拟器测试

1. 确认云函数已部署、环境变量已设置
2. 在开发者工具中点击 **「编译」**
3. 测试流程：
   - **首页**：看到门店信息、概览数据、快捷入口
   - **对话页**：点击底部「对话」tab → 选择智能体 → 输入文字 → 点击发送 → 等待AI回复
   - **看板页**：点击底部「看板」tab → 查看指标卡片、趋势图、库存预警
   - **订单页**：首页点击「订单管理」 → 查看订单列表 → 点击订单查看详情

4. Console 面板查看日志：开发者工具底部 → **「Console」** tab
   - 如果看到 `云函数调用失败` → 检查云函数是否部署成功
   - 如果看到 `语音识别错误` → 正常，模拟器不支持语音（需真机测试）

### 5.2 真机调试

**语音功能必须在真机上测试**（开发者工具模拟器不支持麦克风录音）。

1. 开发者工具 → 点击工具栏 **「真机调试」**
2. 手机微信扫描二维码
3. 手机上打开小程序后：
   - 进入对话页 → 点击 🎤 切换语音模式
   - 首次会弹出麦克风权限请求 → **允许**
   - 按住「按住说话」按钮 → 说话 → 松开
   - 识别结果自动填入并发送

4. 如果真机白屏：检查基础库版本是否 ≥ 3.3.4

---

## 六、语音功能测试用例

| 编号 | 用例 | 操作步骤 | 预期结果 | 备注 |
|------|------|----------|----------|------|
| V01 | 语音输入文字 | 对话页→点🎤→按住说"今天营收多少"→松开 | 识别文字填入→自动发送→AI回复营收数据 | 需真机 |
| V02 | 模式切换 | 点🎤切语音→再点⌨️切键盘 | 切换正常，无闪烁 | |
| V03 | 语音取消 | 按住说话→手指上滑→松开 | 显示"已取消"，不发送 | |
| V04 | 长文本语音 | 连续说30秒 | 完整识别，不断句 | |
| V05 | 权限拒绝 | 拒绝麦克风权限 | 提示"麦克风权限被拒绝，请前往设置开启" | |
| V06 | 智能体切换 | 点不同智能体Tab | 切换后清空消息，加载该智能体历史 | |
| V07 | 空输入 | 不输入直接点发送 | 发送按钮灰色，不可点 | |
| V08 | 网络异常 | 断网后发消息 | 显示"网络有点问题"提示 | |
| V09 | 快捷跳转 | 看板页点"成本核算" | 跳转到对话页，自动选中成本核算智能体 | |
| V10 | 下拉刷新 | 看板页下拉 | 刷新指标数据 | |

---

## 七、体验版生成

### 7.1 上传代码

1. 开发者工具 → 点击 **「上传」** 按钮
2. 填写：
   - **版本号**：`1.0.0`
   - **备注**：`体验版v1.0.0 - 望月湖店`
3. 点击确定 → 等待上传完成

### 7.2 设置体验版

1. 登录 **[微信公众平台](https://mp.weixin.qq.com)**
2. 左侧菜单 → **「管理」** → **「版本管理」**
3. 找到刚上传的版本 → 点击 **「选为体验版」**
4. 生成体验版二维码

### 7.3 添加体验者

1. 微信公众平台 → **「管理」** → **「成员管理」**
2. 在 **「体验成员」** 区域 → 点击 **「添加」**
3. 输入体验者微信号 → 确认添加
4. 将体验版二维码分享给体验者

> 体验者扫码后即可在手机上使用完整功能。

---

## 八、审核准备

### 8.1 提交审核前检查

- [ ] 所有页面可正常打开，无白屏
- [ ] AI对话功能正常（能发送消息、收到回复）
- [ ] 语音输入功能正常（需真机验证）
- [ ] 看板数据展示正常
- [ ] 订单列表和详情正常
- [ ] 无 Console 红色错误

### 8.2 审核信息

| 项目 | 内容 |
|------|------|
| **服务类目** | 餐饮服务平台 |
| **AppID** | wx97425a7556eb8572 |
| **算法备案编号** | 网信算备440305295988701230071号 |
| **统一社会信用代码** | 92430112MAEXE7G422 |
| **隐私政策** | 需编写小程序隐私政策页面 |

### 8.3 预计审核时间

- 首次审核：1-7个工作日
- 更新审核：1-3个工作日

### 8.4 常见拒审原因

| 原因 | 解决方案 |
|------|----------|
| 功能不完整 | 确保所有页面有内容，不能是空白页或"开发中" |
| 缺少隐私政策 | 在设置页添加隐私政策链接 |
| 语音权限未声明 | 确认 app.json 中已声明 scope.record |
| 插件未审核通过 | 确认同声传译插件已添加并通过 |
| 类目不符 | 选择正确的服务类目（餐饮服务平台） |
| 诱导分享 | 确保无分享引导弹窗或强制分享逻辑 |

---

## 九、故障排查

### 9.1 云函数调用失败

**现象**：Console 显示 `callFunction:fail` 或 `errCode: -404011`

**排查**：
1. 确认云开发已开通，环境名为 `canyin-ai`
2. 确认 `app.js` 中 `wx.cloud.init` 的 env 与实际环境名一致
3. 确认云函数已上传部署（云开发控制台 → 云函数 → 查看列表）
4. 确认环境变量已设置（COZE_API_TOKEN、SUPABASE_URL、SUPABASE_SERVICE_KEY）
5. 尝试在云开发控制台手动测试云函数

### 9.2 Supabase 连接失败

**现象**：看板数据为空或显示 Mock 数据

**排查**：
1. 确认 Supabase 项目状态为 **Active**（非 Paused）
2. 确认云函数中 SUPABASE_URL 和 SUPABASE_SERVICE_KEY 正确
3. 在 Supabase Dashboard → Table Editor 确认表有数据
4. 在云开发控制台测试 `supabase_query` 云函数，查看返回错误信息

### 9.3 语音插件不可用

**现象**：点击🎤切换后无反应，或 `requirePlugin` 报错

**排查**：
1. 确认微信公众平台 → 插件管理中已添加「同声传译」
2. 确认 `app.json` 中 plugins 配置正确
3. 确认基础库版本 ≥ 2.12.0
4. **模拟器不支持语音**，需真机调试
5. 检查手机系统是否给了微信麦克风权限

### 9.4 真机白屏

**现象**：真机打开后白屏，无内容

**排查**：
1. 确认基础库版本 ≥ 3.3.4
2. 真机调试查看 Console 错误
3. 检查是否有 `wx.cloud` 未初始化导致的报错
4. 检查 app.json 中 pages 路径是否正确

### 9.5 常见错误码

| 错误码 | 含义 | 解决方案 |
|--------|------|----------|
| -404011 | 云函数不存在 | 上传部署对应云函数 |
| -404003 | 云环境不存在 | 检查 env 名称 |
| -30003 | 麦克风权限被拒 | 引导用户去手机设置开启 |
| -30002 | 录音太短 | 提示用户说长一点 |
| ERR_CONNECTION | 网络连接失败 | 检查网络/Supabase状态 |

---

## 十、后续迭代计划

| 版本 | 功能 | 优先级 |
|------|------|--------|
| v1.1 | 订单创建（堂食扫码点餐） | 高 |
| v1.2 | 京东外卖API对接 | 中 |
| v1.3 | 小爱同学语音控制 | 低（等设备） |
| v1.4 | 树莓派硬件对接 | 低（等设备） |
| v1.5 | 多门店切换 | 低 |
| v2.0 | 正式版上线 | — |

---

> 本文档随项目迭代持续更新。如有问题，查阅上方故障排查或联系开发者。
