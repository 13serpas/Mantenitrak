// Lógica pura de la función vehicle-specs (sin dependencias de Deno),
// separada para poder probarla con Node.

export interface VehicleQuery {
  type: string;
  brand: string;
  model: string;
  year: number;
  engine?: string | null;
  fuel_type?: string | null;
}

export interface VehicleSpecs {
  oil_type: string | null;
  oil_liters: number | null;
  oil_brands: string[] | null;
  oil_filter_ref: string | null;
  air_filter_ref: string | null;
  cabin_filter_ref: string | null;
  fuel_filter_ref: string | null;
  spark_plug_ref: string | null;
  tire_size_front: string | null;
  tire_size_rear: string | null;
  battery_spec: string | null;
  notes: string | null;
}

const TYPES = new Set([
  "coche", "moto", "camion", "autobus", "furgoneta",
  "todoterreno", "caravana", "barco", "quad", "otro",
]);

/** Valida la petición del cliente. Devuelve el error o la consulta limpia. */
export function parseQuery(body: unknown): { error: string } | { query: VehicleQuery } {
  if (typeof body !== "object" || body === null) return { error: "Cuerpo no válido" };
  const b = body as Record<string, unknown>;
  const text = (v: unknown, max: number) =>
    typeof v === "string" && v.trim().length > 0 && v.trim().length <= max ? v.trim() : null;

  const type = text(b.type, 20);
  const brand = text(b.brand, 60);
  const model = text(b.model, 60);
  const year = typeof b.year === "number" ? b.year : Number(b.year);
  const thisYear = new Date().getFullYear();

  if (!type || !TYPES.has(type)) return { error: "Tipo de vehículo no válido" };
  if (!brand || !model) return { error: "Marca y modelo son obligatorios" };
  if (!Number.isInteger(year) || year < 1900 || year > thisYear + 1) return { error: "Año no válido" };

  return {
    query: {
      type, brand, model, year,
      engine: text(b.engine, 60),
      fuel_type: text(b.fuel_type, 20),
    },
  };
}

export function buildPrompt(q: VehicleQuery): string {
  const desc = [q.brand, q.model, q.engine, String(q.year)].filter(Boolean).join(" ");
  return [
    `Eres un mecánico experto del mercado español. Vehículo: ${desc}.`,
    `Tipo: ${q.type}.${q.fuel_type ? ` Combustible: ${q.fuel_type}.` : ""}`,
    "Devuelve SOLO un objeto JSON, sin texto adicional, con estas claves:",
    "oil_type (viscosidad y norma, p. ej. \"5W-30 VW 504.00\"), oil_liters (número, con filtro),",
    "oil_brands (array de hasta 3 marcas), oil_filter_ref, air_filter_ref, cabin_filter_ref,",
    "fuel_filter_ref, spark_plug_ref, tire_size_front, tire_size_rear, battery_spec, notes.",
    "Usa null en lo que no aplique a este vehículo (p. ej. bujías en un diésel o eléctrico).",
    "Si no estás seguro de una referencia concreta de recambio, devuelve null en lugar de inventarla.",
  ].join("\n");
}

/** Extrae el primer objeto JSON del texto del modelo (tolera ```json …```). */
export function extractJson(text: string): unknown {
  const start = text.indexOf("{");
  const end = text.lastIndexOf("}");
  if (start < 0 || end <= start) throw new Error("La respuesta no contiene JSON");
  return JSON.parse(text.slice(start, end + 1));
}

const STRING_FIELDS = [
  "oil_type", "oil_filter_ref", "air_filter_ref", "cabin_filter_ref",
  "fuel_filter_ref", "spark_plug_ref", "tire_size_front", "tire_size_rear", "battery_spec",
] as const;

/** camelCase → snake_case, por si el modelo responde con otro estilo. */
function snake(key: string): string {
  return key.replace(/[A-Z]/g, (c) => `_${c.toLowerCase()}`);
}

/**
 * Convierte lo que devuelva la IA en una ficha segura: solo columnas
 * conocidas, tipos correctos y longitudes acotadas. Todo lo demás se descarta.
 */
export function sanitizeSpecs(raw: unknown): VehicleSpecs {
  const src: Record<string, unknown> = {};
  if (typeof raw === "object" && raw !== null) {
    for (const [k, v] of Object.entries(raw as Record<string, unknown>)) src[snake(k)] = v;
  }

  const str = (v: unknown, max = 80): string | null => {
    if (typeof v !== "string") return null;
    const t = v.trim();
    if (!t || t.length > max || /^(null|n\/a|desconocido|-)$/i.test(t)) return null;
    return t;
  };

  const liters = typeof src.oil_liters === "number"
    ? src.oil_liters
    : typeof src.oil_liters === "string"
      ? Number(src.oil_liters.replace(",", "."))
      : NaN;

  const brands = Array.isArray(src.oil_brands)
    ? src.oil_brands.map((b) => str(b, 30)).filter((b): b is string => b !== null).slice(0, 5)
    : [];

  const out = {
    oil_liters: Number.isFinite(liters) && liters > 0 && liters <= 60
      ? Math.round(liters * 100) / 100
      : null,
    oil_brands: brands.length ? brands : null,
    notes: str(src.notes, 300),
  } as VehicleSpecs;
  for (const f of STRING_FIELDS) out[f] = str(src[f]);
  return out;
}

/** true si la IA no ha devuelto nada aprovechable. */
export function isEmptySpecs(s: VehicleSpecs): boolean {
  return Object.values(s).every((v) => v === null);
}
