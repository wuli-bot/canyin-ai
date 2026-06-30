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
