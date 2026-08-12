// ===========================================================================
// The parser's contract with the model, and the routing rule around it.
// ===========================================================================
// We give OpenAI exactly two functions and force it to call one of them
// (tool_choice: "required"). That is what implements the spec's hard rule —
// "a booking is never silently dropped or auto-filled with guesses": the model
// cannot answer in prose. It must either return a structured booking or
// explicitly classify why this email isn't one.
//
// The routing logic below (pure, unit-tested) decides whether an extraction is
// trustworthy enough to become a ride automatically, or whether it goes to the
// human review queue. It never *invents* trust — low confidence, any field the
// model flagged as uncertain, a missing essential, or an ambiguous date all
// force review.

export const VEHICLE_TYPES = [
  "sedan",
  "estate",
  "mpv",
  "executive",
  "minibus",
] as const;

export const REVIEW_REASONS = [
  "not_a_booking",
  "amendment",
  "cancellation",
  "missing_required_fields",
  "ambiguous",
  "unreadable",
] as const;

export type ReviewReason = (typeof REVIEW_REASONS)[number];

export interface BookingExtraction {
  customer_name: string;
  customer_phone: string | null;
  pickup_address: string;
  dropoff_address: string;
  pickup_datetime_iso: string;
  pickup_datetime_verbatim: string;
  passengers: number;
  luggage: number;
  flight_number: string | null;
  vehicle_type: string | null;
  fare_amount: number | null;
  fare_currency: string | null;
  notes: string | null;
  confidence: number;
  uncertain_fields: string[];
}

export interface ReviewFlag {
  reason: ReviewReason;
  summary: string;
  partial: {
    customer_name: string | null;
    pickup_address: string | null;
    dropoff_address: string | null;
    pickup_datetime_verbatim: string | null;
  };
}

// The confidence floor for an unattended auto-create. Everything below, or with
// any other risk signal, goes to a human. Tune against real mail after launch.
export const AUTO_CREATE_CONFIDENCE = 0.85;

export const SYSTEM_PROMPT =
  `You extract chauffeur/transfer ride bookings from emails for a UK operator ` +
  `(Sublime Transfers). All times are Europe/London local time.\n\n` +
  `Rules:\n` +
  `- If the email is a genuine new booking request, call extract_booking.\n` +
  `- If it is NOT a new booking — marketing, an amendment to an existing ` +
  `booking, a cancellation, a reply/confirmation, or unreadable — call ` +
  `flag_for_review with the right reason. Never invent a booking.\n` +
  `- Dates: UK format is day-first (DD/MM). Convert the pickup date and time ` +
  `to an ISO 8601 string WITH the Europe/London offset in pickup_datetime_iso, ` +
  `and ALSO copy the exact original date/time text into ` +
  `pickup_datetime_verbatim. If the date is genuinely ambiguous or missing, ` +
  `lower your confidence and add "pickup_datetime" to uncertain_fields.\n` +
  `- Only fill a field you are confident about. List any field you are unsure ` +
  `of in uncertain_fields (use the field name). Do not guess an address, a ` +
  `time, or a passenger count.\n` +
  `- passengers defaults to 1 and luggage to 0 if not stated.\n` +
  `- vehicle_type must be one of: ${VEHICLE_TYPES.join(", ")} — or null.\n` +
  `- confidence is your overall 0..1 certainty this is a correct, complete ` +
  `booking.`;

