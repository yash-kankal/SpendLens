const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type Task = "categorize" | "insights" | "chat";

type AIRequest = {
  task: Task;
  title?: string;
  userMessage?: string;
  expensesJSON?: string;
  localSummary?: string;
  budgetTotal?: number;
  currentDay?: number;
  daysInMonth?: number;
};

const categories = [
  "food",
  "transport",
  "shopping",
  "entertainment",
  "health",
  "utilities",
  "rent",
  "savings",
  "other",
];

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const openAIKey = Deno.env.get("OPENAI_API_KEY");
    if (!openAIKey) {
      return json({ error: "OPENAI_API_KEY is not configured." }, 500);
    }

    const body = await req.json() as AIRequest;

    switch (body.task) {
      case "categorize":
        return json(await categorize(openAIKey, body.title ?? ""));
      case "insights":
        return json({ insight: await insights(openAIKey, body) });
      case "chat":
        return json({ content: await chat(openAIKey, body) });
      default:
        return json({ error: "Unsupported AI task." }, 400);
    }
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : "AI request failed." }, 500);
  }
});

async function categorize(openAIKey: string, title: string) {
  const content = await complete(openAIKey, {
    model: "gpt-4o-mini",
    max_tokens: 20,
    temperature: 0.1,
    messages: [
      {
        role: "system",
        content: `Return exactly one category from this list: ${categories.join(", ")}.`,
      },
      {
        role: "user",
        content: `Expense title: "${title}"`,
      },
    ],
  });

  const category = normalizeCategory(content);
  return {
    category: categories.includes(category) ? category : "other",
    source: "AI",
  };
}

async function insights(openAIKey: string, body: AIRequest) {
  const content = await complete(openAIKey, {
    model: "gpt-4o-mini",
    max_tokens: 800,
    temperature: 0.3,
    response_format: { type: "json_object" },
    messages: [
      {
        role: "system",
        content: [
          "You are SpendLens AI. Return only practical personal finance JSON with these keys:",
          "savedAmount, projectedSpend, lastMonthSavings, budgetTips, patterns, savingOpportunities, spendLessOn.",
          "All numeric values must be numbers, but the app will calculate final numbers locally.",
          "For numeric keys, echo the locally computed values from the summary when possible and never invent a default budget.",
          "All list values must be arrays of concise, specific, user-actionable strings.",
          "Avoid generic tips like 'spend less' unless tied to a category or dollar amount from the user's data.",
        ].join(" "),
      },
      {
        role: "user",
        content: [
          "Local computed summary:",
          body.localSummary ?? "No summary provided.",
          `Monthly budget: ${body.budgetTotal ?? 0}`,
          `Day ${body.currentDay ?? 1} of ${body.daysInMonth ?? 30}`,
          "Expenses:",
          body.expensesJSON ?? "[]",
        ].join("\n"),
      },
    ],
  });

  return JSON.parse(stripCodeFence(content));
}

async function chat(openAIKey: string, body: AIRequest) {
  return await complete(openAIKey, {
    model: "gpt-4o-mini",
    max_tokens: 350,
    temperature: 0.3,
    messages: [
      {
        role: "system",
        content: [
          "You are SpendLens AI, a concise personal finance assistant.",
          "Use the user's expense data below when answering.",
          "Mention dollar amounts when useful.",
          "Expenses:",
          body.expensesJSON ?? "[]",
        ].join("\n"),
      },
      {
        role: "user",
        content: body.userMessage ?? "",
      },
    ],
  });
}

async function complete(openAIKey: string, payload: Record<string, unknown>) {
  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${openAIKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`OpenAI request failed: ${text}`);
  }

  const jsonBody = await response.json();
  const content = jsonBody?.choices?.[0]?.message?.content;
  if (typeof content !== "string") {
    throw new Error("OpenAI returned an unexpected response.");
  }
  return content;
}

function normalizeCategory(value: string) {
  return value.trim().toLowerCase().replaceAll('"', "").replaceAll("'", "").replaceAll(".", "");
}

function stripCodeFence(value: string) {
  return value
    .trim()
    .replace(/^```json\s*/i, "")
    .replace(/^```\s*/i, "")
    .replace(/\s*```$/i, "");
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
