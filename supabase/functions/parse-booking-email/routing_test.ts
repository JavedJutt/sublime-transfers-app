// Tests for the parser's routing rule — the pure decision layer that keeps a
// mis-parsed booking out of the calendar. No network; run with `deno test`.
import { assertEquals } from "jsr:@std/assert@1";
import {
  type BookingExtraction,
  dateIsSwappable,
  essentialsMissing,
  extractionToPayload,
  routeExtraction,
} from "./schema.ts";

function booking(overrides: Partial<BookingExtraction> = {}): BookingExtraction {
  return {
    customer_name: "Ava Turner",
    customer_phone: "+44 7700 900123",
    pickup_address: "Heathrow Terminal 5",
    dropoff_address: "The Savoy, London",
    pickup_datetime_iso: "2026-08-01T14:30:00+01:00",
    pickup_datetime_verbatim: "1 August 2026, 14:30",
    passengers: 2,
    luggage: 3,
    flight_number: "BA123",
    vehicle_type: "executive",
    fare_amount: 120,
    fare_currency: "GBP",
    notes: null,
    confidence: 0.95,
    uncertain_fields: [],
    ...overrides,
  };
}

Deno.test("a clean, confident booking auto-creates", () => {
  const r = routeExtraction(booking());
  assertEquals(r.autoCreate, true);
  assertEquals(r.payload.pickup_at, "2026-08-01T14:30:00+01:00");
  assertEquals(r.payload.vehicle_type, "executive");
});

Deno.test("low confidence forces review", () => {
  const r = routeExtraction(booking({ confidence: 0.6 }));
  assertEquals(r.autoCreate, false);
});

Deno.test("any uncertain field forces review even at high confidence", () => {
  const r = routeExtraction(
    booking({ confidence: 0.99, uncertain_fields: ["dropoff_address"] }),
  );
  assertEquals(r.autoCreate, false);
});

Deno.test("a missing essential forces review", () => {
  const r = routeExtraction(booking({ pickup_address: "" }));
  assertEquals(r.autoCreate, false);
});

Deno.test("an unparseable pickup time forces review", () => {
  const r = routeExtraction(booking({ pickup_datetime_iso: "sometime tuesday" }));
  assertEquals(r.autoCreate, false);
});

Deno.test("an ambiguous numeric date (03/04) forces review", () => {
  const r = routeExtraction(
    booking({ pickup_datetime_verbatim: "03/04/2026 14:30" }),
  );
  assertEquals(r.autoCreate, false);
});

Deno.test("an unambiguous numeric date (25/12) auto-creates", () => {
  const r = routeExtraction(
    booking({ pickup_datetime_verbatim: "25/12/2026 14:30" }),
  );
  assertEquals(r.autoCreate, true);
});

Deno.test("dateIsSwappable detects reversible all-numeric dates only", () => {
  assertEquals(dateIsSwappable("03/04/2026"), true);
  assertEquals(dateIsSwappable("3-4-26"), true);
  assertEquals(dateIsSwappable("25/12/2026"), false); // day > 12
  assertEquals(dateIsSwappable("1 August 2026"), false); // month named
  assertEquals(dateIsSwappable("07/07/2026"), false); // same value, not reversible
  assertEquals(dateIsSwappable(null), false);
});

Deno.test("extractionToPayload drops an unknown vehicle type to null", () => {
  const p = extractionToPayload(booking({ vehicle_type: "spaceship" }));
  assertEquals(p.vehicle_type, null);
});

Deno.test("essentialsMissing lists each absent core field", () => {
  const p = extractionToPayload(
    booking({ customer_name: "", pickup_address: "" }),
  );
  const missing = essentialsMissing(p);
  assertEquals(missing.includes("customer name"), true);
  assertEquals(missing.includes("pickup"), true);
});
