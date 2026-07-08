-- ============================================
-- Combined Schema for canyin-ai
-- Run this FIRST, then run mock_data_wangyuehu.sql
-- ============================================

-- ========== Part 1: v2_schema.sql ==========
-- ============================================================
-- 餐饮AI店长 V2 - 多店+客服+日报 新增表SQL
-- 纯增量，不修改V1任何表
-- 执行方式：Supabase Dashboard → SQL Editor → New Query → 粘贴执行
-- 生成时间：2026-07-01
-- ============================================================

-- ============================================================
-- 1. 门店主表（多店管理的核心）
-- ============================================================
CREATE TABLE IF NOT EXISTS stores (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  store_name TEXT NOT NULL,
  store_code TEXT UNIQUE NOT NULL,  -- 简短标识码，如 WH001
  address TEXT,
  contact_person TEXT,
  phone TEXT,
  business_hours TEXT,  -- 如 "10:00-22:00"
  platform_accounts JSONB DEFAULT '{}',  -- {"meituan": "shop_id", "douyin": "shop_id", "jd": "shop_id"}
  status TEXT DEFAULT 'active',  -- active/suspended/closed
  owner_id TEXT,  -- 管理者账号标识
  logo_url TEXT,
  settings JSONB DEFAULT '{}',  -- 门店级自定义配置
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 2. 客服对话记录表（统一入口，所有渠道对话沉淀）
-- ============================================================
CREATE TABLE IF NOT EXISTS conversations (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id UUID REFERENCES stores(id),
  channel TEXT NOT NULL,  -- wechat/douyin/juqing/gzh/meituan/tel
  customer_name TEXT,
  customer_external_id TEXT,  -- 外部平台的客户标识
  customer_phone TEXT,
  messages JSONB NOT NULL DEFAULT '[]',  -- [{role:"customer"|"ai"|"human", content, timestamp, source}]
  intent_tags TEXT[] DEFAULT '{}',  -- 识别出的意图标签
  status TEXT DEFAULT 'open',  -- open/ai_replied/escalated/resolved/closed
  assigned_to TEXT DEFAULT 'ai',  -- 'ai' 或具体人工客服名
  ai_response_count INTEGER DEFAULT 0,
  human_takeover BOOLEAN DEFAULT false,
  human_takeover_at TIMESTAMPTZ,
  satisfaction_score NUMERIC,  -- 1-5
  resolution_notes TEXT,
  last_message_at TIMESTAMPTZ DEFAULT NOW(),
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. 门店交易表（各店订单/交易流水）
-- ============================================================
CREATE TABLE IF NOT EXISTS store_transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id UUID REFERENCES stores(id),
  transaction_date DATE NOT NULL,
  transaction_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  order_no TEXT,
  channel TEXT NOT NULL,  -- meituan/dianping/tangshi/juqing/online
  items JSONB NOT NULL DEFAULT '[]',  -- [{name, qty, price, subtotal}]
  total_amount NUMERIC NOT NULL DEFAULT 0,
  discount_amount NUMERIC DEFAULT 0,
  platform_fee NUMERIC DEFAULT 0,  -- 平台抽佣
  delivery_fee NUMERIC DEFAULT 0,
  actual_amount NUMERIC DEFAULT 0,  -- 实际到手
  payment_method TEXT,  -- online/cash/wechat/alipay
  status TEXT DEFAULT 'completed',  -- completed/refunded/cancelled/pending
  customer_name TEXT,
  customer_phone TEXT,
  customer_note TEXT,
  raw_data JSONB,  -- 原始平台数据备份
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 4. 门店菜品表（各店菜品库，独立于V1的菜单模块）
-- ============================================================
CREATE TABLE IF NOT EXISTS store_dishes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id UUID REFERENCES stores(id),
  dish_name TEXT NOT NULL,
  category TEXT,  -- 主食/小吃/饮品/套餐
  price NUMERIC NOT NULL,
  cost NUMERIC,
  gross_margin NUMERIC,  -- 毛利率百分比
  status TEXT DEFAULT 'available',  -- available/soldout/seasonal/disabled
  is_featured BOOLEAN DEFAULT false,  -- 是否推荐/招牌
  is_new BOOLEAN DEFAULT false,  -- 是否新品
  sort_order INTEGER DEFAULT 0,
  description TEXT,
  image_url TEXT,
  total_sold NUMERIC DEFAULT 0,  -- 累计销量
  total_revenue NUMERIC DEFAULT 0,  -- 累计营收
  daily_avg_sold NUMERIC DEFAULT 0,  -- 日均销量（缓存）
  last_sold_date DATE,
  platform_prices JSONB DEFAULT '{}',  -- {"meituan": 15, "dianping": 16}
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 5. 门店日报汇总表（每日关键指标，多店对比用）
-- ============================================================
CREATE TABLE IF NOT EXISTS store_daily_summary (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id UUID REFERENCES stores(id),
  summary_date DATE NOT NULL,
  total_revenue NUMERIC DEFAULT 0,
  total_cost NUMERIC DEFAULT 0,
  gross_profit NUMERIC DEFAULT 0,
  gross_margin_pct NUMERIC,  -- 毛利率百分比
  order_count INTEGER DEFAULT 0,
  avg_order_value NUMERIC,
  customer_count INTEGER DEFAULT 0,
  new_customer_count INTEGER DEFAULT 0,
  negative_reviews INTEGER DEFAULT 0,
  inventory_alerts INTEGER DEFAULT 0,
  food_safety_score NUMERIC,  -- 食安评分
  top_dishes JSONB DEFAULT '[]',  -- [{name, qty, revenue}]
  bottom_dishes JSONB DEFAULT '[]',  -- 滞销菜品
  channel_breakdown JSONB DEFAULT '{}',  -- {"meituan": {revenue, orders}, "tangshi": {...}}
  peak_hours JSONB DEFAULT '[]',  -- [{hour, order_count}]
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(store_id, summary_date)
);

-- ============================================================
-- 6. 门店模块配置表（控制各店启用哪些功能模块）
-- ============================================================
CREATE TABLE IF NOT EXISTS store_configs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id UUID REFERENCES stores(id) UNIQUE,
  modules_enabled TEXT[] DEFAULT '{}',  -- 启用的模块列表
  ai_settings JSONB DEFAULT '{}',  -- AI回复配置 {"tone": "friendly", "max_retries": 3}
  notification_settings JSONB DEFAULT '{}',  -- 推送配置 {"channels": ["feishu", "wechat"]}
  business_rules JSONB DEFAULT '{}',  -- 门店级业务规则
  auto_reply_templates JSONB DEFAULT '{}',  -- 自定义话术模板
  escalation_rules JSONB DEFAULT '{}',  -- 转人工规则
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 索引
-- ============================================================
-- stores
CREATE INDEX IF NOT EXISTS idx_stores_status ON stores(status);
CREATE INDEX IF NOT EXISTS idx_stores_code ON stores(store_code);
CREATE INDEX IF NOT EXISTS idx_stores_owner ON stores(owner_id);

-- conversations
CREATE INDEX IF NOT EXISTS idx_conv_store ON conversations(store_id);
CREATE INDEX IF NOT EXISTS idx_conv_channel ON conversations(channel);
CREATE INDEX IF NOT EXISTS idx_conv_status ON conversations(status);
CREATE INDEX IF NOT EXISTS idx_conv_assigned ON conversations(assigned_to);
CREATE INDEX IF NOT EXISTS idx_conv_last_msg ON conversations(last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_conv_created ON conversations(created_at DESC);

-- store_transactions
CREATE INDEX IF NOT EXISTS idx_stx_store ON store_transactions(store_id);
CREATE INDEX IF NOT EXISTS idx_stx_date ON store_transactions(transaction_date);
CREATE INDEX IF NOT EXISTS idx_stx_channel ON store_transactions(channel);
CREATE INDEX IF NOT EXISTS idx_stx_status ON store_transactions(status);
CREATE INDEX IF NOT EXISTS idx_stx_order_no ON store_transactions(order_no);
CREATE INDEX IF NOT EXISTS idx_stx_store_date ON store_transactions(store_id, transaction_date);

-- store_dishes
CREATE INDEX IF NOT EXISTS idx_sd_store ON store_dishes(store_id);
CREATE INDEX IF NOT EXISTS idx_sd_status ON store_dishes(status);
CREATE INDEX IF NOT EXISTS idx_sd_category ON store_dishes(category);
CREATE INDEX IF NOT EXISTS idx_sd_featured ON store_dishes(is_featured);

-- store_daily_summary
CREATE INDEX IF NOT EXISTS idx_sds_store ON store_daily_summary(store_id);
CREATE INDEX IF NOT EXISTS idx_sds_date ON store_daily_summary(summary_date);
CREATE INDEX IF NOT EXISTS idx_sds_store_date ON store_daily_summary(store_id, summary_date);

-- store_configs
CREATE INDEX IF NOT EXISTS idx_sc_store ON store_configs(store_id);

-- ============================================================
-- RLS 策略
-- ============================================================
ALTER TABLE stores ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_dishes ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_daily_summary ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_configs ENABLE ROW LEVEL SECURITY;

-- 公开读取策略（调试阶段，正式上线后按 owner_id 隔离）
CREATE POLICY "Allow public read stores" ON stores FOR SELECT USING (true);
CREATE POLICY "Allow public insert stores" ON stores FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update stores" ON stores FOR UPDATE USING (true);

CREATE POLICY "Allow public read conversations" ON conversations FOR SELECT USING (true);
CREATE POLICY "Allow public insert conversations" ON conversations FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update conversations" ON conversations FOR UPDATE USING (true);

CREATE POLICY "Allow public read transactions" ON store_transactions FOR SELECT USING (true);
CREATE POLICY "Allow public insert transactions" ON store_transactions FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update transactions" ON store_transactions FOR UPDATE USING (true);

CREATE POLICY "Allow public read dishes" ON store_dishes FOR SELECT USING (true);
CREATE POLICY "Allow public insert dishes" ON store_dishes FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update dishes" ON store_dishes FOR UPDATE USING (true);

CREATE POLICY "Allow public read daily_summary" ON store_daily_summary FOR SELECT USING (true);
CREATE POLICY "Allow public insert daily_summary" ON store_daily_summary FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update daily_summary" ON store_daily_summary FOR UPDATE USING (true);

CREATE POLICY "Allow public read configs" ON store_configs FOR SELECT USING (true);
CREATE POLICY "Allow public insert configs" ON store_configs FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update configs" ON store_configs FOR UPDATE USING (true);

-- ============================================================
-- 插入默认门店（哇塞猛火猪油炒饭 - 首店）
-- ============================================================
INSERT INTO stores (store_name, store_code, address, contact_person, phone, business_hours, platform_accounts)
VALUES (
  '哇塞猛火猪油炒饭',
  'WH001',
  '湖南外国语职业学院北食堂',
  '艾刃',
  '',
  '10:00-21:00',
  '{"meituan": "", "douyin": "", "jd": ""}'
)
ON CONFLICT (store_code) DO NOTHING;

-- ========== Part 2: supabase_build.sql ==========
-- ============================================================
-- 餐饮AI店长 - 6模块15张表 批量建表SQL
-- 执行顺序：按外键依赖排序，supplier_profiles最先
-- 执行方式：Supabase Dashboard → SQL Editor → New Query → 粘贴执行
-- 生成时间：2026-06-25
-- ============================================================

-- ============================================================
-- P0-2 供应商管理 + 采购验收留痕 - 数据库Schema
-- 餐饮AI店长系统
-- ============================================================

-- 供应商档案表
CREATE TABLE IF NOT EXISTS supplier_profiles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  contact_person TEXT,
  phone TEXT,
  main_categories TEXT[],  -- 主营品类数组
  qualifications JSONB,  -- 资质信息（营业执照/食品经营许可证等）
  qual_expiry_date DATE,  -- 资质到期日
  cooperation_start DATE,
  contract_end_date DATE,
  bank_account TEXT,
  address TEXT,
  notes TEXT,
  status TEXT DEFAULT 'active',  -- active/inactive/blacklisted
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 采购验收记录表
CREATE TABLE IF NOT EXISTS purchase_acceptance (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  purchase_order_no TEXT NOT NULL,
  supplier_id UUID REFERENCES supplier_profiles(id),
  order_date DATE NOT NULL,
  expected_date DATE NOT NULL,
  actual_date DATE,
  items JSONB NOT NULL,  -- [{name, category, ordered_qty, ordered_unit, received_qty, received_unit, quality_score, notes, photo_urls}]
  total_amount NUMERIC,
  acceptance_status TEXT DEFAULT 'pending',  -- pending/accepted/rejected/partial
  quality_score NUMERIC,  -- 1-5
  delivery_ontime BOOLEAN,
  quantity_variance_pct NUMERIC,  -- 数量差异百分比
  abnormal_flag BOOLEAN DEFAULT false,
  abnormal_reason TEXT,
  acceptance_photos TEXT[],  -- 验收照片URL
  inspector TEXT NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 供应商评分表
CREATE TABLE IF NOT EXISTS supplier_scores (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  supplier_id UUID REFERENCES supplier_profiles(id),
  eval_period TEXT NOT NULL,  -- 如 2026-06
  price_score NUMERIC(2,1),  -- 价格评分 1-5
  quality_score NUMERIC(2,1),  -- 质量评分 1-5
  delivery_score NUMERIC(2,1),  -- 配送准时率 1-5
  overall_score NUMERIC(3,2),  -- 综合评分
  grade TEXT,  -- A/B/C/D
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_supplier_status ON supplier_profiles(status);
CREATE INDEX IF NOT EXISTS idx_supplier_qual_expiry ON supplier_profiles(qual_expiry_date);
CREATE INDEX IF NOT EXISTS idx_purchase_supplier ON purchase_acceptance(supplier_id);
CREATE INDEX IF NOT EXISTS idx_purchase_order_no ON purchase_acceptance(purchase_order_no);
CREATE INDEX IF NOT EXISTS idx_purchase_status ON purchase_acceptance(acceptance_status);
CREATE INDEX IF NOT EXISTS idx_purchase_abnormal ON purchase_acceptance(abnormal_flag);
CREATE INDEX IF NOT EXISTS idx_scores_supplier ON supplier_scores(supplier_id);
CREATE INDEX IF NOT EXISTS idx_scores_period ON supplier_scores(eval_period);
-- ============================================================
-- P0-1 食材效期管理 + 食安自查清单
-- 数据库表定义（Supabase / PostgreSQL）
-- ============================================================

-- 食材库存表（含效期）
CREATE TABLE IF NOT EXISTS ingredient_inventory (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  ingredient_name TEXT NOT NULL,
  category TEXT,  -- 肉类/蔬菜/调料/冻品等
  supplier_id UUID REFERENCES supplier_profiles(id),
  batch_no TEXT,
  purchase_date DATE NOT NULL,
  expiry_date DATE NOT NULL,
  shelf_life_days INTEGER NOT NULL,
  quantity NUMERIC NOT NULL,
  unit TEXT NOT NULL,
  storage_location TEXT DEFAULT '冷藏',  -- 冷藏/冷冻/常温
  status TEXT DEFAULT 'normal',  -- normal/warning/critical/expired/disposed
  disposed_at TIMESTAMPTZ,
  disposed_reason TEXT,  -- 报废/退货
  disposed_by TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 食安自查清单表
CREATE TABLE IF NOT EXISTS food_safety_checklist (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  check_date DATE NOT NULL,
  check_type TEXT NOT NULL,  -- morning_open/evening_close
  check_items JSONB NOT NULL,  -- [{item, checked, notes, photo_url}]
  inspector TEXT NOT NULL,
  completed BOOLEAN DEFAULT false,
  incomplete_items JSONB,  -- 未完成项
  notified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 索引：加速效期查询
CREATE INDEX IF NOT EXISTS idx_inventory_status ON ingredient_inventory(status);
CREATE INDEX IF NOT EXISTS idx_inventory_expiry ON ingredient_inventory(expiry_date);
CREATE INDEX IF NOT EXISTS idx_checklist_date_type ON food_safety_checklist(check_date, check_type);

-- RLS 策略（Supabase 必需）
ALTER TABLE ingredient_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE food_safety_checklist ENABLE ROW LEVEL SECURITY;

-- 公开读取策略（按 store_id 隔离，后续扩展）
CREATE POLICY "Allow public read inventory" ON ingredient_inventory
  FOR SELECT USING (true);

CREATE POLICY "Allow public read checklist" ON food_safety_checklist
  FOR SELECT USING (true);

CREATE POLICY "Allow public insert inventory" ON ingredient_inventory
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow public update inventory" ON ingredient_inventory
  FOR UPDATE USING (true);

CREATE POLICY "Allow public insert checklist" ON food_safety_checklist
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow public update checklist" ON food_safety_checklist
  FOR UPDATE USING (true);
CREATE TABLE IF NOT EXISTS equipment_registry (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  model TEXT,
  category TEXT,  -- 厨房设备/制冷设备/电器/其他
  purchase_date DATE,
  warranty_end DATE,
  maintenance_cycle_days INTEGER DEFAULT 30,
  last_maintenance DATE,
  next_maintenance DATE,
  status TEXT DEFAULT 'running',  -- running/maintenance/broken/retired
  location TEXT,
  purchase_cost NUMERIC,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS maintenance_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  equipment_id UUID REFERENCES equipment_registry(id),
  log_type TEXT NOT NULL,  -- maintenance/breakdown/inspection
  log_date TIMESTAMPTZ NOT NULL,
  description TEXT NOT NULL,
  repair_content TEXT,
  cost NUMERIC DEFAULT 0,
  technician TEXT,
  photos TEXT[],
  next_action TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 索引优化
CREATE INDEX IF NOT EXISTS idx_equipment_status ON equipment_registry(status);
CREATE INDEX IF NOT EXISTS idx_equipment_next_maintenance ON equipment_registry(next_maintenance);
CREATE INDEX IF NOT EXISTS idx_maintenance_equipment ON maintenance_logs(equipment_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_log_date ON maintenance_logs(log_date);
CREATE INDEX IF NOT EXISTS idx_maintenance_log_type ON maintenance_logs(log_type);
CREATE TABLE IF NOT EXISTS data_quality_metrics (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  module_name TEXT NOT NULL,  -- 来源模块
  metric_date DATE NOT NULL,
  completeness NUMERIC(5,2),  -- 完整性 0-100%
  accuracy NUMERIC(5,2),  -- 准确性 0-100%
  timeliness NUMERIC(5,2),  -- 时效性 0-100%
  overall_score NUMERIC(5,2),
  issues JSONB,  -- [{type, description, severity}]
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS decision_confidence_logs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  decision_id UUID,
  module_name TEXT NOT NULL,
  decision_type TEXT NOT NULL,  -- pricing/disposal/understocking/menu_adjustment
  confidence_score NUMERIC(5,2),  -- 0-100
  confidence_level TEXT,  -- high/medium/low
  data_sources JSONB,  -- 依据的数据来源
  data_volume INTEGER,  -- 支撑数据量
  consistency_score NUMERIC(5,2),  -- 数据一致性
  need_manual_review BOOLEAN DEFAULT false,
  human_confirmed BOOLEAN,
  human_reviewer TEXT,
  human_review_at TIMESTAMPTZ,
  decision_content JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 索引优化
CREATE INDEX IF NOT EXISTS idx_quality_module ON data_quality_metrics(module_name);
CREATE INDEX IF NOT EXISTS idx_quality_date ON data_quality_metrics(metric_date);
CREATE INDEX IF NOT EXISTS idx_decision_module ON decision_confidence_logs(module_name);
CREATE INDEX IF NOT EXISTS idx_decision_type ON decision_confidence_logs(decision_type);
CREATE INDEX IF NOT EXISTS idx_decision_level ON decision_confidence_logs(confidence_level);
CREATE INDEX IF NOT EXISTS idx_decision_review ON decision_confidence_logs(need_manual_review) WHERE need_manual_review = true;
-- 损耗追踪+预警模块 数据库表结构

CREATE TABLE IF NOT EXISTS loss_records (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  record_date DATE NOT NULL,
  ingredient_name TEXT NOT NULL,
  category TEXT,  -- 食材类别
  quantity NUMERIC NOT NULL,
  unit TEXT NOT NULL,
  unit_cost NUMERIC,
  total_cost NUMERIC,
  reason TEXT NOT NULL,  -- expired/spoilage/damage/overorder/preparation_waste
  reason_detail TEXT,
  recorded_by TEXT NOT NULL,
  photos TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_loss_records_date ON loss_records(record_date);
CREATE INDEX IF NOT EXISTS idx_loss_records_category ON loss_records(category);
CREATE INDEX IF NOT EXISTS idx_loss_records_reason ON loss_records(reason);

CREATE TABLE IF NOT EXISTS loss_daily_summary (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  summary_date DATE NOT NULL UNIQUE,
  total_revenue NUMERIC,
  total_cost NUMERIC,
  total_loss_amount NUMERIC,
  loss_rate NUMERIC(5,2),  -- 损耗率 = total_loss_amount / total_cost * 100
  loss_count INTEGER,
  top_loss_items JSONB,  -- [{ingredient, amount, reason}]
  status TEXT DEFAULT 'normal',  -- normal/warning/critical
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_loss_daily_summary_date ON loss_daily_summary(summary_date);
CREATE INDEX IF NOT EXISTS idx_loss_daily_summary_status ON loss_daily_summary(status);
-- 员工管理基础版 数据库表结构

CREATE TABLE IF NOT EXISTS staff_profiles (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT,
  role TEXT,  -- 老板/店长/厨师/帮厨/收银/保洁
  hire_date DATE,
  status TEXT DEFAULT 'active',  -- active/inactive
  hourly_rate NUMERIC,
  health_cert_date DATE,  -- 健康证到期日
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_staff_status ON staff_profiles(status);
CREATE INDEX IF NOT EXISTS idx_staff_role ON staff_profiles(role);

CREATE TABLE IF NOT EXISTS staff_schedule (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  staff_id UUID REFERENCES staff_profiles(id),
  schedule_date DATE NOT NULL,
  shift_type TEXT NOT NULL,  -- morning/afternoon/full/rest
  start_time TIME,
  end_time TIME,
  work_hours NUMERIC(4,2),
  actual_check_in TIME,
  actual_check_out TIME,
  actual_hours NUMERIC(4,2),
  status TEXT DEFAULT 'scheduled',  -- scheduled/checked_in/checked_out/completed/absent
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_schedule_date ON staff_schedule(schedule_date);
CREATE INDEX IF NOT EXISTS idx_schedule_staff ON staff_schedule(staff_id);

CREATE TABLE IF NOT EXISTS staff_training (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  staff_id UUID REFERENCES staff_profiles(id),
  training_name TEXT NOT NULL,
  training_type TEXT,  -- onboarding/safety/operation/service
  checklist JSONB,  -- [{item, completed, completed_at, confirmed_by}]
  overall_progress NUMERIC(5,2),
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_training_staff ON staff_training(staff_id);

CREATE TABLE IF NOT EXISTS staff_tasks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  task_date DATE NOT NULL,
  task_name TEXT NOT NULL,
  task_type TEXT NOT NULL,  -- opening/closing/daily
  assigned_to UUID REFERENCES staff_profiles(id),
  status TEXT DEFAULT 'pending',  -- pending/in_progress/completed/overdue
  priority INTEGER DEFAULT 1,  -- 1-3
  completed_at TIMESTAMPTZ,
  completed_by UUID,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tasks_date ON staff_tasks(task_date);
CREATE INDEX IF NOT EXISTS idx_tasks_type ON staff_tasks(task_type);
CREATE INDEX IF NOT EXISTS idx_tasks_assigned ON staff_tasks(assigned_to);

-- ============================================================
-- 验证：检查15张表是否全部创建
-- ============================================================
SELECT table_name, '✅ 已创建' as status
FROM information_schema.tables
WHERE table_schema='public'
AND table_name IN (
  'supplier_profiles','purchase_acceptance','supplier_scores',
  'ingredient_inventory','food_safety_checklist',
  'equipment_registry','maintenance_logs',
  'data_quality_metrics','decision_confidence_logs',
  'loss_records','loss_daily_summary',
  'staff_profiles','staff_schedule','staff_training','staff_tasks'
) ORDER BY table_name;

-- ========== Part 3: feedback_iteration_schema.sql ==========
-- ============================================================
-- 客服反馈驱动智能体迭代系统 - 数据库表
-- 纯增量，不修改任何现有表
-- ============================================================

-- 1. 对话标签表：记录每条对话的自动打标结果
CREATE TABLE IF NOT EXISTS feedback_labels (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  conversation_id uuid REFERENCES conversations(id),
  store_id uuid REFERENCES stores(id),
  -- 标签分类
  label_type text NOT NULL,  -- high_freq_question / knowledge_gap / feature_request / competitor_mention / sentiment_signal / good_suggestion / repeated_consult
  label_value text NOT NULL,  -- 标签内容（如具体问题文本、竞品名等）
  -- 元数据
  confidence numeric(3,2) DEFAULT 0.8,  -- 打标置信度
  source_role text,  -- 来源角色（customer/bot/system）
  source_text text,  -- 原始对话文本
  -- 好建议专用字段
  suggestion_actionable boolean DEFAULT false,  -- 是否可操作
  suggestion_direction text,  -- 改进方向
  -- 统计
  occurrence_count integer DEFAULT 1,  -- 出现次数（去重后）
  first_seen timestamptz DEFAULT now(),
  last_seen timestamptz DEFAULT now(),
  status text DEFAULT 'active',  -- active / merged / resolved
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

-- 2. 迭代报告表：存储每周自动生成的升级建议报告
CREATE TABLE IF NOT EXISTS iteration_reports (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  week_number text NOT NULL,  -- 如 "2026-W27"
  report_date date NOT NULL,  -- 生成日期
  -- 报告内容（JSON结构化）
  high_freq_questions jsonb DEFAULT '[]',  -- [{question, count, example_texts[]}]
  knowledge_gaps jsonb DEFAULT '[]',  -- [{gap_description, count, related_labels[]}]
  feature_requests jsonb DEFAULT '[]',  -- [{feature_name, count, source_texts[]}]
  competitor_mentions jsonb DEFAULT '[]',  -- [{competitor_name, count, context}]
  sentiment_summary jsonb DEFAULT '{}',  -- {satisfaction_rate, last_week_rate, top_complaints[]}
  good_suggestions jsonb DEFAULT '[]',  -- [{suggestion, source, actionable, direction}]
  -- 建议动作
  suggested_actions jsonb DEFAULT '[]',  -- [{action_type, target, description, priority}]
  -- 原始Markdown报告
  report_markdown text,
  -- 审核状态
  review_status text DEFAULT 'pending',  -- pending / approved / rejected / partial
  approved_actions jsonb DEFAULT '[]',  -- 用户批准执行的子集
  executed_at timestamptz,
  -- 统计
  total_conversations_analyzed integer DEFAULT 0,
  total_labels_generated integer DEFAULT 0,
  store_id uuid REFERENCES stores(id),
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now(),
  UNIQUE(week_number, store_id)
);

-- 3. 迭代任务表：从报告中提取的具体执行任务
CREATE TABLE IF NOT EXISTS iteration_tasks (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  report_id uuid REFERENCES iteration_reports(id),
  task_type text NOT NULL,  -- knowledge_add / knowledge_update / prompt_adjust / feature_dev / competitor_monitor
  -- 任务内容
  title text NOT NULL,
  description text,
  target_module text,  -- 影响的模块名（如"成本核算"、"客服Prompt"）
  target_file text,  -- 影响的文件路径
  -- 知识库专用
  knowledge_entry text,  -- 要新增/更新的FAQ条目
  knowledge_answer text,  -- 对应的答案
  -- Prompt专用
  prompt_section text,  -- 要调整的Prompt片段
  prompt_before text,  -- 调整前
  prompt_after text,  -- 调整后
  -- 执行状态
  priority text DEFAULT 'medium',  -- high / medium / low
  status text DEFAULT 'pending',  -- pending / approved / in_progress / completed / skipped
  approved_by text,  -- 审批人
  approved_at timestamptz,
  executed_at timestamptz,
  execution_result text,  -- 执行结果描述
  -- 溯源
  source_labels jsonb DEFAULT '[]',  -- 关联的feedback_label IDs
  evidence_texts jsonb DEFAULT '[]',  -- 支撑证据（客户原话）
  occurrence_count integer DEFAULT 1,
  metadata jsonb DEFAULT '{}',
  created_at timestamptz DEFAULT now()
);

-- 索引优化
CREATE INDEX IF NOT EXISTS idx_feedback_labels_type ON feedback_labels(label_type);
CREATE INDEX IF NOT EXISTS idx_feedback_labels_store ON feedback_labels(store_id);
CREATE INDEX IF NOT EXISTS idx_feedback_labels_status ON feedback_labels(status);
CREATE INDEX IF NOT EXISTS idx_feedback_labels_seen ON feedback_labels(last_seen);
CREATE INDEX IF NOT EXISTS idx_iteration_reports_week ON iteration_reports(week_number);
CREATE INDEX IF NOT EXISTS idx_iteration_reports_status ON iteration_reports(review_status);
CREATE INDEX IF NOT EXISTS idx_iteration_tasks_report ON iteration_tasks(report_id);
CREATE INDEX IF NOT EXISTS idx_iteration_tasks_status ON iteration_tasks(status);
CREATE INDEX IF NOT EXISTS idx_iteration_tasks_type ON iteration_tasks(task_type);

-- ========== Part 4: settlement_schema.sql ==========
-- ============================================================
-- 餐饮AI店长 - AI自主结算模块 建表SQL（纯增量）
-- 不修改现有任何表，仅新增2张表
-- 执行方式：Supabase Dashboard → SQL Editor → New Query → 粘贴执行
-- 生成时间：2026-07-05
-- ============================================================

-- ============================================================
-- 1. agent_auth（智能体结算授权表）
-- 控制每个AI Agent能花多少钱、用什么支付、是否需要老板确认
-- ============================================================
CREATE TABLE IF NOT EXISTS agent_auth (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  agent_id TEXT NOT NULL,                          -- Coze Bot ID
  agent_name TEXT NOT NULL,                         -- 显示名称
  store_id UUID REFERENCES stores(id),             -- 所属门店（NULL=全局）
  payment_channels JSONB DEFAULT '[]',              -- ["wechat","alipay"] 支持的支付渠道
  single_limit NUMERIC DEFAULT 0,                   -- 单笔限额（元）
  daily_limit NUMERIC DEFAULT 0,                    -- 日累计限额（元）
  monthly_limit NUMERIC DEFAULT 0,                  -- 月累计限额（元）
  requires_approval BOOLEAN DEFAULT true,           -- 每笔交易是否需要老板确认
  approvers JSONB DEFAULT '[]',                      -- ["老板"] 谁有权审批
  auto_approve_below NUMERIC DEFAULT 0,              -- 低于此金额自动通过（元）
  status TEXT DEFAULT 'active',                     -- active/frozen/disabled
  frozen_reason TEXT,                               -- 冻结原因
  frozen_at TIMESTAMPTZ,                            -- 冻结时间
  today_spent NUMERIC DEFAULT 0,                    -- 今日已花（运行时更新）
  today_date DATE DEFAULT CURRENT_DATE,             -- 今日日期标记
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(agent_id, store_id)
);

-- ============================================================
-- 2. settlement_records（结算记录表）
-- 每一笔AI经手的收支流水，完整存证可追溯
-- ============================================================
CREATE TABLE IF NOT EXISTS settlement_records (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  agent_id TEXT NOT NULL,                          -- 哪个Agent操作的
  agent_name TEXT NOT NULL,                         -- Agent名称（冗余，便于查询）
  store_id UUID REFERENCES stores(id),             -- 门店
  task_id TEXT,                                     -- 关联的任务/订单ID
  task_type TEXT,                                   -- order采购/procurement/营销refund/refund/other
  amount NUMERIC NOT NULL DEFAULT 0,                -- 金额（元）
  channel TEXT DEFAULT 'mock',                     -- wechat/alipay/mock
  type TEXT NOT NULL DEFAULT 'expense',             -- income收入/expense支出
  status TEXT DEFAULT 'pending',                   -- pending/confirmed/failed/cancelled
  reference_id TEXT,                                -- 第三方交易号（Mock时为本地流水号）
  description TEXT,                                 -- 这笔钱花在哪/收在哪
  approved_by TEXT,                                 -- 审批人（老板微信名等）
  approved_at TIMESTAMPTZ,                          -- 审批时间
  mock BOOLEAN DEFAULT true,                       -- true=模拟交易（未接真实支付）
  metadata JSONB DEFAULT '{}',                     -- 扩展字段（订单详情、供应商信息等）
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 3. 索引（加速查询）
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_agent_auth_agent_id ON agent_auth(agent_id);
CREATE INDEX IF NOT EXISTS idx_agent_auth_status ON agent_auth(status);
CREATE INDEX IF NOT EXISTS idx_settlement_agent_id ON settlement_records(agent_id);
CREATE INDEX IF NOT EXISTS idx_settlement_store_id ON settlement_records(store_id);
CREATE INDEX IF NOT EXISTS idx_settlement_created_at ON settlement_records(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_settlement_status ON settlement_records(status);
CREATE INDEX IF NOT EXISTS idx_settlement_type ON settlement_records(type);

-- ============================================================
-- 4. RLS 行级安全策略
-- ============================================================
ALTER TABLE agent_auth ENABLE ROW LEVEL SECURITY;
ALTER TABLE settlement_records ENABLE ROW LEVEL SECURITY;

-- 匿名用户可读（调试阶段，上线后收紧）
CREATE POLICY "anon_read_agent_auth" ON agent_auth FOR SELECT TO anon USING (true);
CREATE POLICY "anon_all_settlement_records" ON settlement_records FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================================
-- 5. 自动更新 updated_at 触发器
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_agent_auth_updated ON agent_auth;
CREATE TRIGGER trg_agent_auth_updated
  BEFORE UPDATE ON agent_auth
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- 6. 初始数据：为现有5个Agent创建默认授权配置
-- ============================================================
INSERT INTO agent_auth (agent_id, agent_name, store_id, payment_channels, single_limit, daily_limit, monthly_limit, requires_approval, approvers, auto_approve_below, status)
SELECT
  bot.id,
  bot.name,
  NULL,
  '["mock"]'::jsonb,
  100,
  500,
  5000,
  true,
  '["老板"]'::jsonb,
  20,
  'active'
FROM (VALUES
  ('7651922196432338995', '成本核算助手'),
  ('7651944084466794550', '差评处理助手'),
  ('7651952126398054435', '私域引流助手'),
  ('7651953305891405870', '小哇客服'),
  ('7652253691269103651', '语音总控')
) AS bot(id, name)
WHERE NOT EXISTS (SELECT 1 FROM agent_auth WHERE agent_id = bot.id);

-- ============================================================
-- 7. Mock交易示例数据（让审计页面一打开就有数据看）
-- ============================================================
INSERT INTO settlement_records (agent_id, agent_name, store_id, task_id, task_type, amount, channel, type, status, description, approved_by, mock, created_at)
SELECT
  r.agent_id,
  r.agent_name,
  NULL,
  'mock-task-' || gs,
  CASE (gs % 3)
    WHEN 0 THEN 'order'
    WHEN 1 THEN 'procurement'
    ELSE 'marketing'
  END,
  CASE (gs % 3)
    WHEN 0 THEN 28.50
    WHEN 1 THEN 156.00
    ELSE 5.00
  END,
  'mock',
  CASE (gs % 3)
    WHEN 0 THEN 'income'
    ELSE 'expense'
  END,
  CASE (gs % 3)
    WHEN 0 THEN 'confirmed'
    WHEN 1 THEN 'confirmed'
    ELSE 'pending'
  END,
  CASE (gs % 3)
    WHEN 0 THEN '顾客语音点餐收款'
    WHEN 1 THEN '库存预警自动采购鸡蛋5斤'
    ELSE '老客复购自动发券'
  END,
  CASE (gs % 3)
    WHEN 0 THEN 'auto'
    WHEN 1 THEN '老板'
    ELSE NULL
  END,
  true,
  NOW() - (gs || ' hours')::interval
FROM generate_series(1, 12) AS gs
CROSS JOIN (VALUES
  ('7652253691269103651', '语音总控'),
  ('7651952126398054435', '私域引流助手'),
  ('7651922196432338995', '成本核算助手')
) AS r(agent_id, agent_name)
WHERE NOT EXISTS (SELECT 1 FROM settlement_records LIMIT 1);

-- ============================================================
-- 执行完成。
-- 验证：
--   SELECT * FROM agent_auth;
--   SELECT * FROM settlement_records ORDER BY created_at DESC LIMIT 20;
-- ============================================================
