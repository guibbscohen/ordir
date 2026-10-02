// rules-answer: answers a rules question from a game's official sources, citing source and page.
//
// POST { game, expansions: string[], question, followUp? } with a signed-in player's access token.
// With followUp, the player's last few questions on that game (from rules_questions, never from the
// client) come first as earlier turns, so "and with Smugglers?" makes sense.
// Returns { answer: [{ text, citations: [{ source, page, quote }] }], refused, questionsLeft }.
//
// The sources' text comes from the rules_pages table (loaded by the Rules corpus workflow), split
// into passages so citations point at a passage, which maps back to its page. Claude Opus 5.5 reads
// the base game's rulebook and FAQ plus the rulebooks of the expansions in play; the documents are
// cached, so after the first question each costs about a cent. Every question is logged in
// rules_questions, which also enforces a daily cap per player.

import Anthropic from "npm:@anthropic-ai/sdk";
import { createClient } from "npm:@supabase/supabase-js@2";

const MODEL = "claude-opus-5-5";
const DAILY_QUESTIONS = 30;
/** A follow-up sees this many earlier questions on the same game, from the last few hours. */
const FOLLOW_UP_TURNS = 3;
const FOLLOW_UP_HOURS = 6;

/** Which sources each game has, in the order Claude reads them. Keep in step with the turn script. */
const GAMES: Record<string, { title: string; sources: Record<string, string>; base: string[] }> = {
  duneWarForArrakis: {
    title: "Dune: War for Arrakis",
    base: ["rulebook", "faq"],
    sources: {
      rulebook: "Dune: War for Arrakis rulebook (work-in-progress edition)",
      faq: "Dune: War for Arrakis FAQ 3.0 (June 2024)",
      desertWar: "Desert War expansion rulebook",
      smugglers: "Smugglers expansion rulebook",
      spacingGuild: "The Spacing Guild expansion rulebook",
    },
  },
  starWarsRebellion: {
    title: "Star Wars: Rebellion",
    base: ["learnToPlay", "rulesReference", "faq"],
    sources: {
      learnToPlay: "Star Wars: Rebellion Learn to Play",
      rulesReference: "Star Wars: Rebellion Rules Reference",
      faq: "Star Wars: Rebellion FAQ and errata v2.1 (May 2019)",
      riseOfTheEmpire: "Rise of the Empire expansion rulesheet",
    },
  },
};

const SYSTEM = `You are Ordir's rules referee for board games. Answer the player's question using only the official documents provided: the game's rulebook, the publisher's FAQ, and the rulebooks of the expansions in play.

- Cite every rule you rely on.
- Where the FAQ differs from the rulebook, the FAQ is final: follow it and say that it changes the rulebook.
- Expansion rules apply only when that expansion's rulebook is provided.
- If the documents don't settle the question, say so plainly and say what they do cover. Never fill a gap from general knowledge of the game, other editions, or forums.

Format: one short sentence that answers the question, then up to five short bullet points with the details, each on its own line starting with "- ". No headings and no long paragraphs.`;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

type Passage = { text: string; page: number };

const supabase = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const anthropic = new Anthropic();

/** Pages split into passages of a few sentences, cached per instance. */
const passagesCache = new Map<string, Passage[]>();

