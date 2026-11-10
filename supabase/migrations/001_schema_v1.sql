-- ============================================================
-- MANTENITRAK — Supabase Schema
-- Ejecuta este SQL en el SQL Editor de tu proyecto Supabase
-- Orden: extensiones → tablas → índices → RLS → políticas → funciones
-- ============================================================

-- ─── EXTENSIONES ─────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- búsqueda de texto fuzzy

-- ─── TABLA: profiles ─────────────────────────────────────────
-- Extiende auth.users con datos del perfil de usuario
CREATE TABLE public.profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name  TEXT,
  avatar_url    TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ─── TABLA: vehicles ─────────────────────────────────────────
CREATE TABLE public.vehicles (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type          TEXT NOT NULL CHECK (type IN ('coche','moto','camion')),
  brand         TEXT NOT NULL,
  model         TEXT NOT NULL,
  year          INT  NOT NULL CHECK (year BETWEEN 1900 AND 2100),
  engine        TEXT,
  plate         TEXT,
  fuel_type     TEXT,
  usage         TEXT,
  role          TEXT NOT NULL DEFAULT 'owner' CHECK (role IN ('owner','regular','company','mechanic')),
  zone          TEXT NOT NULL DEFAULT 'interior' CHECK (zone IN ('interior','costa','montana','mixto','norte')),
  current_km    INT,
  annual_km     INT,
  share_code    TEXT UNIQUE DEFAULT upper(substring(md5(random()::text) from 1 for 6)),
  added_at      DATE DEFAULT CURRENT_DATE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ─── TABLA: vehicle_specs ────────────────────────────────────
CREATE TABLE public.vehicle_specs (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_id        UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
  oil_type          TEXT,
  oil_liters        NUMERIC(4,2),
  oil_brands        TEXT[],          -- array de marcas recomendadas
  oil_filter_ref    TEXT,
  air_filter_ref    TEXT,
  cabin_filter_ref  TEXT,
  fuel_filter_ref   TEXT,
  spark_plug_ref    TEXT,
  tire_size_front   TEXT,
  tire_size_rear    TEXT,
  tire_brand        TEXT,
  battery_spec      TEXT,
  notes             TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(vehicle_id)
);

-- ─── TABLA: km_logs ──────────────────────────────────────────
-- Historial de lecturas del odómetro para calcular km/año real
CREATE TABLE public.km_logs (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_id  UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES auth.users(id),
  km          INT  NOT NULL CHECK (km >= 0),
  logged_at   DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ─── TABLA: maintenance_records ──────────────────────────────
CREATE TABLE public.maintenance_records (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_id  UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES auth.users(id),
  item_id     TEXT NOT NULL,   -- aceite, filtro_aire, frenos_delanteros…
  item_name   TEXT,            -- nombre legible, desnormalizado para informes
  performed_at DATE NOT NULL DEFAULT CURRENT_DATE,
  km          INT,
  cost        NUMERIC(8,2),
  notes       TEXT,
  photos      TEXT[],          -- URLs de Storage
  tire_analysis JSONB,         -- resultado del análisis IA de neumáticos
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ─── TABLA: fuel_logs ────────────────────────────────────────
CREATE TABLE public.fuel_logs (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_id      UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES auth.users(id),
  logged_at       DATE NOT NULL DEFAULT CURRENT_DATE,
  km              INT,
  liters          NUMERIC(6,3),
  price_per_liter NUMERIC(5,3),
  total           NUMERIC(7,2),
  fuel_type       TEXT,
  full_tank       BOOLEAN DEFAULT TRUE,
  station         TEXT,
  consumption_l100 NUMERIC(5,2), -- calculado al insertar o actualizar
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ─── TABLA: shared_vehicles ──────────────────────────────────
-- Vehículos compartidos con otros usuarios (mediante share_code)
CREATE TABLE public.shared_vehicles (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_id  UUID NOT NULL REFERENCES public.vehicles(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role        TEXT NOT NULL DEFAULT 'regular' CHECK (role IN ('regular','company','mechanic')),
  joined_at   TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(vehicle_id, user_id)
);

-- ─── ÍNDICES ─────────────────────────────────────────────────
CREATE INDEX idx_vehicles_owner         ON public.vehicles(owner_id);
CREATE INDEX idx_vehicles_share_code    ON public.vehicles(share_code);
CREATE INDEX idx_km_logs_vehicle        ON public.km_logs(vehicle_id, logged_at DESC);
CREATE INDEX idx_maintenance_vehicle    ON public.maintenance_records(vehicle_id, performed_at DESC);
CREATE INDEX idx_maintenance_item       ON public.maintenance_records(vehicle_id, item_id);
CREATE INDEX idx_fuel_vehicle           ON public.fuel_logs(vehicle_id, logged_at DESC);
CREATE INDEX idx_shared_user            ON public.shared_vehicles(user_id);
CREATE INDEX idx_shared_vehicle         ON public.shared_vehicles(vehicle_id);

-- ─── ROW LEVEL SECURITY ──────────────────────────────────────
ALTER TABLE public.profiles           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicle_specs      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.km_logs            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.maintenance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fuel_logs          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shared_vehicles    ENABLE ROW LEVEL SECURITY;

-- ─── FUNCIÓN HELPER: ¿tiene acceso al vehículo? ──────────────
-- Devuelve true si el usuario es propietario O tiene acceso compartido
CREATE OR REPLACE FUNCTION public.has_vehicle_access(p_vehicle_id UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.vehicles
    WHERE id = p_vehicle_id AND owner_id = auth.uid()
  ) OR EXISTS (
    SELECT 1 FROM public.shared_vehicles
    WHERE vehicle_id = p_vehicle_id AND user_id = auth.uid()
  );
$$;

-- ─── POLÍTICAS: profiles ─────────────────────────────────────
CREATE POLICY "Usuarios ven su propio perfil"
  ON public.profiles FOR SELECT
  USING (id = auth.uid());

CREATE POLICY "Usuarios actualizan su propio perfil"
  ON public.profiles FOR UPDATE
  USING (id = auth.uid());

CREATE POLICY "Insertar perfil propio"
  ON public.profiles FOR INSERT
  WITH CHECK (id = auth.uid());

-- ─── POLÍTICAS: vehicles ─────────────────────────────────────
CREATE POLICY "Ver vehículos propios y compartidos"
  ON public.vehicles FOR SELECT
  USING (public.has_vehicle_access(id));

CREATE POLICY "Insertar vehículos propios"
  ON public.vehicles FOR INSERT
  WITH CHECK (owner_id = auth.uid());

CREATE POLICY "Actualizar vehículos propios"
  ON public.vehicles FOR UPDATE
  USING (owner_id = auth.uid());

CREATE POLICY "Eliminar vehículos propios"
  ON public.vehicles FOR DELETE
  USING (owner_id = auth.uid());

-- ─── POLÍTICAS: vehicle_specs ────────────────────────────────
CREATE POLICY "Ver specs si tiene acceso al vehículo"
  ON public.vehicle_specs FOR SELECT
  USING (public.has_vehicle_access(vehicle_id));

CREATE POLICY "Insertar/actualizar specs si es propietario"
  ON public.vehicle_specs FOR ALL
  USING (EXISTS (SELECT 1 FROM public.vehicles WHERE id = vehicle_id AND owner_id = auth.uid()));

-- ─── POLÍTICAS: km_logs ──────────────────────────────────────
CREATE POLICY "Ver km_logs si tiene acceso al vehículo"
  ON public.km_logs FOR SELECT
  USING (public.has_vehicle_access(vehicle_id));

CREATE POLICY "Insertar km_logs si tiene acceso"
  ON public.km_logs FOR INSERT
  WITH CHECK (public.has_vehicle_access(vehicle_id) AND user_id = auth.uid());

CREATE POLICY "Eliminar propio km_log"
  ON public.km_logs FOR DELETE
  USING (user_id = auth.uid());

-- ─── POLÍTICAS: maintenance_records ─────────────────────────
CREATE POLICY "Ver mantenimientos si tiene acceso al vehículo"
  ON public.maintenance_records FOR SELECT
  USING (public.has_vehicle_access(vehicle_id));

CREATE POLICY "Insertar mantenimiento si tiene acceso"
  ON public.maintenance_records FOR INSERT
  WITH CHECK (public.has_vehicle_access(vehicle_id) AND user_id = auth.uid());

CREATE POLICY "Eliminar mantenimiento propio"
  ON public.maintenance_records FOR DELETE
  USING (user_id = auth.uid());

CREATE POLICY "Actualizar mantenimiento propio"
  ON public.maintenance_records FOR UPDATE
  USING (user_id = auth.uid());

-- ─── POLÍTICAS: fuel_logs ────────────────────────────────────
CREATE POLICY "Ver repostajes si tiene acceso al vehículo"
  ON public.fuel_logs FOR SELECT
  USING (public.has_vehicle_access(vehicle_id));

CREATE POLICY "Insertar repostaje si tiene acceso"
  ON public.fuel_logs FOR INSERT
  WITH CHECK (public.has_vehicle_access(vehicle_id) AND user_id = auth.uid());

CREATE POLICY "Eliminar repostaje propio"
  ON public.fuel_logs FOR DELETE
  USING (user_id = auth.uid());

-- ─── POLÍTICAS: shared_vehicles ──────────────────────────────
CREATE POLICY "Ver shares propios o de mis vehículos"
  ON public.shared_vehicles FOR SELECT
  USING (
    user_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.vehicles WHERE id = vehicle_id AND owner_id = auth.uid())
  );

CREATE POLICY "Unirse mediante share_code (INSERT propio)"
  ON public.shared_vehicles FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Propietario puede eliminar accesos"
  ON public.shared_vehicles FOR DELETE
  USING (
    user_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.vehicles WHERE id = vehicle_id AND owner_id = auth.uid())
  );

-- ─── FUNCIÓN: join por share_code ────────────────────────────
CREATE OR REPLACE FUNCTION public.join_vehicle_by_code(
  p_code TEXT,
  p_role TEXT DEFAULT 'regular'
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_vehicle public.vehicles;
BEGIN
  -- Buscar el vehículo por código
  SELECT * INTO v_vehicle FROM public.vehicles WHERE share_code = upper(p_code);
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Código no válido');
  END IF;
  -- Evitar que el propietario se una a su propio vehículo
  IF v_vehicle.owner_id = auth.uid() THEN
    RETURN jsonb_build_object('error', 'Ya eres el propietario de este vehículo');
  END IF;
  -- Insertar o actualizar rol
  INSERT INTO public.shared_vehicles (vehicle_id, user_id, role)
  VALUES (v_vehicle.id, auth.uid(), p_role)
  ON CONFLICT (vehicle_id, user_id) DO UPDATE SET role = p_role;

  RETURN jsonb_build_object(
    'success', true,
    'vehicle_id', v_vehicle.id,
    'brand', v_vehicle.brand,
    'model', v_vehicle.model
  );
END;
$$;

-- ─── FUNCIÓN: calcular consumo al insertar repostaje ─────────
CREATE OR REPLACE FUNCTION public.calculate_fuel_consumption()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  prev_log public.fuel_logs;
BEGIN
  -- Solo calcular si es depósito lleno y tiene km
  IF NEW.full_tank AND NEW.km IS NOT NULL THEN
    SELECT * INTO prev_log
    FROM public.fuel_logs
    WHERE vehicle_id = NEW.vehicle_id
      AND full_tank = TRUE
      AND km < NEW.km
    ORDER BY km DESC
    LIMIT 1;

    IF FOUND AND prev_log.km IS NOT NULL AND prev_log.liters IS NOT NULL THEN
      NEW.consumption_l100 := ROUND(
        (NEW.liters / (NEW.km - prev_log.km)::NUMERIC) * 100,
        2
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_fuel_consumption
  BEFORE INSERT ON public.fuel_logs
  FOR EACH ROW EXECUTE FUNCTION public.calculate_fuel_consumption();

-- ─── FUNCIÓN: actualizar updated_at automáticamente ──────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;

CREATE TRIGGER trg_vehicles_updated_at     BEFORE UPDATE ON public.vehicles      FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_specs_updated_at        BEFORE UPDATE ON public.vehicle_specs  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_profiles_updated_at     BEFORE UPDATE ON public.profiles       FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ─── FUNCIÓN: crear perfil al registrarse ────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)));
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ─── STORAGE BUCKETS ─────────────────────────────────────────
-- Ejecuta esto en Supabase Dashboard > Storage o vía API
-- INSERT INTO storage.buckets (id, name, public) VALUES ('maintenance-photos', 'maintenance-photos', false);
-- INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true);

-- Políticas de Storage (ejecutar tras crear los buckets):
-- CREATE POLICY "Fotos propias accesibles"
--   ON storage.objects FOR SELECT
--   USING (bucket_id = 'maintenance-photos' AND auth.uid()::text = (storage.foldername(name))[1]);
-- CREATE POLICY "Subir foto propia"
--   ON storage.objects FOR INSERT
--   WITH CHECK (bucket_id = 'maintenance-photos' AND auth.uid()::text = (storage.foldername(name))[1]);
-- CREATE POLICY "Eliminar foto propia"
--   ON storage.objects FOR DELETE
--   USING (bucket_id = 'maintenance-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

-- ─── VISTA: vehicle_summary ──────────────────────────────────
-- Útil para el home: vehículo + último km + total gastado
CREATE VIEW public.vehicle_summary AS
SELECT
  v.id,
  v.owner_id,
  v.type,
  v.brand,
  v.model,
  v.year,
  v.engine,
  v.plate,
  v.fuel_type,
  v.usage,
  v.role,
  v.zone,
  v.current_km,
  v.annual_km,
  v.share_code,
  v.added_at,
  (SELECT km FROM public.km_logs WHERE vehicle_id = v.id ORDER BY logged_at DESC LIMIT 1) AS last_km_log,
  (SELECT logged_at FROM public.km_logs WHERE vehicle_id = v.id ORDER BY logged_at DESC LIMIT 1) AS last_km_date,
  (SELECT COALESCE(SUM(cost), 0) FROM public.maintenance_records WHERE vehicle_id = v.id) AS total_maintenance_cost,
  (SELECT COALESCE(SUM(total), 0) FROM public.fuel_logs WHERE vehicle_id = v.id) AS total_fuel_cost,
  (SELECT COUNT(*) FROM public.shared_vehicles WHERE vehicle_id = v.id) AS shared_count
FROM public.vehicles v;
