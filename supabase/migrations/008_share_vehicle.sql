-- ============================================================
-- MANTENITRAK — Migración 008: compartir vehículos (punto 7)
-- Ejecutar después de 007. Idempotente.
--
-- Cambios respecto a la 003:
--  · El código ya no vive en `vehicles.share_code`: esa columna la podía
--    leer cualquiera con acceso (un taller podía reenviarlo). Ahora está
--    en `vehicle_invites`, que solo se lee a través de funciones y solo
--    el propietario.
--  · Los códigos caducan (7 días por defecto) y se pueden renovar.
--  · Unirse lanza errores normales (código 22023), salvo con un código
--    inexistente o caducado: entonces devuelve la columna `error`, porque
--    un error desharía el registro del intento fallido.
--  · Lista de personas con acceso con su nombre, cambio de rol por el
--    propietario (unirse otra vez no lo cambia) y límite de 20 personas.
-- ============================================================

-- ─── 1. Invitaciones ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.vehicle_invites (
  vehicle_id  UUID PRIMARY KEY REFERENCES public.vehicles(id) ON DELETE CASCADE,
  code        TEXT NOT NULL UNIQUE,
  created_by  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at  TIMESTAMPTZ NOT NULL
);
ALTER TABLE public.vehicle_invites ENABLE ROW LEVEL SECURITY;  -- sin políticas: solo vía funciones
REVOKE ALL ON public.vehicle_invites FROM anon, authenticated;

-- El código antiguo deja de usarse y de generarse.
DROP TRIGGER IF EXISTS trg_vehicles_share_code ON public.vehicles;
ALTER TABLE public.vehicles ALTER COLUMN share_code DROP DEFAULT;
UPDATE public.vehicles SET share_code = NULL WHERE share_code IS NOT NULL;

-- ─── 2. Código vigente (lo crea si no hay o ha caducado) ─────
CREATE OR REPLACE FUNCTION public.get_share_invite(p_vehicle_id UUID)
RETURNS TABLE (code TEXT, expires_at TIMESTAMPTZ)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_inv public.vehicle_invites;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.vehicles WHERE id = p_vehicle_id AND owner_id = auth.uid()) THEN
    RAISE EXCEPTION 'Solo el propietario puede compartir este vehículo' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO v_inv FROM public.vehicle_invites i WHERE i.vehicle_id = p_vehicle_id;
  IF NOT FOUND OR v_inv.expires_at <= NOW() THEN
    RETURN QUERY SELECT * FROM public.regenerate_share_code(p_vehicle_id);
    RETURN;
  END IF;
  RETURN QUERY SELECT v_inv.code, v_inv.expires_at;
END;
$$;

-- ─── 3. Código nuevo (invalida el anterior) ──────────────────
-- La 003 devolvía TEXT: hay que borrarla para cambiar el tipo.
DROP FUNCTION IF EXISTS public.regenerate_share_code(UUID);
DROP FUNCTION IF EXISTS public.regenerate_share_code(UUID, INT);
CREATE FUNCTION public.regenerate_share_code(p_vehicle_id UUID, p_days INT DEFAULT 7)
RETURNS TABLE (code TEXT, expires_at TIMESTAMPTZ)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_code TEXT;
  v_exp  TIMESTAMPTZ;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.vehicles WHERE id = p_vehicle_id AND owner_id = auth.uid()) THEN
    RAISE EXCEPTION 'Solo el propietario puede compartir este vehículo' USING ERRCODE = '42501';
  END IF;
  IF p_days IS NULL OR p_days < 1 OR p_days > 30 THEN
    RAISE EXCEPTION 'La validez debe ser de 1 a 30 días' USING ERRCODE = '22023';
  END IF;
  v_exp := NOW() + make_interval(days => p_days);
  -- Reintenta en el caso (rarísimo) de que el código ya exista.
  FOR i IN 1..5 LOOP
    v_code := public.generate_share_code(6);
    BEGIN
      INSERT INTO public.vehicle_invites AS vi (vehicle_id, code, created_by, expires_at)
      VALUES (p_vehicle_id, v_code, auth.uid(), v_exp)
      ON CONFLICT ON CONSTRAINT vehicle_invites_pkey DO UPDATE
        SET code = EXCLUDED.code, created_by = EXCLUDED.created_by,
            created_at = NOW(), expires_at = EXCLUDED.expires_at;
      RETURN QUERY SELECT v_code, v_exp;
      RETURN;
    EXCEPTION WHEN unique_violation THEN
      -- otro vehículo tiene ese código: probar otro
    END;
  END LOOP;
  RAISE EXCEPTION 'No se ha podido generar el código. Inténtalo de nuevo.' USING ERRCODE = '22023';
END;
$$;