function toPassages(page: number, text: string): Passage[] {
  const sentences = text.replace(/\s*\n\s*/g, " ").split(/(?<=[.!?])\s+(?=[A-Z0-9“"(•-])/);
  const passages: Passage[] = [];
  let current = "";
  for (const sentence of sentences) {
    current = current ? `${current} ${sentence}` : sentence;
    if (current.length >= 280) {
      passages.push({ text: current, page });
      current = "";
    }
  }
  if (current.trim()) passages.push({ text: current, page });
  return passages;
}

async function passagesFor(game: string, source: string): Promise<Passage[]> {
  const key = `${game}/${source}`;
  const cached = passagesCache.get(key);
  if (cached) return cached;
  const { data, error } = await supabase
    .from("rules_pages")
    .select("page, text")
    .eq("game", game)
    .eq("source", source)
    .order("page");
  if (error) throw error;
  const passages = (data ?? []).flatMap((row) => toPassages(row.page, row.text));
  if (passages.length) passagesCache.set(key, passages);
  return passages;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  // A signed-in player (not a guest or the bare anon key).
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data: auth } = await supabase.auth.getUser(token);
  const user = auth?.user;
  if (!user || user.is_anonymous) return json({ error: "Sign in to ask rules questions." }, 401);

  let body: { game?: string; expansions?: string[]; question?: string; followUp?: boolean };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Send JSON." }, 400);
  }
  const game = GAMES[body.game ?? ""];
  const question = (body.question ?? "").trim();
  if (!game) return json({ error: "Unknown game." }, 400);
  if (question.length < 3 || question.length > 500) return json({ error: "Ask in 3 to 500 characters." }, 400);
  const expansions = [...new Set(body.expansions ?? [])].filter((id) => id in game.sources && !game.base.includes(id));

  const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
  const { count } = await supabase
    .from("rules_questions")
    .select("id", { count: "exact", head: true })
    .eq("user_id", user.id)
    .gte("created_at", since);
  if ((count ?? 0) >= DAILY_QUESTIONS) {
    return json({ error: `That's ${DAILY_QUESTIONS} questions today. Try again tomorrow.` }, 429);
  }

  // Base sources first, then expansions in the game's order, so the cached prefix is stable.
  const sourceIds = Object.keys(game.sources).filter((id) => game.base.includes(id) || expansions.includes(id));
  const documents = await Promise.all(sourceIds.map(async (id) => ({ id, passages: await passagesFor(body.game!, id) })));
  if (documents.some((d) => d.passages.length === 0)) {
    return json({ error: "The rules aren't loaded yet. Try again later." }, 503);
  }

  const content: Anthropic.Beta.BetaContentBlockParam[] = documents.map((doc, index) => ({
    type: "document",
    title: game.sources[doc.id],
    context: `Official source for ${game.title}.`,
    source: { type: "content", content: doc.passages.map((p) => ({ type: "text", text: p.text })) },
    citations: { enabled: true },
    ...(index === documents.length - 1 ? { cache_control: { type: "ephemeral" } } : {}),
  }));

  // Earlier turns of this chat, oldest first, as plain text: the documents stay at the start of the
  // first user turn, so their cached prefix still matches.
  const turns: { question: string; answer: string }[] = [];
  if (body.followUp) {
    const { data: earlier } = await supabase
      .from("rules_questions")
      .select("question, answer")
      .eq("user_id", user.id)
      .eq("game", body.game)
      .not("answer", "is", null)
      .gte("created_at", new Date(Date.now() - FOLLOW_UP_HOURS * 60 * 60 * 1000).toISOString())
      .order("created_at", { ascending: false })
      .limit(FOLLOW_UP_TURNS);
    for (const row of (earlier ?? []).reverse()) {
      const answer = (row.answer as { text: string }[]).map((block) => block.text).join("").trim();
      if (answer) turns.push({ question: row.question, answer });
    }
  }
  const messages: Anthropic.Beta.BetaMessageParam[] = [];
  for (const [index, turn] of turns.entries()) {
    messages.push({ role: "user", content: index === 0 ? [...content, { type: "text", text: turn.question }] : turn.question });
    messages.push({ role: "assistant", content: turn.answer });
  }
  messages.push({ role: "user", content: turns.length ? question : [...content, { type: "text", text: question }] });

  let response: Anthropic.Beta.BetaMessage;
  try {
    response = await anthropic.beta.messages.create({
      model: MODEL,
      max_tokens: 16000,
      output_config: { effort: "medium" },
      system: SYSTEM,
      messages,
      // On a safety decline, the API retries on a suitable fallback model within the same call.
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
    });
  } catch (error) {
    if (error instanceof Anthropic.RateLimitError) return json({ error: "Busy right now. Try again in a minute." }, 503);
    if (error instanceof Anthropic.APIError) {
      console.error("Anthropic API error", error.status, error.message);
      return json({ error: "Couldn't get an answer. Try again." }, 502);
    }
    throw error;
  }

  const refused = response.stop_reason === "refusal";
  const answer = refused
    ? [{ text: "I can't answer that one.", citations: [] }]
    : response.content.flatMap((block) => {
        if (block.type !== "text") return [];
        const citations = (block.citations ?? []).flatMap((c) => {
          if (c.type !== "content_block_location") return [];
          const doc = documents[c.document_index];
          const passage = doc?.passages[c.start_block_index];
          return passage ? [{ source: doc.id, page: passage.page, quote: c.cited_text }] : [];
        });
        return [{ text: block.text, citations }];
      });

  await supabase.from("rules_questions").insert({
    user_id: user.id,
    game: body.game,
    expansions,
    question,
    answer,
    model: response.model,
    usage: response.usage,
  });

  return json({ answer, refused, questionsLeft: DAILY_QUESTIONS - (count ?? 0) - 1 });
});
