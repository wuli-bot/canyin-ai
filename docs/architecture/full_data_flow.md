# 餐饮AI店长 — 全链路数据流架构文档

> **版本**：v1.0  
> **更新日期**：2026-07  
> **维护方**：餐饮AI店长项目组  
> **文档定位**：系统级数据流设计文档，可直接作为开发排期输入

---

## 目录

- [1. 系统总览](#1-系统总览)
- [2. 技术栈全景](#2-技术栈全景)
- [3. 系统架构图](#3-系统架构图)
- [4. 数据库架构](#4-数据库架构)
- [5. 上行数据流（用户→系统）](#5-上行数据流用户系统)
- [6. 下行数据流（系统→用户）](#6-下行数据流系统用户)
- [7. 横向数据流（系统内部）](#7-横向数据流系统内部)
- [8. MCP Server 工具规范](#8-mcp-server-工具规范)
- [9. AI平台架构](#9-ai平台架构)
- [10. 对话驱动迭代机制](#10-对话驱动迭代机制)
- [11. 实现状态矩阵](#11-实现状态矩阵)
- [12. 开发排期建议](#12-开发排期建议)

---

## 1. 系统总览

餐饮AI店长是一个**零服务器成本**的餐饮全链路智能管理系统，通过 GitHub Pages 前端 + Supabase 数据库 + Coze AI平台 + MCP Server 的组合，实现从订单采集、数据分析、智能决策到用户触达的完整闭环。

### 核心设计原则

| 原则 | 说明 |
|------|------|
| **零服务器成本** | 前端托管 GitHub Pages，数据库用 Supabase 免费层，AI 用 Coze 平台，无自建服务器 |
| **对话驱动迭代** | 每周日23:00自动分析用户对话，生成迭代报告，形成数据闭环 |
| **MCP统一数据出口** | 所有 AI 智能体通过 MCP Server 统一访问 Supabase，避免直连数据库 |
| **渐进式扩展** | V1基础6表 → V2扩展15表 → V3迭代3表，按需迭代 |

---

## 2. 技术栈全景

### 2.1 技术选型一览

| 层级 | 技术 | 选型/版本 | 成本 | 选型原因 |
|------|------|-----------|------|----------|
| **前端** | GitHub Pages | 30个独立HTML页面 | 免费 | 零服务器成本，CDN全球加速，Git版本管理天然集成 |
| **前端仓库** | GitHub | wuli-bot/canyin-ai | 免费 | 代码托管 + Pages托管一体化 |
| **数据库** | Supabase PostgreSQL | URL: `https://vovzgflfdwngfuqnxjc.supabase.co` | 免费层 | 托管PostgreSQL，自带REST API和实时订阅，免运维 |
| **AI平台** | Coze（扣子） | 4大智能体 + 25位AI数字员工 | 按量计费 | 可视化编排工作流，原生支持MCP协议，多渠道发布 |
| **备用AI** | 阿里云百炼 | qwen-plus模型 | 按量计费 | Coze不可用时降级方案，国内网络稳定 |
| **MCP Server** | Python + FastAPI + SSE | 端口8765 | 低 | MCP协议标准实现，SSE支持流式响应，轻量高效 |
| **微信小程序** | 原生小程序 | AppID: `wx97425a7556eb8572` | 免费 | 微信生态原生触达，主体：长沙市望城区周兰英餐饮店 |
| **消息推送** | 飞书群机器人 | Webhook | 免费 | 餐饮运营团队飞书办公，推送日报/预警 |
| **打印机** | 飞鹅云打印机 | 回调Webhook | 硬件成本 | 外卖订单自动接单打印，回调写入数据库 |

### 2.2 技术架构分层

```
┌─────────────────────────────────────────────────────┐
│                    用户触达层                         │
│  微信小程序 · H5页面(GitHub Pages) · 飞书群 · 打印机  │
├─────────────────────────────────────────────────────┤
│                    AI 智能层                          │
│  Coze 4大智能体 · 25位数字员工 · 千问Agent(备用)      │
├─────────────────────────────────────────────────────┤
│                   数据服务层                          │
│  MCP Server (FastAPI + SSE, 端口8765)                │
│  4个核心工具：菜单/库存/门店/日报                      │
├─────────────────────────────────────────────────────┤
│                   数据存储层                          │
│  Supabase PostgreSQL · 24张表 · V1/V2/V3             │
├─────────────────────────────────────────────────────┤
│                   外部数据源                          │
│  美团 · 京东 · 饿了么 · 飞鹅打印机                    │
└─────────────────────────────────────────────────────┘
```

---

## 3. 系统架构图

### 3.1 全局架构图

```mermaid
graph TB
    subgraph 用户触达层
        WX[微信小程序<br/>AppID: wx97425a7556eb8572]
        H5[H5页面群<br/>GitHub Pages × 30]
        FS[飞书群机器人<br/>日报/预警推送]
        FP[飞鹅云打印机<br/>订单回调]
    end

    subgraph AI智能层
        CB1[老板助手<br/>Coze智能体]
        CB2[店长助手<br/>Coze智能体]
        CB3[营销助手<br/>Coze智能体]
        CB4[智能小哇<br/>Coze智能体]
        DE[25位AI数字员工<br/>Coze]
        QA[千问Agent<br/>阿里云百炼·备用]
    end

    subgraph 数据服务层
        MCP[MCP Server<br/>Python+FastAPI+SSE<br/>端口8765]
        T1[get_menu<br/>菜品查询]
        T2[get_inventory_status<br/>库存查询]
        T3[get_store_info<br/>门店查询]
        T4[get_daily_summary<br/>日报查询]
        MCP --- T1
        MCP --- T2
        MCP --- T3
        MCP --- T4
    end

    subgraph 数据存储层
        SB[(Supabase PostgreSQL<br/>vovzgflfdwngfuqnxjc)]
        V1[V1基础·6表]
        V2[V2扩展·15表]
        V3[V3迭代·3表]
        SB --- V1
        SB --- V2
        SB --- V3
    end

    subgraph 外部数据源
        MT[美团外卖]
        JD[京东到家]
        ELM[饿了么]
    end

    %% 用户上行
    WX -->|用户指令| CB1
    WX -->|用户指令| CB2
    H5 -->|用户指令| CB4
    H5 -->|客服对话| SB

    %% AI下行
    CB3 -->|日报/建议| FS
    CB1 -->|预警/建议| FS

    %% AI → MCP → DB
    CB1 -->|MCP调用| MCP
    CB2 -->|MCP调用| MCP
    CB4 -->|MCP调用| MCP
    MCP -->|SQL查询| SB

    %% 外部订单
    MT -->|订单| FP
    JD -->|订单| FP
    ELM -->|订单| FP
    FP -->|回调Webhook| SB

    %% 备用链路
    CB1 -.->|降级| QA
    QA -.->|直连| SB

    %% 保活
    SB -.->|每3天ping| SB

    style SB fill:#3ecf8e,color:#fff
    style MCP fill:#ff9900,color:#fff
    style CB1 fill:#0066cc,color:#fff
    style CB2 fill:#0066cc,color:#fff
    style CB3 fill:#0066cc,color:#fff
    style CB4 fill:#0066cc,color:#fff
```

### 3.2 数据流总览图

```mermaid
flowchart LR
    subgraph 上行["⬆️ 上行数据流（用户→系统）"]
        U1[小程序/H5操作] --> CB[Coze Bot]
        CB --> MCP1[MCP Server]
        MCP1 --> DB1[(Supabase)]
        U2[外卖平台订单] --> FP1[飞鹅打印机]
        FP1 --> DB1
        U3[客服对话] --> DB1
    end

    subgraph 下行["⬇️ 下行数据流（系统→用户）"]
        DB2[(Supabase)] --> MCP2[MCP Server]
        MCP2 --> CB2[Coze智能体]
        CB2 --> P1[飞书群推送]
        CB2 --> P2[小程序展示]
        DB3[(Supabase)] --> RPT[竞品分析报告]
        RPT --> P1
    end

    subgraph 横向["↔️ 横向数据流（系统内部）"]
        DB4[(Supabase)] --> AGG[日报聚合]
        AGG --> DB4
        DB4 --> ITR[对话迭代分析]
        ITR --> DB4
    end

    DB1 -.-> DB2
    DB1 -.-> DB4

    style 上行 fill:#e8f5e9
    style 下行 fill:#e3f2fd
    style 横向 fill:#fff3e0
```

---

## 4. 数据库架构

### 4.1 数据库全景

```mermaid
erDiagram
    %% V1 基础表（6张）
    stores ||--o{ store_transactions : "一店多单"
    stores ||--o{ store_dishes : "一店多菜"
    stores ||--|| store_configs : "一店一配置"
    stores ||--o{ conversations : "一店多对话"
    store_transactions ||--o{ store_daily_summary : "聚合"
    stores ||--o{ store_daily_summary : "一店多日报"

    %% V2 扩展表（15张）
    stores ||--o{ supplier_profiles : "一店多供应商"
    supplier_profiles ||--o{ purchase_acceptance : "一供应商多验收"
    supplier_profiles ||--o{ supplier_scores : "一供应商多评分"
    stores ||--o{ ingredient_inventory : "一店多食材库存"
    stores ||--o{ food_safety_checklist : "一店多检查项"
    stores ||--o{ equipment_registry : "一店多设备"
    equipment_registry ||--o{ maintenance_logs : "一设备多维护"
    stores ||--o{ data_quality_metrics : "数据质量监控"
    stores ||--o{ decision_confidence_logs : "决策置信度"
    stores ||--o{ loss_records : "损耗记录"
    loss_records ||--o{ loss_daily_summary : "聚合"
    stores ||--o{ staff_profiles : "一店多员工"
    staff_profiles ||--o{ staff_schedule : "一员工多排班"
    staff_profiles ||--o{ staff_training : "一员工多培训"
    stores ||--o{ staff_tasks : "一店多任务"

    %% V3 迭代表（3张）
    conversations ||--o{ feedback_labels : "对话标签化"
    stores ||--o{ iteration_reports : "迭代报告"
    iteration_reports ||--o{ iteration_tasks : "一报告多任务"
```

### 4.2 V1 基础表（6张）— 核心业务数据

| # | 表名 | 用途 | 核心字段 | 实现状态 |
|---|------|------|----------|----------|
| 1 | `stores` | 门店主表 | store_id, name, address, phone | ✅ 已实现 |
| 2 | `conversations` | 对话记录 | store_id, role, content, created_at | ✅ 已实现 |
| 3 | `store_transactions` | 交易/订单 | store_id, amount, platform, created_at | ✅ 已实现 |
| 4 | `store_dishes` | 菜品目录 | store_id, name, price, category | ✅ 已实现 |
| 5 | `store_daily_summary` | 日报聚合 | store_id, date, total_revenue, order_count | ✅ 已实现 |
| 6 | `store_configs` | 门店配置 | store_id, config_key, config_value | ✅ 已实现 |

### 4.3 V2 扩展表（15张）— 全链路管理

| # | 表名 | 用途 | 所属模块 | 实现状态 |
|---|------|------|----------|----------|
| 7 | `supplier_profiles` | 供应商档案 | 供应链管理 | ✅ 已实现 |
| 8 | `purchase_acceptance` | 采购验收记录 | 供应链管理 | ✅ 已实现 |
| 9 | `supplier_scores` | 供应商评分 | 供应链管理 | ✅ 已实现 |
| 10 | `ingredient_inventory` | 食材库存 | 库存管理 | ✅ 已实现 |
| 11 | `food_safety_checklist` | 食安检查清单 | 食品安全 | ✅ 已实现 |
| 12 | `equipment_registry` | 设备台账 | 设备管理 | ✅ 已实现 |
| 13 | `maintenance_logs` | 维护日志 | 设备管理 | ✅ 已实现 |
| 14 | `data_quality_metrics` | 数据质量指标 | 系统监控 | ✅ 已实现 |
| 15 | `decision_confidence_logs` | 决策置信度日志 | 系统监控 | ✅ 已实现 |
| 16 | `loss_records` | 损耗记录 | 损耗管理 | ✅ 已实现 |
| 17 | `loss_daily_summary` | 损耗日报聚合 | 损耗管理 | ✅ 已实现 |
| 18 | `staff_profiles` | 员工档案 | 人员管理 | ✅ 已实现 |
| 19 | `staff_schedule` | 排班表 | 人员管理 | ✅ 已实现 |
| 20 | `staff_training` | 培训记录 | 人员管理 | ✅ 已实现 |
| 21 | `staff_tasks` | 任务分配 | 人员管理 | ✅ 已实现 |

### 4.4 V3 迭代表（3张）— 对话驱动进化

| # | 表名 | 用途 | 触发周期 | 实现状态 |
|---|------|------|----------|----------|
| 22 | `feedback_labels` | 对话反馈标签 | 实时/批处理 | ✅ 已实现 |
| 23 | `iteration_reports` | 迭代分析报告 | 每周日23:00 | ✅ 已实现 |
| 24 | `iteration_tasks` | 迭代任务清单 | 报告生成后 | ✅ 已实现 |

### 4.5 数据库保活策略

```mermaid
flowchart LR
    CRON[定时任务<br/>每3天] -->|HTTP GET| SB[(Supabase)]
    SB -->|200 OK| OK[保活成功]
    SB -->|超时/错误| ALERT[告警通知]
    
    style CRON fill:#fff3e0
    style SB fill:#3ecf8e,color:#fff
```

> **原因**：Supabase 免费层项目闲置7天后会自动暂停，需定期 ping 保持活跃。

---

## 5. 上行数据流（用户→系统）

### 5.1 用户指令流（小程序/H5 → Coze → MCP → Supabase）

```mermaid
sequenceDiagram
    participant U as 用户
    participant WX as 小程序/H5
    participant CB as Coze Bot
    participant MCP as MCP Server(:8765)
    participant SB as Supabase

    U->>WX: 输入指令（语音/文字）
    WX->>CB: 转发指令
    CB->>CB: 意图识别 & 工作流编排
    
    alt 需要查询数据
        CB->>MCP: 调用MCP工具(get_menu/get_inventory_status等)
        MCP->>SB: SQL查询
        SB-->>MCP: 返回数据
        MCP-->>CB: 结构化数据
    end
    
    CB->>CB: AI生成回复
    CB-->>WX: 返回回复
    WX-->>U: 展示结果
    
    Note over CB,SB: 对话记录同步写入 conversations 表
```

**技术选型说明**：

| 环节 | 技术方案 | 选型原因 |
|------|----------|----------|
| 指令传输 | Coze Bot API | 原生支持多渠道发布，小程序/H5统一接入 |
| 意图识别 | Coze工作流编排 | 可视化编排，无需自建NLP服务 |
| 数据查询 | MCP Server (SSE) | MCP协议标准化AI工具调用，SSE支持流式传输 |
| 数据库访问 | Supabase REST API | 无需直连数据库，HTTP接口安全便捷 |

### 5.2 外卖订单流（平台 → 飞鹅打印机 → Supabase）

```mermaid
sequenceDiagram
    participant MT as 美团/京东/饿了么
    participant FP as 飞鹅云打印机
    participant CS as 云服务器(回调接收)
    participant SB as Supabase

    MT->>FP: 新订单推送
    FP->>FP: 自动打印
    FP->>CS: 回调Webhook通知
    CS->>CS: 解析订单数据
    CS->>SB: INSERT INTO store_transactions
    SB-->>CS: 写入确认
    
    Note over SB: 订单数据进入 store_transactions 表<br/>字段包含: platform, amount, items, created_at
```

**技术选型说明**：

| 环节 | 技术方案 | 选型原因 |
|------|----------|----------|
| 订单接收 | 飞鹅云打印机回调 | 硬件级自动接单，无需开发对接各平台API |
| 回调处理 | 云服务器接收Webhook | 轻量级HTTP服务，仅做数据转发 |
| 数据写入 | Supabase INSERT | 直接写入store_transactions，触发后续聚合 |

**数据流详情**：

```
美团订单 → 飞鹅打印机 → Webhook回调 → 解析{platform:"meituan", amount, items} → store_transactions
京东订单 → 飞鹅打印机 → Webhook回调 → 解析{platform:"jddj", amount, items}    → store_transactions
饿了么订单 → 飞鹅打印机 → Webhook回调 → 解析{platform:"eleme", amount, items}  → store_transactions
```

### 5.3 客服对话流（H5 → Supabase → 迭代分析）

```mermaid
sequenceDiagram
    participant U as 用户
    participant H5 as xiaowa-bot.html
    participant SB as Supabase
    participant CRON as 每周定时任务
    participant AI as Coze AI分析

    U->>H5: 客服对话
    H5->>SB: INSERT INTO conversations
    
    Note over CRON: 每周日 23:00 触发
    
    CRON->>SB: 查询本周 conversations
    SB-->>CRON: 返回对话记录
    CRON->>AI: 发送对话批量分析
    AI->>AI: 标签化分类(feedback_labels)
    AI->>AI: 生成迭代报告(iteration_reports)
    AI->>AI: 拆解迭代任务(iteration_tasks)
    AI->>SB: 写入分析结果
```

**技术选型说明**：

| 环节 | 技术方案 | 选型原因 |
|------|----------|----------|
| 对话采集 | H5页面直连Supabase | 零中间层，降低延迟 |
| 对话存储 | conversations表 | 统一存储所有渠道对话 |
| 定时分析 | 每周日23:00自动触发 | 低峰期执行，不影响日常使用 |
| 标签化 | Coze AI分析 | 利用AI理解对话语义，自动分类 |

---

## 6. 下行数据流（系统→用户）

### 6.1 智能推送流（Supabase → MCP → Coze → 飞书/小程序）

```mermaid
sequenceDiagram
    participant SB as Supabase
    participant MCP as MCP Server(:8765)
    participant CB as Coze智能体
    participant FS as 飞书群
    participant WX as 小程序

    Note over SB: 定时触发 / 事件触发
    
    SB->>MCP: get_daily_summary 查询日报数据
    MCP->>SB: SQL查询
    SB-->>MCP: 返回日报数据
    MCP-->>CB: 结构化日报
    
    CB->>CB: AI分析生成日报/预警/建议
    
    alt 日报推送
        CB->>FS: 飞书群机器人推送日报
    end
    
    alt 预警推送
        CB->>FS: 飞书群机器人推送预警
    end
    
    alt 小程序展示
        CB-->>WX: 更新小程序数据展示
    end
```

**推送类型明细**：

| 推送类型 | 触发条件 | 推送渠道 | 数据来源 | 实现状态 |
|----------|----------|----------|----------|----------|
| 营业日报 | 每日固定时间 | 飞书群 | store_daily_summary | ✅ 已实现 |
| 异常预警 | 库存不足/损耗异常 | 飞书群 | ingredient_inventory / loss_records | ✅ 已实现 |
| 营销建议 | 周度分析 | 飞书群 | store_transactions + store_dishes | ✅ 已实现 |
| 迭代报告 | 每周日23:00 | 飞书群 | iteration_reports | ✅ 已实现 |
| 实时查询响应 | 用户主动查询 | 小程序/H5 | MCP实时查询 | ✅ 已实现 |

### 6.2 竞品监控流（采集 → Supabase → 分析 → 飞书）

```mermaid
flowchart LR
    subgraph 数据采集
        C1[竞品数据采集<br/>美团/点评/饿了么]
    end
    
    subgraph 数据存储
        SB[(Supabase)]
    end
    
    subgraph 分析输出
        AN[竞品分析报告]
        FS[飞书群推送]
    end
    
    C1 -->|结构化数据| SB
    SB -->|查询分析| AN
    AN -->|推送| FS
    
    style C1 fill:#fce4ec
    style SB fill:#3ecf8e,color:#fff
    style FS fill:#e3f2fd
```

> **说明**：竞品数据采集当前为半自动化流程，后续计划接入自动化采集脚本。

---

## 7. 横向数据流（系统内部）

### 7.1 日报聚合流（订单 → 日报）

```mermaid
flowchart LR
    subgraph 源数据
        TX[store_transactions<br/>每笔订单]
    end
    
    subgraph 聚合处理
        AGG[聚合计算<br/>SUM/COUNT/GROUP BY]
    end
    
    subgraph 目标表
        DS[store_daily_summary<br/>每店每日一行]
    end
    
    TX -->|按 store_id + date 聚合| AGG
    AGG -->|INSERT/UPSERT| DS
    
    style TX fill:#fff3e0
    style AGG fill:#e8f5e9
    style DS fill:#e3f2fd
```

**聚合逻辑**：

| 聚合维度 | 源表 | 目标表 | 聚合方式 |
|----------|------|--------|----------|
| 日维度 | store_transactions | store_daily_summary | 按 store_id + date GROUP BY |
| 损耗日维度 | loss_records | loss_daily_summary | 按 store_id + date GROUP BY |

### 7.2 对话迭代流（对话 → 标签 → 报告 → 任务）

```mermaid
flowchart LR
    subgraph 数据源
        CV[conversations<br/>原始对话记录]
    end
    
    subgraph 标签化
        FL[feedback_labels<br/>反馈标签]
    end
    
    subgraph 报告生成
        IR[iteration_reports<br/>迭代分析报告]
    end
    
    subgraph 任务拆解
        IT[iteration_tasks<br/>可执行任务]
    end
    
    CV -->|AI语义分析| FL
    FL -->|每周聚合| IR
    IR -->|任务拆解| IT
    
    IT -.->|反馈优化| CV
    
    style CV fill:#fff3e0
    style FL fill:#e8f5e9
    style IR fill:#e3f2fd
    style IT fill:#f3e5f5
```

**迭代闭环说明**：

```
用户对话 → AI标签化分类 → 周度聚合分析 → 生成迭代报告 → 拆解可执行任务 → 优化AI回复 → 更好的用户体验 → 更多对话
```

### 7.3 选址诊断流（独立模块）

```mermaid
flowchart LR
    subgraph 输入
        U[用户输入地址/商圈]
    end
    
    subgraph 前端处理
        DG[diagnosis.html<br/>选址诊断页面]
    end
    
    subgraph 输出
        R[诊断结果展示<br/>商圈画像/竞品密度/评分]
    end
    
    U --> DG
    DG --> R
    
    R -.->|规划中| SB[(Supabase<br/>选址结果入库)]
    
    style DG fill:#fff3e0
    style R fill:#e3f2fd
    style SB fill:#f5f5f5,color:#999
```

> **当前状态**：选址诊断结果在前端展示，**暂未入库**。规划中将诊断结果写入数据库，支持历史对比和持续优化。

### 7.4 全链路数据流完整图

```mermaid
flowchart TB
    %% 外部输入
    WX[微信小程序]
    H5[H5页面群]
    MT[美团]
    JD[京东到家]
    ELM[饿了么]
    
    %% 中间处理
    CB[Coze 4大智能体<br/>+25数字员工]
    FP[飞鹅打印机]
    MCP[MCP Server<br/>4个核心工具]
    
    %% 数据库
    SB[(Supabase<br/>24张表)]
    
    %% 内部聚合
    AGG1[日报聚合<br/>transactions→daily_summary]
    AGG2[损耗聚合<br/>loss_records→loss_daily_summary]
    ITR[对话迭代<br/>conversations→labels→reports→tasks]
    
    %% 输出
    FS[飞书群推送]
    WX2[小程序展示]
    
    %% 上行
    WX -->|指令| CB
    H5 -->|指令| CB
    H5 -->|客服对话| SB
    MT -->|订单| FP
    JD -->|订单| FP
    ELM -->|订单| FP
    FP -->|回调| SB
    CB -->|MCP调用| MCP
    MCP -->|查询| SB
    
    %% 横向
    SB --> AGG1
    SB --> AGG2
    SB --> ITR
    AGG1 --> SB
    AGG2 --> SB
    ITR --> SB
    
    %% 下行
    SB -->|数据| MCP
    MCP -->|结构化数据| CB
    CB -->|日报/预警/建议| FS
    CB -->|实时数据| WX2
    
    %% 保活
    SB -.->|每3天ping| SB
    
    style SB fill:#3ecf8e,color:#fff
    style CB fill:#0066cc,color:#fff
    style MCP fill:#ff9900,color:#fff
    style FS fill:#e3f2fd
```

---

## 8. MCP Server 工具规范

### 8.1 架构概述

```mermaid
graph TB
    subgraph MCP Server
        SV[FastAPI 应用<br/>端口8765<br/>SSE协议]
        
        subgraph 工具集
            T1[get_menu<br/>查询门店菜品]
            T2[get_inventory_status<br/>查询库存状态]
            T3[get_store_info<br/>查询门店信息]
            T4[get_daily_summary<br/>查询日报数据]
        end
        
        SV --- T1
        SV --- T2
        SV --- T3
        SV --- T4
    end
    
    CB[Coze智能体] -->|MCP协议调用| SV
    SV -->|Supabase REST API| SB[(Supabase)]
    
    style SV fill:#ff9900,color:#fff
    style SB fill:#3ecf8e,color:#fff
```

### 8.2 工具详细规范

| # | 工具名 | 功能 | 输入参数 | 输出 | 关联表 | 实现状态 |
|---|--------|------|----------|------|--------|----------|
| 1 | `get_menu` | 查询门店菜品 | store_id | 菜品列表(名称/价格/分类) | store_dishes | ✅ 已实现 |
| 2 | `get_inventory_status` | 查询库存状态 | store_id | 食材库存明细(当前量/预警线) | ingredient_inventory | ✅ 已实现 |
| 3 | `get_store_info` | 查询门店信息 | store_id | 门店基础信息+配置 | stores, store_configs | ✅ 已实现 |
| 4 | `get_daily_summary` | 查询日报数据 | store_id, date | 日营收/订单量/损耗等 | store_daily_summary | ✅ 已实现 |

### 8.3 技术选型说明

| 维度 | 选型 | 原因 |
|------|------|------|
| 协议 | MCP (Model Context Protocol) | AI工具调用行业标准，Coze原生支持 |
| 传输 | SSE (Server-Sent Events) | 支持流式响应，适合AI场景的长文本输出 |
| 框架 | FastAPI | 异步高性能，自动生成API文档，Python生态友好 |
| 端口 | 8765 | 避开常用端口冲突 |
| 数据库连接 | Supabase REST API | 无需维护数据库连接池，HTTP无状态 |

### 8.4 规划中的MCP工具

| # | 工具名 | 功能 | 关联表 | 实现状态 |
|---|--------|------|--------|----------|
| 5 | `get_supplier_scores` | 查询供应商评分 | supplier_profiles, supplier_scores | 🔲 规划中 |
| 6 | `get_staff_schedule` | 查询排班 | staff_profiles, staff_schedule | 🔲 规划中 |
| 7 | `get_equipment_status` | 查询设备状态 | equipment_registry, maintenance_logs | 🔲 规划中 |
| 8 | `get_loss_summary` | 查询损耗日报 | loss_records, loss_daily_summary | 🔲 规划中 |
| 9 | `get_iteration_report` | 查询迭代报告 | iteration_reports, iteration_tasks | 🔲 规划中 |

---

## 9. AI平台架构

### 9.1 Coze智能体矩阵

```mermaid
graph TB
    subgraph Coze平台
        subgraph 4大智能体
            B1[老板助手<br/>经营决策·数据分析]
            B2[店长助手<br/>日常运营·任务管理]
            B3[营销助手<br/>活动策划·竞品监控]
            B4[智能小哇<br/>客服接待·FAQ解答]
        end
        
        subgraph 25位AI数字员工
            DE1[采购员AI]
            DE2[库存管理员AI]
            DE3[食安检查员AI]
            DE4[设备管理员AI]
            DE5[排班员AI]
            DE6[培训师AI]
            DE7[...共25位]
        end
    end
    
    B1 -->|MCP| MCP[MCP Server]
    B2 -->|MCP| MCP
    B4 -->|MCP| MCP
    MCP --> SB[(Supabase)]
    
    B3 -->|竞品数据| SB
    
    style B1 fill:#1565c0,color:#fff
    style B2 fill:#1565c0,color:#fff
    style B3 fill:#1565c0,color:#fff
    style B4 fill:#1565c0,color:#fff
```

### 9.2 智能体职责矩阵

| 智能体 | 核心职责 | 数据权限 | 触发方式 | 输出渠道 |
|--------|----------|----------|----------|----------|
| 老板助手 | 经营决策、数据分析、预警 | 全部24张表 | 用户指令 / 定时触发 | 飞书群 / 小程序 |
| 店长助手 | 日常运营、任务分配、排班 | 运营相关表 | 用户指令 | 小程序 / 飞书群 |
| 营销助手 | 活动策划、竞品分析、复购提升 | 交易/菜品表 | 用户指令 / 定时触发 | 飞书群 |
| 智能小哇 | 客服接待、FAQ、对话记录 | conversations | 用户对话 | H5 / 小程序 |

### 9.3 降级方案

```mermaid
flowchart LR
    CB[Coze智能体] -->|正常| MCP1[MCP Server]
    MCP1 --> SB1[(Supabase)]
    
    CB -.->|Coze不可用| QA[千问Agent<br/>qwen-plus]
    QA -.->|直连REST API| SB2[(Supabase)]
    
    style CB fill:#0066cc,color:#fff
    style QA fill:#ff9900,color:#fff
    style SB1 fill:#3ecf8e,color:#fff
    style SB2 fill:#3ecf8e,color:#fff
```

> **降级策略**：当 Coze 平台不可用时，自动切换至阿里云百炼平台的千问Agent（qwen-plus模型），通过直连Supabase REST API维持基本服务。降级模式不支持MCP工具调用和工作流编排，仅支持基础对话+数据查询。

---

## 10. 对话驱动迭代机制

### 10.1 迭代闭环架构

```mermaid
flowchart TB
    subgraph 第1步-数据采集
        D1[用户对话<br/>小程序/H5/飞书]
        D2[conversations表<br/>实时写入]
        D1 --> D2
    end
    
    subgraph 第2步-标签化["每周日 23:00"]
        L1[批量查询本周对话]
        L2[AI语义分析]
        L3[feedback_labels表<br/>标签写入]
        L1 --> L2
        L2 --> L3
    end
    
    subgraph 第3步-报告生成
        R1[标签聚合分析]
        R2[识别高频问题/改进点]
        R3[iteration_reports表<br/>报告写入]
        R1 --> R2
        R2 --> R3
    end
    
    subgraph 第4步-任务拆解
        T1[报告拆解为可执行任务]
        T2[iteration_tasks表<br/>任务写入]
        T1 --> T2
    end
    
    subgraph 第5步-闭环优化
        O1[任务执行→优化AI回复]
        O2[更好的用户体验]
        O3[更多有效对话]
        O1 --> O2
        O2 --> O3
        O3 -.-> D1
    end
    
    D2 --> L1
    L3 --> R1
    R3 --> T1
    T2 --> O1
    
    style 第2步-标签化 fill:#fff3e0
    style 第3步-报告生成 fill:#e3f2fd
    style 第5步-闭环优化 fill:#e8f5e9
```

### 10.2 迭代周期说明

| 阶段 | 时间 | 操作 | 涉及表 |
|------|------|------|--------|
| 日常采集 | 实时 | 对话写入 | conversations |
| 标签化 | 每周日 23:00 | AI分析标签 | feedback_labels |
| 报告生成 | 每周日 23:00 | 聚合分析 | iteration_reports |
| 任务拆解 | 报告生成后 | 拆解任务 | iteration_tasks |
| 优化执行 | 下周持续 | 执行任务优化 | 反馈至 conversations |

---

## 11. 实现状态矩阵

### 11.1 数据流实现状态

| 数据流 | 方向 | 描述 | 实现状态 |
|--------|------|------|----------|
| 用户指令→Coze→MCP→Supabase | 上行 | 用户查询菜品/库存/门店/日报 | ✅ 已实现 |
| 外卖订单→飞鹅→Supabase | 上行 | 三平台订单自动入库 | ✅ 已实现 |
| 客服对话→Supabase | 上行 | H5客服对话存储 | ✅ 已实现 |
| Supabase→MCP→Coze→飞书推送 | 下行 | 日报/预警/建议推送 | ✅ 已实现 |
| Supabase→MCP→Coze→小程序展示 | 下行 | 实时数据展示 | ✅ 已实现 |
| 竞品采集→Supabase→分析→飞书 | 下行 | 竞品监控推送 | 🔶 半自动 |
| 订单→日报聚合 | 横向 | transactions→daily_summary | ✅ 已实现 |
| 损耗→损耗日报聚合 | 横向 | loss_records→loss_daily_summary | ✅ 已实现 |
| 对话→标签→报告→任务 | 横向 | 对话驱动迭代闭环 | ✅ 已实现 |
| 选址诊断→入库 | 横向 | diagnosis.html结果存储 | 🔲 规划中 |
| Supabase保活 | 横向 | 每3天自动ping | ✅ 已实现 |
| Coze→千问降级 | 横向 | AI平台故障切换 | 🔲 规划中 |

### 11.2 组件实现状态

| 组件 | 描述 | 实现状态 |
|------|------|----------|
| GitHub Pages × 30页面 | 前端页面群 | ✅ 已实现 |
| Supabase V1 基础6表 | 核心业务数据 | ✅ 已实现 |
| Supabase V2 扩展15表 | 全链路管理 | ✅ 已实现 |
| Supabase V3 迭代3表 | 对话驱动进化 | ✅ 已实现 |
| MCP Server 4工具 | 数据查询服务 | ✅ 已实现 |
| MCP Server 5工具(规划) | 扩展数据查询 | 🔲 规划中 |
| Coze 4大智能体 | AI决策中枢 | ✅ 已实现 |
| Coze 25位数字员工 | 专业岗位AI | ✅ 已实现 |
| 微信小程序 | 用户触达 | ✅ 已实现 |
| 飞鹅打印机回调 | 订单自动接单 | ✅ 已实现 |
| 飞书群机器人 | 消息推送 | ✅ 已实现 |
| 千问Agent备用 | 降级方案 | 🔲 规划中 |
| 对话迭代定时任务 | 每周自动分析 | ✅ 已实现 |
| Supabase保活定时 | 每3天ping | ✅ 已实现 |

### 11.3 H5页面清单（30个）

> 以下为 GitHub Pages 托管的独立HTML页面，仓库 `wuli-bot/canyin-ai`。

| # | 页面 | 功能 | 数据流类型 | 实现状态 |
|---|------|------|------------|----------|
| 1 | index.html | 首页/导航 | 展示 | ✅ |
| 2 | xiaowa-bot.html | 客服对话 | 上行→Supabase | ✅ |
| 3 | diagnosis.html | 选址诊断 | 独立(暂未入库) | ✅ |
| 4-30 | （其余27个页面） | 各功能模块 | 按需 | ✅ |

> **注**：30个H5页面均已部署上线，具体页面清单详见仓库 `wuli-bot/canyin-ai` 的 `docs/` 目录。

---

## 12. 开发排期建议

### 12.1 规划中功能优先级

| 优先级 | 功能 | 依赖 | 预估工作量 | 关联数据流 |
|--------|------|------|------------|------------|
| P0 | MCP工具扩展(5→9) | MCP Server | 2-3天 | 上行数据流 |
| P0 | 选址诊断结果入库 | Supabase建表 | 1-2天 | 横向数据流 |
| P1 | 千问Agent降级方案 | 阿里云百炼 | 3-5天 | 横向数据流 |
| P1 | 竞品监控全自动化 | 采集脚本 | 5-7天 | 下行数据流 |
| P2 | MCP工具权限分级 | MCP Server | 2-3天 | 上行数据流 |
| P2 | 实时数据推送(SSE) | 前端改造 | 3-5天 | 下行数据流 |
| P3 | 多门店数据隔离 | Supabase RLS | 2-3天 | 全链路 |

### 12.2 数据流优化方向

```mermaid
graph LR
    subgraph 当前优化点
        O1[MCP工具覆盖<br/>4→9个]
        O2[选址数据闭环<br/>入库+历史对比]
        O3[AI降级机制<br/>千问Agent]
    end
    
    subgraph 中期优化
        M1[竞品监控自动化]
        M2[实时推送SSE]
        M3[数据权限分级]
    end
    
    subgraph 远期优化
        L1[多门店隔离RLS]
        L2[数据湖/BI看板]
        L3[AI自主决策闭环]
    end
    
    O1 --> M1
    O2 --> M2
    O3 --> M3
    M1 --> L1
    M2 --> L2
    M3 --> L3
    
    style O1 fill:#ffcdd2
    style O2 fill:#ffcdd2
    style O3 fill:#ffcdd2
    style M1 fill:#fff9c4
    style M2 fill:#fff9c4
    style M3 fill:#fff9c4
    style L1 fill:#c8e6c9
    style L2 fill:#c8e6c9
    style L3 fill:#c8e6c9
```

---

## 附录A：数据流完整索引

| 编号 | 数据流名称 | 方向 | 源 | 目标 | 涉及组件 | 状态 |
|------|-----------|------|-----|------|----------|------|
| UF-01 | 用户指令查询 | 上行 | 小程序/H5 | Supabase | Coze→MCP | ✅ |
| UF-02 | 外卖订单入库 | 上行 | 美团/京东/饿了么 | Supabase | 飞鹅→回调服务 | ✅ |
| UF-03 | 客服对话存储 | 上行 | H5 | Supabase | 直连 | ✅ |
| DF-01 | 日报推送 | 下行 | Supabase | 飞书群 | MCP→Coze→飞书 | ✅ |
| DF-02 | 预警推送 | 下行 | Supabase | 飞书群 | MCP→Coze→飞书 | ✅ |
| DF-03 | 实时数据展示 | 下行 | Supabase | 小程序 | MCP→Coze | ✅ |
| DF-04 | 竞品分析推送 | 下行 | Supabase | 飞书群 | 采集→分析→推送 | 🔶 |
| HF-01 | 订单日报聚合 | 横向 | store_transactions | store_daily_summary | SQL聚合 | ✅ |
| HF-02 | 损耗日报聚合 | 横向 | loss_records | loss_daily_summary | SQL聚合 | ✅ |
| HF-03 | 对话迭代闭环 | 横向 | conversations | iteration_tasks | AI分析链 | ✅ |
| HF-04 | 选址诊断 | 横向 | diagnosis.html | (暂未入库) | 前端独立 | 🔲 |
| HF-05 | 数据库保活 | 横向 | 定时任务 | Supabase | HTTP ping | ✅ |
| HF-06 | AI降级切换 | 横向 | Coze | 千问Agent | 故障检测 | 🔲 |

---

## 附录B：关键配置信息

| 配置项 | 值 | 备注 |
|--------|-----|------|
| GitHub仓库 | `wuli-bot/canyin-ai` | 前端代码+Pages托管 |
| Supabase URL | `https://vovzgflfdwngfuqnxjc.supabase.co` | 数据库 |
| Supabase保活周期 | 每3天 | 防止免费层暂停 |
| MCP Server端口 | 8765 | FastAPI + SSE |
| MCP工具数量 | 4(已实现) / 9(规划) | — |
| Coze智能体数量 | 4大智能体 + 25数字员工 | — |
| 小程序AppID | `wx97425a7556eb8572` | 微信原生小程序 |
| 小程序主体 | 长沙市望城区周兰英餐饮店 | 个体工商户 |
| 备用AI模型 | qwen-plus | 阿里云百炼平台 |
| 迭代分析周期 | 每周日 23:00 | 自动触发 |
| 数据库表总数 | 24张 | V1(6) + V2(15) + V3(3) |
| H5页面总数 | 30个 | GitHub Pages托管 |

---

> **文档结束** | 本文档为纯设计文档，不包含可运行代码。如需技术实现细节，请参考各模块开发文档。