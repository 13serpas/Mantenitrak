// Supabase Edge Function: genera la ficha técnica orientativa con IA.
//
// La clave de Anthropic vive SOLO aquí (secreto del proyecto), nunca en la app.
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//   supabase functions deploy vehicle-specs
//
// Supabase exige el JWT del usuario por defecto (verify_jwt), así que solo
// usuarios con sesión pueden llamarla.

import { buildPrompt, extractJson, isEmptySpecs, parseQuery, sanitizeSpecs } from "./specs.ts";

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return json({ error: "Método no permitido" }, 405);

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return json({ error: "La IA no está configurada en el servidor" }, 503);

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Cuerpo no válido" }, 400);
  }
  const parsed = parseQuery(body);
  if ("error" in parsed) return json({ error: parsed.error }, 400);

  try {
    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: Deno.env.get("ANTHROPIC_MODEL") ?? "claude-haiku-5-5",
        max_tokens: 800,
        temperature: 0,
        messages: [{ role: "user", content: buildPrompt(parsed.query) }],
      }),
      signal: AbortSignal.timeout(25_000),
    });

    if (!res.ok) {
      console.error("Anthropic", res.status, await res.text());
      return json({ error: "El servicio de IA no está disponible ahora mismo" }, 502);
    }

    const data = await res.json();
    const text = (data.content ?? [])
      .filter((c: { type: string }) => c.type === "text")
      .map((c: { text: string }) => c.text)
      .join("");

    const specs = sanitizeSpecs(extractJson(text));
    if (isEmptySpecs(specs)) {
      return json({ error: "No hay datos fiables para este vehículo" }, 422);
    }
    return json({ specs });
  } catch (e) {
    console.error("vehicle-specs", e);
    return json({ error: "No se pudo generar la ficha" }, 502);
  }
});
