# My first days using AI for coding

*A practical guide for developers—especially Elixir and Phoenix LiveView—who are learning to work with LLMs in real projects.*

---

## Table of contents

1. [Why this article](#why-this-article)
2. [Glossary](#glossary)
3. [How LLMs actually work](#how-llms-actually-work)
4. [Context engineering](#context-engineering)
5. [Choosing a workflow: YOLO, MVP, and mission-critical](#choosing-a-workflow-yolo-mvp-and-mission-critical)
6. [Plan mode vs Auto mode](#plan-mode-vs-auto-mode)
7. [AGENTS.md: what it is and a copy-paste template](#agentsmd-what-it-is-and-a-copy-paste-template)
8. [Prompts you can copy and paste](#prompts-you-can-copy-and-paste)
9. [Tutorial: same prompts, simple LiveView path](#tutorial-same-prompts-simple-liveview-path)
10. [Principles that survived the course](#principles-that-survived-the-course)
11. [Further reading](#further-reading)

---

## Why this article

I took a course on using AI for coding and collected notes, screenshots, and real prompts. This article ties those pieces together **with clearer explanations** for things I only half-understood at first—especially **memory**, **context**, and **when to go fast vs slow**.

If you use **Elixir**, **Phoenix**, or **LiveView**, you’ll see examples aligned with that stack. The ideas apply to any language.

---

## Glossary

| Term | Meaning |
|------|---------|
| **LLM** | Large Language Model. A system trained to predict likely text continuations. |
| **Token** | A chunk of text the model reads and generates (words, subwords, or punctuation—not always equal to a “word”). |
| **Context** | Everything the model can “see” for a given request: instructions, files, chat history, tool results, etc. |
| **Context engineering** | Deliberately shaping what goes into that input so outputs are useful and safe. Older name: *prompt engineering*; as inputs grew (tools, files, rules), the name broadened. |
| **AI application** | A product that uses an LLM for a business goal (e.g. ChatGPT, Cursor, Duolingo Max). |
| **YOLO (workflow)** | “You only live once”: move fast, minimal process, accept more risk. |
| **Commercial MVP** | A minimum product you’d actually ship: plans, docs, tests where they matter, and oversight. |

---

## How LLMs actually work

### Prediction, not memory

An LLM does **not** think the way humans do. For each step, it computes **the most probable next tokens** given its **current input** (the context). It is a very sophisticated **pattern matcher** trained on huge amounts of text and code.

So:

- **Input** → sequence of tokens (your question, rules, pasted code, etc.).
- **Output** → predicted continuation, token by token.

### The “illusion of memory”

It can feel like the model “remembers” you because earlier messages are often **included in the same conversation**. But:

- There is **no personal database** of you.
- If your name or requirements **are not in the current context** (trimmed away, new chat, or never pasted), the model has **nothing reliable** to recall—it may guess or say it doesn’t know.

**Example:** You say “I’m Gustavo” in message 1. Many turns later you ask “What’s my name?” If that early line is **no longer in context** (too far back, or context limit), the model may answer incorrectly or deny knowing. That’s not a bug in “memory”; it’s how the window works.

### “It understands my business”

What people often mean: the model produces **plausible, structured** answers. Under the hood it is still **statistics + context**: training data patterns plus whatever **you** put in the prompt, `AGENTS.md`, and attachments. It does not **verify** facts about your company unless you give them or it retrieves them via tools you wired up.

---

## Context engineering

**The output depends entirely on the input.** Garbage or vague context → weak or risky output.

### Context stack (typical coding agent)

Think of layers that get assembled for each request:

1. **System prompt** — Role, safety, general behavior.
2. **Tools** — Descriptions of what the agent can run (terminal, search, edit).
3. **Memory / persistent notes** — Only what your tool explicitly stores (not “human memory”).
4. **Project rules** — e.g. **`AGENTS.md`** at repo root: *your* constraints, stack, and definition of done.
5. **Conversation / session** — User messages, assistant replies, tool calls and results, snippets from open files.

**Why `AGENTS.md` is its own bullet:** The system prompt is generic. **`AGENTS.md` is your contract** with the agent for *this* repo: Phoenix version, test commands, “use Req not HTTPoison,” no inline scripts, etc. Without it, you repeat the same lecture every chat.

### When to reset the conversation

Consider a **new chat** or **reset** when:

- The model **contradicts** earlier decisions or invents APIs.
- The thread is **huge** and full of noise—old mistakes stay in context and bias the next answer.
- You’re **pivoting** (e.g. “we’re not using OpenRouter anymore”).

Paste a **short brief**: goal, stack, what’s already done, what’s next, and pointers to files.

---

## Choosing a workflow: YOLO, MVP, and mission-critical

One size does not fit all. Rough guide:

### Mission-critical · large codebase · high cost of mistakes

Prefer **controlled** workflows:

| Approach | In practice |
|----------|-------------|
| **Micro-manage, approve, frequent resets** | You review diffs; you reset context when it drifts. |
| **Plan → execute → review → test** | Approve a plan; implement; read code; run tests. |
| **SDD; trust but verify** | Start from a design/spec; verify behavior against it. |

### MVPs · greenfield · learning · boilerplate

You can go **faster**:

| Approach | In practice |
|----------|-------------|
| **YOLO** | Minimal oversight; speed first; you’ll refactor or throw away. |
| **Ralph loops** | Tiny steps, quick feedback, steer with short messages. |
| **Multi-agent / parallel** | Split work; you integrate and reconcile outputs. |

### YOLO vs Commercial MVP (one glance)

| | **YOLO** | **Commercial MVP** |
|---|----------|---------------------|
| **Oversight** | Little; agent runs. | Plan, docs, review. |
| **Risk** | Higher. | Lower, more predictable. |
| **Docs / plan** | Often skipped. | `PLAN.md`, `AGENTS.md`, etc. |
| **Tests** | Optional. | Valuable tests; coverage targets only if sensible. |
| **Fit** | Spikes, demos, learning. | Real users, teams, maintenance. |

**One line:** YOLO = *ship fast, clean up later*; Commercial MVP = *plan, document, test what matters, then ship so you can maintain it.*

**Rule of thumb:** YOLO is **irresponsible** for **payments, auth, security, compliance**, or anything where a wrong line is expensive. Use a controlled loop there.

---

## Plan mode vs Auto mode

*(Names vary by tool; the idea is universal.)*

| | **Plan mode** | **Auto mode** |
|---|----------------|---------------|
| **Edits** | Usually none (read-only research). | Can edit files and run commands. |
| **Purpose** | Design the approach before touching code. | Implement. |
| **Output** | Plan, steps, risks, optional todos. | Code, tests, fixes. |
| **Use when** | You need to **think** or align on approach first. | You’re **comfortable** with the plan and want execution. |

**Short version:** Plan = *figure out what to do*; Auto = *do it*.

---

## AGENTS.md: what it is and a copy-paste template

`AGENTS.md` is **project-level instruction** for an AI assistant: scope, stack, workflow, and standards. Good ones are **short, scannable, and enforced** (you still review code).

### Copy-paste example: Phoenix LiveView side project (profile + optional chat)

Save as **`AGENTS.md`** in the repository root. Adjust names and paths.

```markdown
# AGENTS.md — Profile + AI chat (Phoenix LiveView)

## Product scope

- **What:** Single-user marketing/profile site with optional “Digital Twin” chat about my career.
- **In scope:** LiveView pages, responsive layout, about/career/portfolio sections (portfolio may be placeholders), chat UI calling OpenRouter API from the server.
- **Out of scope:** Multi-tenant auth, admin CMS, billing, email campaigns, mobile apps.

## Technical stack

- **Runtime:** Elixir + Phoenix (LiveView).
- **HTTP client:** Use `Req` for outbound HTTP (OpenRouter). Do not add HTTPoison/Tesla unless explicitly requested.
- **Frontend:** Tailwind as per Phoenix defaults; no inline `<script>` in HEEx—use `assets/js` hooks if needed.
- **Secrets:** `OPENROUTER_API_KEY` via environment / `runtime.exs` only. Never commit `.env` or real keys.

## Definition of done

- `mix compile` and `mix test` pass.
- `mix phx.server` runs; main flows work in browser.
- No secrets in git; README documents required env vars.
- Chat errors show a clear message if API key missing or API fails.

## Workflow

1. For risky or unclear work: **plan first** (short markdown plan or user-approved steps), then implement.
2. Prefer **small PR-sized** changes with a short summary of what changed.
3. After features: suggest **focused tests** (not tests only to raise coverage %).

## Coding standards

- LiveView: use `Layouts.app` / `current_scope` patterns consistent with this Phoenix version.
- Forms: `to_form/2` + `<.form>` + `<.input>`; no raw `form_for`.
- Idiomatic Elixir; no `String.to_atom/1` on user input.
- Keep HEEx accessible (headings, labels, focus states where relevant).

## Design / UX

- Professional, readable typography; sufficient contrast.
- Chat: modern, clear message bubbles; loading state while API responds; empty state when no messages.

## OpenRouter (if chat enabled)

- **Base URL:** `https://openrouter.ai/api/v1/chat/completions` (verify in current docs).
- **Model:** `arcee-ai/trinity-large-preview:free` unless project owner changes it.
- Send only **career/profile context** you are willing to expose to a third-party API.
```

**How to use it:** Commit it, point the agent at the repo, and say “follow `AGENTS.md`.” Refine when the agent keeps making the same mistake—that’s a signal your file is missing a rule.

---

## Prompts you can copy and paste

Below are **ready-to-use prompts** (adjust file names and model IDs if yours differ).

### 1 — Initial LiveView profile page (fast iteration)

```
Please build me a professional page and include in the header a section about me:
my LinkedIn profile is in linkedin.pdf (or I will paste key bullets below).

Make the page stunning: enterprise meets edgy. Include: about me, my career journey,
links to a portfolio (placeholder for future). Iterate until it is as slick and professional
as possible and tell me only when complete. Use LiveView.
```

*Tip:* Prefer **pasting facts** or a **PDF path the tool can read** so the model doesn’t invent your biography.

---

### 2 — “Digital Twin” chat with OpenRouter

```
Add an AI chat with a "Digital Twin" that can answer questions about my career.
Use OpenRouter. My OPENROUTER_API_KEY is in .env in the project root (do not commit it;
load via runtime config).

Use the model named arcee-ai/trinity-large-preview:free.

Make the changes, make sure it works, and tell me when it is ready for me to try.
```

---

### 3 — Beginner-facing `tutorial.md`

```
Please write a comprehensive tutorial in markdown called tutorial.md that is suitable
for a complete beginner in frontend coding. Walk through what you built here: a summary
of the technology, a high-level walkthrough, a detailed code review with code samples,
and end with 5 suggestions for ways the code could be improved based on a self-review.
```

---

### 4 — Replace chat UI (keep behavior, refresh design)

```
This is not working to my taste. Please go a different direction: remove this styling
approach. Use a different, modern chat widget with a strong look and feel (current best
practices). Keep the same LiveView events and API integration; change presentation and UX.
Try again until it feels polished.
```

---

### 5 — Code review only (no code changes)

```
Please do a comprehensive code review of this project and write the results to review.md
including any remedial actions needed. Do not change any application code or configuration;
only create or update review.md.
```

---

### 6 — Review `AGENTS.md` and plan (no implementation yet)

```
Please review AGENTS.md and the project plan (e.g. PLAN.md or docs/*.md), and list any
questions or ambiguities. Do not implement anything yet.
```

---

### 7 — Commercial track: enrich plan + AGENTS + tests

```
1. Enrich PLAN.md with clear phases and success criteria.
2. Create or update AGENTS.md for this repo (frontend + LiveView + API boundaries).
3. Add valuable automated tests (unit where logic exists; integration for critical paths).
   Do not add tests only to inflate coverage. Go ahead.
```

---

### 8 — Pragmatic coverage (manager / lead message you can reuse)

```
Approved — move to the next part. Going forward, aim for high coverage only where it
makes sense; avoid unnecessary tests just to hit a percentage. Focus on valuable tests;
not reaching a specific coverage number is OK if the important paths are covered.
```

---

## Tutorial: same prompts, simple LiveView path

**Goal:** A minimal path that mirrors how I used the course: **one LiveView app**, **profile first**, **chat second**, **docs and review last**.

### Step 0 — Project

```bash
mix phx.new my_profile --live
cd my_profile
```

Add **`AGENTS.md`** (use the template above). Add **OpenRouter** key to env only; wire in `config/runtime.exs` as you would for any secret.

### Step 1

Run **Prompt 1** in your agent. Verify in browser: layout, sections, no compile errors.

### Step 2

Run **Prompt 2**. Manually test: send a message, see reply, break the key and see a sane error.

### Step 3

Run **Prompt 3** so newcomers (or future you) have `tutorial.md`.

### Step 4

If the UI isn’t right, run **Prompt 4** once or twice—keep **events and API** stable.

### Step 5

Run **Prompt 5**; work through `review.md` yourself (the model doesn’t replace your judgment).

### Optional “MVP discipline”

Before large changes, use **Prompts 6–8** so scope and tests stay aligned with reality.

---

## Principles that survived the course

1. **Be the boss** — You decide scope, merges, and production risk.
2. **Invest in `AGENTS.md`** — Concise: spec, style, success criteria.
3. **Start simple, iterate** — Small steps; validate after each.
4. **Demand evidence** — Run tests, click the UI, read the diff.
5. **Handle frustration** — Reset context, narrow the prompt, simplify the task.

**YOLO framing (when you choose it):** Treat defaults as optional; results vary; if stuck, **simplify the goal** or **reset the thread**.

**Ownership:** The model can generate code; **you** are responsible for security, correctness, and maintenance.

---

## Further reading

- Anthropic research on AI assistance and coding skills: [anthropic.com/research](https://www.anthropic.com/research) (search for AI assistance / coding).
- OpenRouter: [openrouter.ai](https://openrouter.ai) — create a key; confirm model IDs in their UI.

---

*Article version 1.0 — generated to consolidate course notes, prompts, and clearer explanations for concepts that are easy to misunderstand at first (memory, context, workflow).*
