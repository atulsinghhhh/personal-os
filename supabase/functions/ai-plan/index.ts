// AI planning assistant. The Flutter client builds a compact context from
// its LOCAL data (tasks, goals, time available, recorded money facts) and
// sends it here; this function calls Groq and returns a structured
// proposal. The user always approves before anything is applied.
//
// Rules enforced by the prompt:
// - never fabricate numbers: only reference figures present in the context
// - proposals are suggestions, not advice; financial output is limited to
//   explaining the user's own recorded data
//
// Secrets: GROQ_API_KEY (supabase secrets set / functions/.env locally).
// JWT verification is on (default), so only signed-in users can call this.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
const MODEL = Deno.env.get("GROQ_MODEL") ?? "openai/gpt-oss-120b";

interface PlanRequest {
  mode: "daily" | "weekly" | "financial";
  context: Record<string, unknown>;
}

const SYSTEM_PROMPTS: Record<PlanRequest["mode"], string> = {
  daily: `You are a planning assistant inside a personal-OS app.
Given the user's open tasks (with ids, estimates, priorities, due dates),
their goals, and their available time, propose a realistic plan for today.
Rules: never invent tasks or numbers not present in the input; if planned
work exceeds available time, say so and propose what to defer; keep it
achievable. Respond ONLY with JSON:
{"summary": "<one sentence>",
 "top_three": ["<task id>", ...up to 3],
 "schedule": [{"task_id": "<id>", "slot": "<e.g. 09:00-10:30>", "reason": "<short>"}],
 "deferred": [{"task_id": "<id>", "reason": "<short>"}],
 "warnings": ["<string>", ...]}`,
  weekly: `You are a planning assistant inside a personal-OS app.
Given the user's goals, unfinished tasks from last week, and this week's
tasks, propose 1-3 weekly outcomes and which tasks serve them.
Rules: never invent tasks or numbers; outcomes must trace to the provided
goals. Respond ONLY with JSON:
{"summary": "<one sentence>",
 "outcomes": [{"title": "<outcome>", "goal_id": "<id or null>", "task_ids": ["<id>", ...]}],
 "carry_over": [{"task_id": "<id>", "reason": "<short>"}],
 "warnings": ["<string>", ...]}`,
  financial: `You explain a user's own recorded financial data inside a
personal-OS app. You are NOT a financial adviser; never recommend buying,
selling, investing, borrowing, or specific products. Only restate and
explain the numbers provided, arithmetic on them, and neutral observations
(e.g. category X grew vs last month). Every number you mention must appear
in, or be direct arithmetic on, the input. Respond ONLY with JSON:
{"insights": [{"title": "<short>", "detail": "<1-2 sentences>", "figures": ["<the input numbers used>"]}]}`,
};

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return json({ error: "POST only" }, 405);
  }

  const apiKey = Deno.env.get("GROQ_API_KEY");
  if (!apiKey) {
    return json(
      { error: "not_configured", message: "GROQ_API_KEY is not set." },
      503,
    );
  }

  let body: PlanRequest;
  try {
    body = (await req.json()) as PlanRequest;
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  if (!body?.mode || !(body.mode in SYSTEM_PROMPTS) || !body.context) {
    return json({ error: "invalid_request" }, 400);
  }

  const response = await fetch(GROQ_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: MODEL,
      temperature: 0.3,
      max_tokens: 1500,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: SYSTEM_PROMPTS[body.mode] },
        { role: "user", content: JSON.stringify(body.context) },
      ],
    }),
  });

  if (!response.ok) {
    const detail = await response.text();
    console.error("groq_error", response.status, detail.slice(0, 500));
    return json({ error: "upstream_error", status: response.status }, 502);
  }

  const completion = await response.json();
  const content: string | undefined =
    completion?.choices?.[0]?.message?.content;
  if (!content) {
    return json({ error: "empty_completion" }, 502);
  }

  try {
    return json({ proposal: JSON.parse(content), model: MODEL });
  } catch {
    return json({ error: "unparseable_completion", raw: content }, 502);
  }
});

function json(payload: unknown, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
