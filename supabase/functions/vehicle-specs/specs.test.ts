// Pruebas de la lógica pura. Ejecutar con:
//   deno test supabase/functions/vehicle-specs/   (o)
//   node --experimental-strip-types supabase/functions/vehicle-specs/specs.test.ts
import assert from "node:assert/strict";
import { buildPrompt, extractJson, isEmptySpecs, parseQuery, sanitizeSpecs } from "./specs.ts";

const tests: [string, () => void][] = [
  ["parseQuery acepta una petición válida", () => {
    const r = parseQuery({ type: "coche", brand: " Seat ", model: "Ibiza", year: "2019" });
    assert.ok("query" in r);
    if ("query" in r) {
      assert.equal(r.query.brand, "Seat");
      assert.equal(r.query.year, 2019);
      assert.equal(r.query.engine, null);
    }
  }],
  ["parseQuery rechaza tipo, año y textos enormes", () => {
    assert.ok("error" in parseQuery({ type: "nave", brand: "a", model: "b", year: 2020 }));
    assert.ok("error" in parseQuery({ type: "coche", brand: "a", model: "b", year: 1800 }));
    assert.ok("error" in parseQuery({ type: "coche", brand: "x".repeat(200), model: "b", year: 2020 }));
    assert.ok("error" in parseQuery(null));
  }],
  ["buildPrompt incluye el vehículo y pide null en vez de inventar", () => {
    const p = buildPrompt({ type: "coche", brand: "Seat", model: "Ibiza", year: 2019, engine: "1.0 TSI" });
    assert.match(p, /Seat Ibiza 1\.0 TSI 2019/);
    assert.match(p, /en lugar de inventarla/);
  }],
  ["extractJson tolera ```json y texto alrededor", () => {
    const v = extractJson('Aquí tienes:\n```json\n{"oil_type":"5W-30"}\n```') as Record<string, string>;
    assert.equal(v.oil_type, "5W-30");
    assert.throws(() => extractJson("sin json"));
  }],
  ["sanitizeSpecs: camelCase, tipos, límites y campos extra", () => {
    const s = sanitizeSpecs({
      oilType: " 5W-30 VW 504.00 ",
      oilLiters: "4,3",
      oilBrands: ["Castrol", 3, "", "Repsol", "a", "b", "c"],
      sparkPlugRef: "null",
      tireSizeFront: "205/55 R16",
      vehicle_id: "hack",
      owner_id: "hack",
      notes: "x".repeat(500),
    }) as unknown as Record<string, unknown>;
    assert.equal(s.oil_type, "5W-30 VW 504.00");
    assert.equal(s.oil_liters, 4.3);
    assert.deepEqual(s.oil_brands, ["Castrol", "Repsol", "a", "b", "c"]);
    assert.equal(s.spark_plug_ref, null);
    assert.equal(s.tire_size_front, "205/55 R16");
    assert.equal(s.notes, null);
    assert.equal("vehicle_id" in s, false);
    assert.equal("owner_id" in s, false);
  }],
  ["sanitizeSpecs: litros absurdos → null; vacío detectado", () => {
    assert.equal(sanitizeSpecs({ oil_liters: 400 }).oil_liters, null);
    assert.equal(sanitizeSpecs({ oil_liters: -1 }).oil_liters, null);
    assert.ok(isEmptySpecs(sanitizeSpecs({ foo: "bar" })));
    assert.ok(!isEmptySpecs(sanitizeSpecs({ battery_spec: "70Ah 640A" })));
  }],
];

let failed = 0;
for (const [name, fn] of tests) {
  try {
    fn();
    console.log(`✓ ${name}`);
  } catch (e) {
    failed++;
    console.error(`✗ ${name}\n  ${(e as Error).message}`);
  }
}
if (failed) {
  console.error(`${failed} prueba(s) fallida(s)`);
  if (typeof process !== "undefined") process.exit(1);
}