-- ─── 4. Unirse con un código ─────────────────────────────────
DROP FUNCTION IF EXISTS public.join_vehicle_by_code(TEXT, TEXT);
CREATE FUNCTION public.join_vehicle_by_code(p_code TEXT, p_role TEXT DEFAULT 'regular')
RETURNS TABLE (vehicle_id UUID, brand TEXT, model TEXT, already_member BOOLEAN, error TEXT)
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_uid   UUID := auth.uid();
  v_code  TEXT := upper(regexp_replace(coalesce(p_code, ''), '[\s-]', '', 'g'));
  v_inv   public.vehicle_invites;
  v_veh   public.vehicles;
  v_fails INT;
  v_had   BOOLEAN;
  v_found BOOLEAN;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión' USING ERRCODE = '42501';
  END IF;
  IF p_role IS NULL OR p_role NOT IN ('regular', 'company', 'mechanic') THEN
    RAISE EXCEPTION 'Rol no válido' USING ERRCODE = '22023';
  END IF;

  SELECT count(*) INTO v_fails FROM public.join_attempts
   WHERE user_id = v_uid AND NOT success AND created_at > NOW() - INTERVAL '1 hour';
  IF v_fails >= 10 THEN
    RAISE EXCEPTION 'Demasiados intentos fallidos. Prueba de nuevo dentro de una hora.' USING ERRCODE = '22023';
  END IF;

  IF v_code !~ '^[A-Z0-9]{6}$' THEN
    RAISE EXCEPTION 'El código tiene 6 letras y números' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_inv FROM public.vehicle_invites i WHERE i.code = v_code;
  v_found := FOUND;
  IF NOT v_found OR v_inv.expires_at <= NOW() THEN
    -- Aquí no se lanza error: el intento fallido se tiene que guardar
    -- (un error desharía el INSERT y el límite de intentos no contaría).
    INSERT INTO public.join_attempts (user_id, success) VALUES (v_uid, FALSE);
    RETURN QUERY SELECT NULL::UUID, NULL::TEXT, NULL::TEXT, FALSE,
      CASE WHEN v_found THEN 'Este código ha caducado. Pide uno nuevo al propietario.'
           ELSE 'Código no válido. Revisa que esté bien escrito.' END;
    RETURN;
  END IF;

  SELECT * INTO v_veh FROM public.vehicles v WHERE v.id = v_inv.vehicle_id;
  IF v_veh.owner_id = v_uid THEN
    RAISE EXCEPTION 'Este vehículo ya es tuyo' USING ERRCODE = '22023';
  END IF;

  v_had := EXISTS (SELECT 1 FROM public.shared_vehicles s WHERE s.vehicle_id = v_veh.id AND s.user_id = v_uid);
  IF NOT v_had AND (SELECT count(*) FROM public.shared_vehicles s WHERE s.vehicle_id = v_veh.id) >= 20 THEN
    RAISE EXCEPTION 'Este vehículo ya está compartido con el máximo de 20 personas' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.join_attempts (user_id, success) VALUES (v_uid, TRUE);
  INSERT INTO public.shared_vehicles AS s (vehicle_id, user_id, role)
  VALUES (v_veh.id, v_uid, p_role)
  -- Si ya tenía acceso, se queda con el rol que tenga (lo decide el propietario).
  ON CONFLICT ON CONSTRAINT shared_vehicles_vehicle_id_user_id_key DO NOTHING;

  RETURN QUERY SELECT v_veh.id, v_veh.brand, v_veh.model, v_had, NULL::TEXT;
END;
$$;

-- ─── 5. Personas con acceso (con su nombre) ──────────────────
-- SECURITY INVOKER: las políticas deciden. El propietario ve a todos;
-- quien tiene acceso compartido se ve a sí mismo y al propietario.
CREATE OR REPLACE FUNCTION public.vehicle_members(p_vehicle_id UUID)
RETURNS TABLE (user_id UUID, display_name TEXT, role TEXT, joined_at TIMESTAMPTZ, is_me BOOLEAN)
LANGUAGE sql STABLE SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
  SELECT m.* FROM (
    SELECT v.owner_id AS user_id, p.display_name, 'owner'::TEXT AS role, v.created_at AS joined_at,
           v.owner_id = auth.uid() AS is_me
      FROM public.vehicles v
      LEFT JOIN public.profiles p ON p.id = v.owner_id
     WHERE v.id = p_vehicle_id
    UNION ALL
    SELECT s.user_id, p.display_name, s.role, s.joined_at, s.user_id = auth.uid()
      FROM public.shared_vehicles s
      LEFT JOIN public.profiles p ON p.id = s.user_id
     WHERE s.vehicle_id = p_vehicle_id
  ) m
  ORDER BY m.role = 'owner' DESC, m.joined_at;
$$;

-- ─── 6. Cambiar el rol de alguien (solo el propietario) ──────
CREATE OR REPLACE FUNCTION public.set_member_role(p_vehicle_id UUID, p_user_id UUID, p_role TEXT)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.vehicles WHERE id = p_vehicle_id AND owner_id = auth.uid()) THEN
    RAISE EXCEPTION 'Solo el propietario puede cambiar los permisos' USING ERRCODE = '42501';
  END IF;
  IF p_role IS NULL OR p_role NOT IN ('regular', 'company', 'mechanic') THEN
    RAISE EXCEPTION 'Rol no válido' USING ERRCODE = '22023';
  END IF;
  UPDATE public.shared_vehicles SET role = p_role
   WHERE vehicle_id = p_vehicle_id AND user_id = p_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Esa persona ya no tiene acceso' USING ERRCODE = '22023';
  END IF;
END;
$$;

-- Quitar el acceso a alguien o dejar de ver un vehículo: DELETE sobre
-- shared_vehicles con la política de la 001 (propietario o uno mismo).

-- ─── 7. Permisos ─────────────────────────────────────────────
REVOKE EXECUTE ON FUNCTION public.get_share_invite(UUID)                 FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.regenerate_share_code(UUID, INT)       FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.join_vehicle_by_code(TEXT, TEXT)       FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.vehicle_members(UUID)                  FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.set_member_role(UUID, UUID, TEXT)      FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.generate_share_code(INT)               FROM anon, authenticated, public;
GRANT  EXECUTE ON FUNCTION public.get_share_invite(UUID)                 TO authenticated;
GRANT  EXECUTE ON FUNCTION public.regenerate_share_code(UUID, INT)       TO authenticated;
GRANT  EXECUTE ON FUNCTION public.join_vehicle_by_code(TEXT, TEXT)       TO authenticated;
GRANT  EXECUTE ON FUNCTION public.vehicle_members(UUID)                  TO authenticated;
GRANT  EXECUTE ON FUNCTION public.set_member_role(UUID, UUID, TEXT)      TO authenticated;
