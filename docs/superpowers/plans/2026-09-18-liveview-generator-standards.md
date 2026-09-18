# LiveView Generator Standards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Phoenix generator structure the documented default for future LiveView work and remove the duplicated LiveView convention file.

**Architecture:** Existing project skills remain the single routed source of agent guidance. Generator-first page ownership goes into the LiveView skill, markup and component rules go into the Phoenix skill, and mirrored test ownership goes into the LiveView testing skill.

**Tech Stack:** Phoenix 1.8, LiveView 1.1, HEEx, ExUnit, project-local Codex skills.

**Spec:** `docs/superpowers/specs/2026-09-18-liveview-generator-standards-design.md`

## Global Constraints

- Preserve current routes, runtime code, existing components, and test locations.
- Keep shared `Form` modules for `:new` and `:edit` valid, including modal flows.
- Do not create a component without explicit engineer approval.
- Apply the generator-first standard prospectively; broad legacy migration is out of scope.

---

### Task 1: Establish generator-first page ownership

**Files:**
- Modify: `.agents/skills/phoenix-liveview/SKILL.md`

**Interfaces:**
- Consumes: Phoenix generator conventions and the approved design spec.
- Produces: Guidance for route/module/template boundaries and LiveView orchestration.

- [ ] **Step 1: Record the baseline gap**

Confirm the skill does not currently document generator-shaped page ownership, matching external templates, boolean assigns, guarded PubSub subscriptions, callback ordering, direct `Repo` prohibition, schema-aligned stream names, or explicit context-result handling.

- [ ] **Step 2: Add the minimal guidance**

Add concise sections covering the missing conventions, the valid shared `Form :new/:edit` exception, namespace mirroring, and prospective rollout.

- [ ] **Step 3: Validate the skill**

Run:

```bash
python3 /Users/gustavooliveira/.codex/skills/.system/skill-creator/scripts/quick_validate.py .agents/skills/phoenix-liveview
```

Expected: validation succeeds.

### Task 2: Add the component gate and resolve HEEx guidance

**Files:**
- Modify: `.agents/skills/phoenix-development/SKILL.md`

**Interfaces:**
- Consumes: The component approval policy and retained markup conventions.
- Produces: Unambiguous component creation and HEEx rules.

- [ ] **Step 1: Record the baseline contradiction**

Confirm the skill currently recommends block-style `<%= for ... %>` while the approved convention requires `:for` on the repeated element, and confirm no explicit approval gate exists for creating components.

- [ ] **Step 2: Replace the conflicting rule and add retained conventions**

Require `:for` for markup collections, add the four-step component approval gate, and retain concise semantic HTML, accessibility, mobile-first, and SEO guidance.

- [ ] **Step 3: Validate the skill**

Run:

```bash
python3 /Users/gustavooliveira/.codex/skills/.system/skill-creator/scripts/quick_validate.py .agents/skills/phoenix-development
```

Expected: validation succeeds.

### Task 3: Align tests with page ownership and remove duplication

**Files:**
- Modify: `.agents/skills/phoenix-liveview-testing/SKILL.md`
- Delete: `lib/alchemistdrops_web/live/CLAUDE.md`

**Interfaces:**
- Consumes: Generator-first module ownership from Task 1.
- Produces: Mirrored test layout and a single routed source of agent instructions.

- [ ] **Step 1: Add test ownership guidance**

Document `index_test.exs`, `show_test.exs`, and shared `form_test.exs` placement alongside their corresponding resource path, including nested namespaces.

- [ ] **Step 2: Verify convention coverage**

Compare the old instruction file with the three edited skills and confirm each retained rule from the design spec has a destination.

- [ ] **Step 3: Remove the duplicated instruction file**

Delete `lib/alchemistdrops_web/live/CLAUDE.md` only after the coverage check passes.

- [ ] **Step 4: Validate the testing skill**

Run:

```bash
python3 /Users/gustavooliveira/.codex/skills/.system/skill-creator/scripts/quick_validate.py .agents/skills/phoenix-liveview-testing
```

Expected: validation succeeds.

### Task 4: Verify and publish the isolated change

**Files:**
- Verify all modified and deleted files from Tasks 1-3.

**Interfaces:**
- Consumes: Completed documentation changes.
- Produces: A reviewable branch and pull request with no runtime behavior changes.

- [ ] **Step 1: Check for contradictions and scope drift**

Search the edited skills for block-style collection guidance, direct component creation recommendations, and accidental legacy migration requirements.

- [ ] **Step 2: Run repository checks**

Run:

```bash
mix format --check-formatted
mix precommit
```

Expected: both commands exit successfully.

- [ ] **Step 3: Review the final diff**

Confirm only the three skills, the removed `CLAUDE.md`, and the approved design/plan documents changed.

- [ ] **Step 4: Commit and push**

```bash
git add .agents/skills/phoenix-liveview/SKILL.md \
  .agents/skills/phoenix-development/SKILL.md \
  .agents/skills/phoenix-liveview-testing/SKILL.md \
  lib/alchemistdrops_web/live/CLAUDE.md \
  docs/superpowers/specs/2026-09-18-liveview-generator-standards-design.md \
  docs/superpowers/plans/2026-09-18-liveview-generator-standards.md
git commit -m "docs(liveview): adopt generator-first standards"
git push -u origin codex/liveview-generator-standards
```

Expected: the remote branch is available for a separate pull request.
