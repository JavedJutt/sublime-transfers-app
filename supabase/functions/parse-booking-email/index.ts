// ===========================================================================
// parse-booking-email
// ===========================================================================
// Takes an inbound email id, asks OpenAI (gpt-4o) to classify and extract it,
// then either auto-creates a ride (high confidence, no risk signals) or parks
// it in the review queue with a reason. Called two ways:
//   * fire-and-forget by the Gmail webhook, authed with the service-role key.
//   * on demand by an admin ("re-parse") from the review screen, authed with
//     their JWT.
// It never throws a booking away: if OpenAI isn't configured, or the call
// fails, the email lands in review with an honest parse_error instead.

import { createClient } from "npm:@supabase/supabase-js@2";
import {
  type BookingExtraction,
  type ReviewFlag,
  routeExtraction,
  SYSTEM_PROMPT,
  TOOLS,
} from "./schema.ts";

const MODEL = "gpt-4o";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const preflight = () => new Response("ok", { headers: corsHeaders });

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return preflight();
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;

  // ---- authorize: internal service call, or an admin's JWT --------------
  const authHeader = req.headers.get("Authorization") ?? "";
  const token = authHeader.replace("Bearer ", "").trim();
  const isInternal = token.length > 0 && token === serviceKey;

  if (!isInternal) {
    const asUser = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData } = await asUser.auth.getUser();
    if (!userData?.user) return json({ error: "unauthorized" }, 401);
    const { data: profile } = await asUser
      .from("profiles")
      .select("role")
      .eq("id", userData.user.id)
      .single();
    if (profile?.role !== "admin") return json({ error: "forbidden" }, 403);
  }

  let emailId: string | undefined;
  try {
    emailId = (await req.json())?.email_id;
  } catch {
    return json({ error: "invalid_body" }, 400);
  }
  if (!emailId) return json({ error: "email_id required" }, 400);

  // Service-role client does all the reads/writes — the email tables carry no
  // client grants.
  const db = createClient(supabaseUrl, serviceKey);

  const { data: email, error: loadErr } = await db
    .from("inbound_emails")
    .select("id, subject, body_text, from_address, admin_id")
    .eq("id", emailId)
    .single();
  if (loadErr || !email) return json({ error: "email_not_found" }, 404);

  const openaiKey = Deno.env.get("OPENAI_API_KEY");
  if (!openaiKey) {
    // Degrade honestly — the booking is preserved for a human, not lost.
    await db
      .from("inbound_emails")
      .update({
        parse_status: "needs_review",
        parse_error: "parser_unconfigured",
        model_id: MODEL,
      })
      .eq("id", emailId);
    return json({ status: "needs_review", reason: "parser_unconfigured" });
  }

  // ---- the OpenAI call ---------------------------------------------------
  let toolName: string;
  let args: Record<string, unknown>;
  try {
    const emailText =
      `From: ${email.from_address ?? "unknown"}\n` +
      `Subject: ${email.subject ?? "(no subject)"}\n\n` +
      `${email.body_text ?? ""}`;

    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${openaiKey}`,
      },
      body: JSON.stringify({
        model: MODEL,
        temperature: 0,
        tools: TOOLS,
        tool_choice: "required",
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: emailText },
        ],
      }),
    });

    if (!res.ok) {
      const detail = await res.text();
      throw new Error(`openai ${res.status}: ${detail.slice(0, 300)}`);
    }

    const body = await res.json();
    const call = body.choices?.[0]?.message?.tool_calls?.[0];
    if (!call?.function?.name) throw new Error("no tool call in response");
    toolName = call.function.name;
    args = JSON.parse(call.function.arguments ?? "{}");
  } catch (e) {
    // A transient model/network failure must not drop the booking.
    await db
      .from("inbound_emails")
      .update({
        parse_status: "needs_review",
        parse_error: `parse_failed: ${String((e as Error).message).slice(0, 400)}`,
        model_id: MODEL,
      })
      .eq("id", emailId);
    return json({ status: "needs_review", reason: "parse_failed" }, 200);
  }

  // ---- classify: booking vs. review flag --------------------------------
  if (toolName === "flag_for_review") {
    const flag = args as unknown as ReviewFlag;
    await db
      .from("inbound_emails")
      .update({
        parse_status: "needs_review",
        parse_error: flag.reason,
        parsed_payload: flag as unknown as Record<string, unknown>,
        confidence: 0,
        model_id: MODEL,
      })
      .eq("id", emailId);
    return json({ status: "needs_review", reason: flag.reason });
  }

  const extraction = args as unknown as BookingExtraction;
  const routed = routeExtraction(extraction);

  if (routed.autoCreate) {
    const { data: ride, error: rpcErr } = await db.rpc("create_ride_from_email", {
      p_email_id: emailId,
      p_payload: routed.payload,
    });
    if (rpcErr) {
      // The insert bounced (e.g. a bad field the model produced). Keep it for
      // review with the DB's complaint rather than losing it.
      await db
        .from("inbound_emails")
        .update({
          parse_status: "needs_review",
          parse_error: `import_failed: ${rpcErr.message}`.slice(0, 400),
          parsed_payload: routed.payload as unknown as Record<string, unknown>,
          confidence: routed.confidence,
          model_id: MODEL,
        })
        .eq("id", emailId);
      return json({ status: "needs_review", reason: "import_failed" });
    }
    // create_ride_from_email already set parse_status='imported' and linked the
    // ride; record the confidence/payload/model for the audit trail.
    await db
      .from("inbound_emails")
      .update({
        parsed_payload: routed.payload as unknown as Record<string, unknown>,
        confidence: routed.confidence,
        model_id: MODEL,
        parse_status: "parsed",
      })
      .eq("id", emailId);
    return json({ status: "parsed", ride_id: (ride as { id: string })?.id });
  }

  // Confident enough to extract, not enough to auto-create → review with the
  // model's best-effort payload pre-filled so the human just corrects.
  await db
    .from("inbound_emails")
    .update({
      parse_status: "needs_review",
      parse_error: routed.reviewReason ?? "low_confidence",
      parsed_payload: routed.payload as unknown as Record<string, unknown>,
      confidence: routed.confidence,
      model_id: MODEL,
    })
    .eq("id", emailId);
  return json({ status: "needs_review", reason: routed.reviewReason });
});
