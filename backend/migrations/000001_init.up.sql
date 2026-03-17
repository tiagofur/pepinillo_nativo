CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  password_hash TEXT NOT NULL,
  image_url TEXT,
  birth_date TIMESTAMPTZ,
  subscription_tier VARCHAR(50) NOT NULL DEFAULT 'free',
  subscription_expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tasks (
  id SERIAL PRIMARY KEY,
  sync_id VARCHAR(255) UNIQUE NOT NULL,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(255),
  description TEXT,
  created_date TIMESTAMPTZ,
  finish_date TIMESTAMPTZ,
  is_finished BOOLEAN NOT NULL DEFAULT FALSE,
  priority SMALLINT NOT NULL DEFAULT 0,
  category VARCHAR(100),
  estimated_pomodoros INTEGER NOT NULL DEFAULT 0,
  completed_pomodoros INTEGER NOT NULL DEFAULT 0,
  focused_seconds INTEGER NOT NULL DEFAULT 0,
  active_session_id VARCHAR(255),
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_updated_at ON tasks(updated_at);

CREATE TABLE IF NOT EXISTS subtasks (
  id SERIAL PRIMARY KEY,
  task_id INTEGER NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  title VARCHAR(255),
  is_finished BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_subtasks_task_id ON subtasks(task_id);

CREATE TABLE IF NOT EXISTS pomodoro_configs (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  pomodoro_time INTEGER NOT NULL DEFAULT 25,
  break_time INTEGER NOT NULL DEFAULT 5,
  rest_time INTEGER NOT NULL DEFAULT 15,
  qty_pomodoros INTEGER NOT NULL DEFAULT 4,
  daily_goal INTEGER NOT NULL DEFAULT 8,
  notifications BOOLEAN NOT NULL DEFAULT FALSE,
  auto_pomodoro BOOLEAN NOT NULL DEFAULT FALSE,
  auto_break BOOLEAN NOT NULL DEFAULT FALSE,
  last_update TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pomodoro_stats (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  pomodoros INTEGER NOT NULL DEFAULT 0,
  pomodoro_duration INTEGER NOT NULL DEFAULT 0,
  breaks INTEGER NOT NULL DEFAULT 0,
  break_duration INTEGER NOT NULL DEFAULT 0,
  rests INTEGER NOT NULL DEFAULT 0,
  rest_duration INTEGER NOT NULL DEFAULT 0,
  daily_goal INTEGER NOT NULL DEFAULT 0,
  daily_completed BOOLEAN NOT NULL DEFAULT FALSE,
  count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT uq_pomodoro_stats_user_date UNIQUE (user_id, date)
);

CREATE INDEX IF NOT EXISTS idx_pomodoro_stats_user_id ON pomodoro_stats(user_id);

CREATE TABLE IF NOT EXISTS pomodoro_sessions (
  id VARCHAR(255) PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  task_id INTEGER REFERENCES tasks(id) ON DELETE SET NULL,
  started_at TIMESTAMPTZ NOT NULL,
  ended_at TIMESTAMPTZ,
  phase VARCHAR(50) NOT NULL,
  duration_seconds INTEGER NOT NULL,
  elapsed_seconds INTEGER NOT NULL,
  pause_count INTEGER NOT NULL DEFAULT 0,
  total_pause_seconds INTEGER NOT NULL DEFAULT 0,
  was_completed BOOLEAN NOT NULL DEFAULT FALSE,
  shared_with_task_ids TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pomodoro_sessions_user_id ON pomodoro_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_pomodoro_sessions_task_id ON pomodoro_sessions(task_id);
CREATE INDEX IF NOT EXISTS idx_pomodoro_sessions_started_at ON pomodoro_sessions(started_at);

CREATE TABLE IF NOT EXISTS ai_insights (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type VARCHAR(100) NOT NULL,
  title VARCHAR(255) NOT NULL,
  content TEXT NOT NULL,
  data_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  generated_at TIMESTAMPTZ NOT NULL,
  expires_at TIMESTAMPTZ,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_insights_user_id ON ai_insights(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_insights_generated_at ON ai_insights(generated_at);

CREATE TABLE IF NOT EXISTS user_behavior_log (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_type VARCHAR(100) NOT NULL,
  event_data JSONB NOT NULL DEFAULT '{}'::jsonb,
  timestamp TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_behavior_log_user_event_ts ON user_behavior_log(user_id, event_type, timestamp);
