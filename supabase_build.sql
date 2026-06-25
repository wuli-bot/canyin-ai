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
