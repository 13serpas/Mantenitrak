-- ============================================================
-- MANTENITRAK — Schema v2
-- Añade: trips, expenses (parking/seguro/multa/otros),
-- nuevos tipos de vehículo, Google Drive backup tokens,
-- filtros temporales via vistas/funciones
-- Ejecuta en SQL Editor sobre el schema v1 ya aplicado
-- ============================================================

-- ─── AMPLIAR TIPOS DE VEHÍCULO ────────────────────────────────
-- Eliminamos el CHECK anterior y lo reemplazamos con uno más amplio
ALTER TABLE public.vehicles
  DROP CONSTRAINT IF EXISTS vehicles_type_check;

ALTER TABLE public.vehicles
  ADD CONSTRAINT vehicles_type_check
  CHECK (type IN (
    'coche', 'moto', 'camion',
    'autobus', 'furgoneta', 'todoterreno',
    'caravana', 'barco', 'quad', 'otro'
  ));

-- ─── TABLA: trips ─────────────────────────────────────────────
-- Viajes con checklist pre-viaje y resumen de gastos
CREATE TABLE public.trips (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_id        UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
  user_id           UUID NOT NULL REFERENCES auth.users(id),
  name              TEXT NOT NULL,                  -- "Vacaciones Asturias", "Visita cliente Madrid"
  destination       TEXT,
  purpose           TEXT DEFAULT 'personal'         -- personal | trabajo | comercial
    CHECK (purpose IN ('personal','trabajo','comercial')),
  started_at        DATE NOT NULL DEFAULT CURRENT_DATE,
  ended_at          DATE,
  km_start          INT  NOT NULL,
  km_end            INT,
  distance_km       INT GENERATED ALWAYS AS (
    CASE WHEN km_end IS NOT NULL AND km_end > km_start
    THEN km_end - km_start ELSE NULL END
  ) STORED,
  fuel_cost         NUMERIC(8,2) DEFAULT 0,         -- suma de repostajes del viaje
  toll_cost         NUMERIC(8,2) DEFAULT 0,         -- peajes
  other_cost        NUMERIC(8,2) DEFAULT 0,         -- parking, restaurantes, etc.
  total_cost        NUMERIC(8,2) GENERATED ALWAYS AS (
    COALESCE(fuel_cost,0) + COALESCE(toll_cost,0) + COALESCE(other_cost,0)
  ) STORED,
  cost_per_km       NUMERIC(8,3),                   -- se calcula en trigger
  checklist_results JSONB DEFAULT '{}',             -- {tires: true, oil: true, ...}
  checklist_issues  TEXT[],                         -- elementos con problemas
  status            TEXT DEFAULT 'planned'
    CHECK (status IN ('planned','active','completed','cancelled')),
  notes             TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

-- ─── TABLA: expenses ──────────────────────────────────────────
-- Gastos generales del vehículo (parking, seguro, multa, ITV, etc.)
CREATE TABLE public.expenses (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_id    UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id),
  trip_id       UUID REFERENCES public.trips(id) ON DELETE SET NULL, -- gasto vinculado a viaje
  category      TEXT NOT NULL
    CHECK (category IN (
      'seguro', 'parking', 'multa', 'itv', 'lavado',
      'peaje', 'impuesto', 'matriculacion', 'reparacion',
      'accesorio', 'otros'
    )),
  amount        NUMERIC(10,2) NOT NULL CHECK (amount >= 0),
  description   TEXT,
  paid_at       DATE NOT NULL DEFAULT CURRENT_DATE,
  receipt_url   TEXT,                               -- foto de recibo en Storage
  recurrent     BOOLEAN DEFAULT FALSE,              -- gasto recurrente (ej. seguro anual)
  recurrent_months INT,                             -- cada cuántos meses se repite
  next_due_date DATE,                               -- próximo vencimiento
  provider      TEXT,                               -- aseguradora, empresa parking, etc.
  policy_number TEXT,                               -- nº póliza si es seguro
  notes         TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ─── TABLA: google_drive_tokens ───────────────────────────────
-- Almacena tokens OAuth de Google Drive por usuario (cifrados)
CREATE TABLE public.google_drive_tokens (
  user_id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  access_token     TEXT,                            -- cifrado en app antes de guardar
  refresh_token    TEXT,                            -- cifrado en app
  token_expiry     TIMESTAMPTZ,
  drive_folder_id  TEXT,                            -- ID de carpeta en Drive
  last_backup_at   TIMESTAMPTZ,
  backup_file_id   TEXT,                            -- último archivo de backup en Drive
  created_at       TIMESTAMPTZ DEFAULT NOW(),
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

-- ─── TABLA: backup_logs ───────────────────────────────────────
CREATE TABLE public.backup_logs (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id     UUID NOT NULL REFERENCES auth.users(id),
  type        TEXT CHECK (type IN ('google_drive','local','export')),
  status      TEXT CHECK (status IN ('success','failed','partial')),
  file_name   TEXT,
  file_size   BIGINT,                               -- bytes
  records_count INT,
  error_msg   TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ─── ÍNDICES ──────────────────────────────────────────────────
CREATE INDEX idx_trips_vehicle       ON public.trips(vehicle_id, started_at DESC);
CREATE INDEX idx_trips_user          ON public.trips(user_id);
CREATE INDEX idx_trips_status        ON public.trips(status);
CREATE INDEX idx_expenses_vehicle    ON public.expenses(vehicle_id, paid_at DESC);
CREATE INDEX idx_expenses_category   ON public.expenses(vehicle_id, category);
CREATE INDEX idx_expenses_trip       ON public.expenses(trip_id);
CREATE INDEX idx_expenses_recurrent  ON public.expenses(recurrent, next_due_date)
  WHERE recurrent = TRUE;

-- ─── RLS ──────────────────────────────────────────────────────
ALTER TABLE public.trips                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses              ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.google_drive_tokens   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.backup_logs           ENABLE ROW LEVEL SECURITY;

-- trips
CREATE POLICY "Ver viajes si tiene acceso al vehículo"
  ON public.trips FOR SELECT
  USING (public.has_vehicle_access(vehicle_id));

CREATE POLICY "Insertar viaje si tiene acceso"
  ON public.trips FOR INSERT
  WITH CHECK (public.has_vehicle_access(vehicle_id) AND user_id = auth.uid());

CREATE POLICY "Actualizar viaje propio"
  ON public.trips FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Eliminar viaje propio"
  ON public.trips FOR DELETE
  USING (user_id = auth.uid());

-- expenses
CREATE POLICY "Ver gastos si tiene acceso al vehículo"
  ON public.expenses FOR SELECT
  USING (public.has_vehicle_access(vehicle_id));

CREATE POLICY "Insertar gasto si tiene acceso"
  ON public.expenses FOR INSERT
  WITH CHECK (public.has_vehicle_access(vehicle_id) AND user_id = auth.uid());

CREATE POLICY "Actualizar gasto propio"
  ON public.expenses FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Eliminar gasto propio"
  ON public.expenses FOR DELETE
  USING (user_id = auth.uid());

-- google_drive_tokens — solo el propio usuario
CREATE POLICY "Solo acceso propio a tokens Drive"
  ON public.google_drive_tokens FOR ALL
  USING (user_id = auth.uid());

CREATE POLICY "Solo acceso propio a backup_logs"
  ON public.backup_logs FOR ALL
  USING (user_id = auth.uid());

-- ─── TRIGGER: calcular cost_per_km al cerrar viaje ────────────
CREATE OR REPLACE FUNCTION public.calculate_trip_cost_per_km()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.km_end IS NOT NULL AND NEW.km_end > NEW.km_start THEN
    NEW.cost_per_km := ROUND(
      NEW.total_cost / (NEW.km_end - NEW.km_start)::NUMERIC, 3
    );
    -- Insertar km_log automáticamente al cerrar el viaje
    IF OLD.km_end IS NULL AND NEW.km_end IS NOT NULL THEN
      INSERT INTO public.km_logs (vehicle_id, user_id, km, logged_at)
      VALUES (NEW.vehicle_id, NEW.user_id, NEW.km_end, NEW.ended_at)
      ON CONFLICT DO NOTHING;
      -- Actualizar current_km del vehículo
      UPDATE public.vehicles
        SET current_km = NEW.km_end
        WHERE id = NEW.vehicle_id AND (current_km IS NULL OR current_km < NEW.km_end);
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_trip_cost_per_km
  BEFORE UPDATE ON public.trips
  FOR EACH ROW EXECUTE FUNCTION public.calculate_trip_cost_per_km();

-- Updated_at para nuevas tablas
CREATE TRIGGER trg_trips_updated_at
  BEFORE UPDATE ON public.trips
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER trg_drive_tokens_updated_at
  BEFORE UPDATE ON public.google_drive_tokens
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ─── FUNCIÓN: resumen de gastos por período ───────────────────
-- Devuelve totales agrupados por categoría para un período dado
-- period: 'month', 'quarter', 'semester', 'year', 'ytd', 'custom'
CREATE OR REPLACE FUNCTION public.get_expense_summary(
  p_vehicle_id  UUID,
  p_period      TEXT DEFAULT 'month',
  p_year        INT  DEFAULT NULL,    -- NULL = año actual
  p_month       INT  DEFAULT NULL,    -- para period='month'
  p_quarter     INT  DEFAULT NULL,    -- 1-4 para period='quarter'
  p_date_from   DATE DEFAULT NULL,    -- para period='custom'
  p_date_to     DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
DECLARE
  v_year   INT := COALESCE(p_year, EXTRACT(YEAR FROM NOW())::INT);
  v_from   DATE;
  v_to     DATE;
  v_result JSONB;
BEGIN
  -- Calcular rango de fechas según período
  CASE p_period
    WHEN 'month' THEN
      v_from := make_date(v_year, COALESCE(p_month, EXTRACT(MONTH FROM NOW())::INT), 1);
      v_to   := (v_from + INTERVAL '1 month - 1 day')::DATE;
    WHEN 'quarter' THEN
      DECLARE v_q INT := COALESCE(p_quarter, CEIL(EXTRACT(MONTH FROM NOW())/3.0)::INT);
      BEGIN
        v_from := make_date(v_year, (v_q-1)*3+1, 1);
        v_to   := (v_from + INTERVAL '3 months - 1 day')::DATE;
      END;
    WHEN 'semester' THEN
      IF EXTRACT(MONTH FROM NOW()) <= 6 OR p_month <= 6 THEN
        v_from := make_date(v_year, 1, 1); v_to := make_date(v_year, 6, 30);
      ELSE
        v_from := make_date(v_year, 7, 1); v_to := make_date(v_year, 12, 31);
      END IF;
    WHEN 'year' THEN
      v_from := make_date(v_year, 1, 1); v_to := make_date(v_year, 12, 31);
    WHEN 'ytd' THEN
      v_from := make_date(EXTRACT(YEAR FROM NOW())::INT, 1, 1);
      v_to   := NOW()::DATE;
    WHEN 'custom' THEN
      v_from := p_date_from; v_to := p_date_to;
    ELSE
      v_from := make_date(v_year, 1, 1); v_to := make_date(v_year, 12, 31);
  END CASE;

  SELECT jsonb_build_object(
    'period',     p_period,
    'date_from',  v_from,
    'date_to',    v_to,
    'totals', (
      SELECT jsonb_object_agg(category, total) FROM (
        SELECT category, ROUND(SUM(amount)::NUMERIC, 2) AS total
        FROM public.expenses
        WHERE vehicle_id = p_vehicle_id
          AND paid_at BETWEEN v_from AND v_to
          AND public.has_vehicle_access(p_vehicle_id)
        GROUP BY category
      ) cats
    ),
    'maintenance_total', (
      SELECT ROUND(COALESCE(SUM(cost),0)::NUMERIC, 2)
      FROM public.maintenance_records
      WHERE vehicle_id = p_vehicle_id
        AND performed_at BETWEEN v_from AND v_to
    ),
    'fuel_total', (
      SELECT ROUND(COALESCE(SUM(total),0)::NUMERIC, 2)
      FROM public.fuel_logs
      WHERE vehicle_id = p_vehicle_id
        AND logged_at BETWEEN v_from AND v_to
    ),
    'trip_total', (
      SELECT ROUND(COALESCE(SUM(total_cost),0)::NUMERIC, 2)
      FROM public.trips
      WHERE vehicle_id = p_vehicle_id
        AND started_at BETWEEN v_from AND v_to
        AND status = 'completed'
    ),
    'monthly_breakdown', (
      SELECT jsonb_agg(row_to_json(m)) FROM (
        SELECT
          TO_CHAR(month_start, 'YYYY-MM') AS month,
          ROUND(COALESCE(SUM(e.amount),0)::NUMERIC,2) AS expenses,
          ROUND(COALESCE((
            SELECT SUM(cost) FROM public.maintenance_records mr
            WHERE mr.vehicle_id = p_vehicle_id
              AND DATE_TRUNC('month', mr.performed_at::TIMESTAMPTZ) = month_start
          ),0)::NUMERIC,2) AS maintenance,
          ROUND(COALESCE((
            SELECT SUM(total) FROM public.fuel_logs fl
            WHERE fl.vehicle_id = p_vehicle_id
              AND DATE_TRUNC('month', fl.logged_at::TIMESTAMPTZ) = month_start
          ),0)::NUMERIC,2) AS fuel
        FROM generate_series(v_from, v_to, '1 month'::INTERVAL) AS month_start
        LEFT JOIN public.expenses e ON e.vehicle_id = p_vehicle_id
          AND DATE_TRUNC('month', e.paid_at::TIMESTAMPTZ) = month_start
        GROUP BY month_start
        ORDER BY month_start
      ) m
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- ─── FUNCIÓN: próximos gastos recurrentes ─────────────────────
CREATE OR REPLACE FUNCTION public.get_upcoming_expenses(
  p_vehicle_id UUID,
  p_days_ahead INT DEFAULT 30
)
RETURNS TABLE (
  id           UUID,
  category     TEXT,
  description  TEXT,
  amount       NUMERIC,
  next_due_date DATE,
  days_remaining INT,
  provider     TEXT
)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT
    id, category, description, amount, next_due_date,
    (next_due_date - CURRENT_DATE)::INT AS days_remaining,
    provider
  FROM public.expenses
  WHERE vehicle_id = p_vehicle_id
    AND recurrent = TRUE
    AND next_due_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + p_days_ahead)
    AND public.has_vehicle_access(p_vehicle_id)
  ORDER BY next_due_date ASC;
$$;

-- ─── VISTA AMPLIADA: vehicle_summary v2 ───────────────────────
DROP VIEW IF EXISTS public.vehicle_summary;

CREATE VIEW public.vehicle_summary AS
SELECT
  v.id, v.owner_id, v.type, v.brand, v.model, v.year,
  v.engine, v.plate, v.fuel_type, v.usage, v.role, v.zone,
  v.current_km, v.annual_km, v.share_code, v.added_at,
  -- km log
  (SELECT km        FROM public.km_logs    WHERE vehicle_id = v.id ORDER BY logged_at DESC LIMIT 1) AS last_km_log,
  (SELECT logged_at FROM public.km_logs    WHERE vehicle_id = v.id ORDER BY logged_at DESC LIMIT 1) AS last_km_date,
  -- gastos totales por tipo
  (SELECT COALESCE(SUM(cost),  0) FROM public.maintenance_records WHERE vehicle_id = v.id) AS total_maintenance,
  (SELECT COALESCE(SUM(total), 0) FROM public.fuel_logs           WHERE vehicle_id = v.id) AS total_fuel,
  (SELECT COALESCE(SUM(amount),0) FROM public.expenses            WHERE vehicle_id = v.id) AS total_expenses,
  (SELECT COALESCE(SUM(total_cost),0) FROM public.trips           WHERE vehicle_id = v.id AND status='completed') AS total_trips,
  -- gastos YTD
  (SELECT COALESCE(SUM(cost),  0) FROM public.maintenance_records WHERE vehicle_id = v.id AND EXTRACT(YEAR FROM performed_at)=EXTRACT(YEAR FROM NOW())) AS ytd_maintenance,
  (SELECT COALESCE(SUM(total), 0) FROM public.fuel_logs           WHERE vehicle_id = v.id AND EXTRACT(YEAR FROM logged_at)=EXTRACT(YEAR FROM NOW())) AS ytd_fuel,
  (SELECT COALESCE(SUM(amount),0) FROM public.expenses            WHERE vehicle_id = v.id AND EXTRACT(YEAR FROM paid_at)=EXTRACT(YEAR FROM NOW())) AS ytd_expenses,
  -- conteos
  (SELECT COUNT(*) FROM public.shared_vehicles WHERE vehicle_id = v.id) AS shared_count,
  (SELECT COUNT(*) FROM public.trips WHERE vehicle_id = v.id AND status='completed') AS total_trips_count,
  -- próximos gastos recurrentes
  (SELECT COUNT(*) FROM public.expenses WHERE vehicle_id = v.id AND recurrent=TRUE AND next_due_date <= CURRENT_DATE + 30) AS upcoming_expenses_count
FROM public.vehicles v;
