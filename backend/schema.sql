-- Usuarios identificados por su cuenta de Google. No guardamos contraseñas:
-- la identidad la verifica Google, nosotros solo guardamos el "sub" (su ID
-- estable de cuenta) para no depender de que el email no cambie nunca.
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  google_sub TEXT UNIQUE NOT NULL,
  email TEXT NOT NULL,
  display_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Una fila por sesión de nado. external_id es el `id` que ya genera
-- SwimSession en la app (hoy: epoch ms del inicio, ver swim_session.dart) —
-- se usa junto con user_id para que volver a subir la misma sesión actualice
-- en vez de duplicar.
CREATE TABLE IF NOT EXISTS swim_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  external_id TEXT NOT NULL,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  distance DOUBLE PRECISION NOT NULL DEFAULT 0,
  calories DOUBLE PRECISION NOT NULL DEFAULT 0,
  average_heart_rate DOUBLE PRECISION,
  max_heart_rate DOUBLE PRECISION,
  spo2 DOUBLE PRECISION,
  water_temperature DOUBLE PRECISION,
  average_speed DOUBLE PRECISION,
  activity_type TEXT,
  -- Series/listas anidadas: se guardan tal cual las manda la app (mismo JSON
  -- que ya producen los toJson() de swim_session.dart). Nada las consulta
  -- todavía por adentro, así que normalizarlas en tablas propias hoy sería
  -- trabajo sin uso real.
  heart_rate_series JSONB NOT NULL DEFAULT '[]',
  laps JSONB NOT NULL DEFAULT '[]',
  segments JSONB NOT NULL DEFAULT '[]',
  speed_series JSONB NOT NULL DEFAULT '[]',
  spo2_series JSONB NOT NULL DEFAULT '[]',
  calorie_series JSONB NOT NULL DEFAULT '[]',
  step_series JSONB NOT NULL DEFAULT '[]',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, external_id)
);

-- ALTERs idempotentes para bases ya creadas con un schema.sql anterior (no
-- hay sistema de migraciones aparte — este archivo se vuelve a correr entero
-- con `npm run migrate` y debe ser seguro de repetir).
ALTER TABLE swim_sessions ADD COLUMN IF NOT EXISTS calorie_series JSONB NOT NULL DEFAULT '[]';
ALTER TABLE swim_sessions ADD COLUMN IF NOT EXISTS step_series JSONB NOT NULL DEFAULT '[]';

CREATE INDEX IF NOT EXISTS swim_sessions_user_start_idx
  ON swim_sessions (user_id, start_time DESC);