// The two tools, in the exact strict-schema shape OpenAI requires: every
// property listed in `required`, optionals typed as ["type","null"], and
// additionalProperties:false, so a schema-valid object is guaranteed.
export const TOOLS = [
  {
    type: "function",
    function: {
      name: "extract_booking",
      description: "Record a genuine new ride booking found in the email.",
      strict: true,
      parameters: {
        type: "object",
        additionalProperties: false,
        properties: {
          customer_name: { type: "string" },
          customer_phone: { type: ["string", "null"] },
          pickup_address: { type: "string" },
          dropoff_address: { type: "string" },
          pickup_datetime_iso: {
            type: "string",
            description: "ISO 8601 with Europe/London offset",
          },
          pickup_datetime_verbatim: {
            type: "string",
            description: "The exact date/time text from the email",
          },
          passengers: { type: "integer" },
          luggage: { type: "integer" },
          flight_number: { type: ["string", "null"] },
          vehicle_type: {
            type: ["string", "null"],
            enum: [...VEHICLE_TYPES, null],
          },
          fare_amount: { type: ["number", "null"] },
          fare_currency: { type: ["string", "null"] },
          notes: { type: ["string", "null"] },
          confidence: { type: "number" },
          uncertain_fields: { type: "array", items: { type: "string" } },
        },
        required: [
          "customer_name",
          "customer_phone",
          "pickup_address",
          "dropoff_address",
          "pickup_datetime_iso",
          "pickup_datetime_verbatim",
          "passengers",
          "luggage",
          "flight_number",
          "vehicle_type",
          "fare_amount",
          "fare_currency",
          "notes",
          "confidence",
          "uncertain_fields",
        ],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "flag_for_review",
      description:
        "Classify an email that is not a clean new booking, for a human.",
      strict: true,
      parameters: {
        type: "object",
        additionalProperties: false,
        properties: {
          reason: { type: "string", enum: [...REVIEW_REASONS] },
          summary: {
            type: "string",
            description: "One line telling the reviewer what this is",
          },
          partial: {
            type: "object",
            additionalProperties: false,
            properties: {
              customer_name: { type: ["string", "null"] },
              pickup_address: { type: ["string", "null"] },
              dropoff_address: { type: ["string", "null"] },
              pickup_datetime_verbatim: { type: ["string", "null"] },
            },
            required: [
              "customer_name",
              "pickup_address",
              "dropoff_address",
              "pickup_datetime_verbatim",
            ],
          },
        },
        required: ["reason", "summary", "partial"],
      },
    },
  },
];

// The ride-shaped payload our DB RPCs consume (snake_case, pickup_at as ISO).
export interface RidePayload {
  pickup_at: string;
  customer_name: string;
  customer_phone: string | null;
  pickup_address: string;
  dropoff_address: string;
  passengers: number;
  luggage: number;
  fare_amount: number | null;
  fare_currency: string | null;
  vehicle_type: string | null;
  flight_number: string | null;
  notes: string | null;
}

export interface RoutingResult {
  autoCreate: boolean;
  payload: RidePayload;
  confidence: number;
  /** When not auto-creating, the reason the queue shows the reviewer. */
  reviewReason?: string;
}

export function extractionToPayload(b: BookingExtraction): RidePayload {
  return {
    pickup_at: b.pickup_datetime_iso,
    customer_name: b.customer_name?.trim() ?? "",
    customer_phone: emptyToNull(b.customer_phone),
    pickup_address: b.pickup_address?.trim() ?? "",
    dropoff_address: b.dropoff_address?.trim() ?? "",
    passengers: Number.isFinite(b.passengers) ? b.passengers : 1,
    luggage: Number.isFinite(b.luggage) ? b.luggage : 0,
    fare_amount: b.fare_amount ?? null,
    fare_currency: emptyToNull(b.fare_currency),
    vehicle_type: VEHICLE_TYPES.includes(b.vehicle_type as never)
      ? b.vehicle_type
      : null,
    flight_number: emptyToNull(b.flight_number),
    notes: emptyToNull(b.notes),
  };
}

// The routing decision. Pure — no I/O — so it is exhaustively unit-tested.
export function routeExtraction(b: BookingExtraction): RoutingResult {
  const payload = extractionToPayload(b);
  const confidence = clamp01(b.confidence);
  const reasons: string[] = [];

  const missing = essentialsMissing(payload);
  if (missing.length > 0) {
    reasons.push(`missing ${missing.join(", ")}`);
  }
  if (!isValidIsoDate(b.pickup_datetime_iso)) {
    reasons.push("unparseable pickup time");
  }
  if ((b.uncertain_fields?.length ?? 0) > 0) {
    reasons.push(`model unsure of ${b.uncertain_fields.join(", ")}`);
  }
  if (confidence < AUTO_CREATE_CONFIDENCE) {
    reasons.push(`confidence ${confidence.toFixed(2)}`);
  }
  // DD/MM vs MM/DD is the biggest silent-corruption risk. If the verbatim text
  // holds an all-numeric date whose day and month could swap (both 1..12) and
  // the model didn't already flag it, force review rather than gamble.
  if (
    dateIsSwappable(b.pickup_datetime_verbatim) &&
    !b.uncertain_fields?.includes("pickup_datetime")
  ) {
    reasons.push("ambiguous numeric date (DD/MM vs MM/DD)");
  }

  return {
    autoCreate: reasons.length === 0,
    payload,
    confidence,
    reviewReason: reasons.length === 0 ? undefined : reasons.join("; "),
  };
}

export function essentialsMissing(p: RidePayload): string[] {
  const missing: string[] = [];
  if (!p.customer_name) missing.push("customer name");
  if (!p.pickup_address || p.pickup_address === "Not provided") {
    missing.push("pickup");
  }
  if (!p.dropoff_address || p.dropoff_address === "Not provided") {
    missing.push("drop-off");
  }
  if (!isValidIsoDate(p.pickup_at)) missing.push("pickup time");
  return missing;
}

export function isValidIsoDate(s: string | null | undefined): boolean {
  if (!s) return false;
  const t = Date.parse(s);
  return !Number.isNaN(t);
}

// True when the verbatim date is an all-numeric d/m(/y) with both components in
// 1..12, i.e. genuinely reversible. A date with a month name, or a day > 12, is
// unambiguous and returns false.
export function dateIsSwappable(verbatim: string | null | undefined): boolean {
  if (!verbatim) return false;
  const m = verbatim.match(/\b(\d{1,2})\s*[\/\-.]\s*(\d{1,2})(?:\s*[\/\-.]\s*\d{2,4})?\b/);
  if (!m) return false;
  const a = Number(m[1]);
  const b = Number(m[2]);
  return a >= 1 && a <= 12 && b >= 1 && b <= 12 && a !== b;
}

function emptyToNull(s: string | null | undefined): string | null {
  const t = s?.trim();
  return t ? t : null;
}

function clamp01(n: number): number {
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(1, n));
}
