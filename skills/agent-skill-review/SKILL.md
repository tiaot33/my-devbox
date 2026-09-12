---
name: agent-skill-review
description: Review or audit an existing Agent Skill, `SKILL.md`, or skill diff. Use when the user wants findings about spec compliance, trigger quality, structure, responsibility boundaries, bundled references, dependency/setup readiness, or eval readiness.
compatibility: Designed for Codex or similar agents that can read files, inspect a repository, and run a local Python 3 script.
---

# Agent Skill Review

Use this skill to review an Agent Skill as a specification artifact, not as a general code review target.

This is a review-first skill. Do not default into rewrite mode unless the user explicitly asks for fixes or a corrected draft.

Your job is to separate:

- hard spec violations
- trigger and activation problems
- structure and responsibility-boundary issues
- workflow and maintainability issues
- optional improvement ideas

Do not present all feedback as equally important.

## When to use

Use this skill when the user wants to:

- validate an existing skill folder or `SKILL.md`
- review an existing skill or skill diff against the Agent Skills contract
- audit a skill's `name`, `description`, structure, references, or instructions
- check whether a skill is too broad, too generic, or unlikely to trigger
- follow a review with targeted fixes or a corrected draft

Do not use this skill for ordinary code review unless the target is specifically an Agent Skill.
Do not use this skill as the default choice for creating a brand-new skill from scratch.

## Inputs

Accept any of these as the review target:

- a skill directory
- a `SKILL.md` file
- pasted skill content
- a diff that changes a skill

## Authority And Supporting Files

Use the bundled files with this priority:

1. `references/spec-baseline.md`
   Use this to decide what is a hard rule versus a quality recommendation.
2. `references/review-rubric.md`
   Use this as the review checklist and issue taxonomy.
3. `references/authoring-baselines.md`
   Use this for trigger-quality, instruction-quality, dependency/setup, and eval heuristics.
4. `references/INSTALLS.md`
   Read this only when the local review workflow cannot run because a required command or package is missing.
5. `references/reporting-contract.md`
   Read this only when the user explicitly asks for `summary.json` or another machine-readable review artifact.

`SKILL.md` defines the default workflow and default human-readable output behavior.

## Review Workflow

### 1. Establish the target

Identify:

- the skill directory name
- the `SKILL.md` path
- any `agents/*.yaml` files that act as lightweight contract surfaces
- any referenced `scripts/`, `references/`, or `assets/`
- any declared or implied runtime dependencies, packages, CLIs, or external tools
- whether the user wants review only, or review plus rewrite

Read the full `SKILL.md` before making suggestions.

Default assumption:

- structure and responsibility-boundary review focuses on `SKILL.md` plus bundled `references/`
- `scripts/` are reviewed mainly through dependency, setup, or execution-readiness concerns unless the user explicitly expands scope
- `agents/*.yaml` should still be checked for trigger and wording drift

### 2. Run hard validation first

Check the target against the bundled hard rules before discussing style.

Run this command first from this skill directory, or invoke it by absolute path:

```bash
python3 scripts/validate_skill.py <skill-dir>
```

Use the validator output as evidence, but still inspect the file yourself.

The validator is intentionally narrow. It covers frontmatter structure and a few high-value field checks. It does not replace manual review.

Focus first on:

- missing or invalid YAML frontmatter
- unsupported frontmatter fields
- invalid `name`
- missing or weak `description`
- directory name and skill name mismatch
- invalid optional field shapes such as `compatibility`, `metadata`, or `allowed-tools`

If `python3` is missing, or the runtime environment cannot execute the validator, read [references/INSTALLS.md](./references/INSTALLS.md) before continuing.

### 3. Review trigger quality

After hard validation, review whether the skill is likely to activate correctly.

Check whether the `description`:

- tells the agent when to use the skill
- describes user intent, not just implementation details
- includes adjacent contexts where the skill should trigger
- is specific enough to avoid false positives
- stays concise

Call out both failure modes:

- too narrow: the skill will be missed when it would help
- too broad: the skill will activate for nearby but different tasks

Also check `agents/*.yaml` when present. Their trigger wording should stay aligned with `SKILL.md`.

### 4. Review structure and responsibility boundaries

After trigger quality, review whether the skill's information architecture is clean and maintainable.

Default focus:

- `SKILL.md`
- `references/`

Check for these structure problems:

- the same concern is split across multiple files without a clear entry point
- one file mixes unrelated responsibilities, for example core workflow, install steps, schema details, eval mechanics, and long examples all in one place
- `SKILL.md` and `references/` repeat the same content, drift over time, or depend on each other too tightly
- a supporting file carries multiple unrelated concerns instead of one conditional purpose
- the agent would need to load unrelated material just to complete one normal task

Use principle mapping rather than slogan-checking:

- SoC / SRP: each file or section should do one main job
- decoupling: the main workflow should not be tightly coupled to optional reference material
- high cohesion / low coupling: closely related guidance should stay together, and one task should not force loading unrelated instructions
- SOLID is only an auxiliary lens for information architecture; use it only when extension or replacement is clearly painful

Treat structure findings as quality and maintainability findings by default, not hard spec violations.

### 5. Review progressive disclosure and bundled file references

Review whether bundled supporting files are reachable and loaded at the right time.

Check:

- whether bundled Markdown files are explicitly referenced from `SKILL.md`
- whether `SKILL.md` explains when to read those files
- whether bulky or conditional detail should move out of `SKILL.md`
- whether install guidance belongs in `references/INSTALLS.md`

Keep these findings separate from structure findings:

- structure findings are about mixed responsibilities, drift, or bad boundaries
- progressive-disclosure findings are about bundled files not being reachable or not having clear load conditions

### 6. Review instruction quality

Assess whether the body teaches a reusable workflow rather than giving vague advice.

This section is for non-structural workflow and expression quality. Do not mix structure, bundled-file reachability, or install-readiness findings into it.

Look for:

- clear defaults instead of menus of equally weighted options
- procedures that generalize beyond one example
- domain-specific gotchas the model would not infer alone
- coherent scope
- concise, direct guidance instead of commentary-heavy prose
- realistic defaults for review-only versus review-plus-rewrite tasks

Flag generic filler such as "follow best practices" or instructions that only restate obvious model knowledge.

### 7. Review dependency and install readiness

Check whether the reviewed skill requires anything the environment may not already have, for example:

- Python packages
- Node packages
- system CLIs
- language runtimes
- MCP servers
- network access or account credentials

Inspect `SKILL.md`, `scripts/`, and referenced files for dependency clues.

If the reviewed skill requires setup:

- check whether the requirement is stated clearly
- check whether installation or setup steps exist
- if install/setup guidance is missing, call it out and recommend adding `references/INSTALLS.md`
- if `references/INSTALLS.md` exists, check whether `SKILL.md` says when to read it

### 8. Review evaluation readiness

If the skill is meant to be used repeatedly, check whether it is testable.

When the skill lacks validation coverage, propose:

- 2-3 realistic eval prompts
- expected outputs
- a few objective assertions

Do not force a full eval plan when the user only asked for a quick review, but mention the gap.

### 9. Produce the review

Default output behavior:

- findings first
- top-level grouping by severity, not by fixed category order
- cite file paths and lines when possible
- separate spec violations from recommendations
- only include sections that carry real information
- if there are no findings, say so plainly and mention any remaining testing gaps

Within each finding, include:

- severity
- file and line reference when available
- evidence
- why it matters
- a concrete fix

You may still use dedicated category headings when they help clarity, especially for:

- `Structure And Responsibility-Boundary Issues`
- `Progressive-Disclosure And File-Reference Issues`
- `Dependency And Installation Issues`

Do not force empty sections just to match a template.

If the user explicitly asks for `summary.json` or another machine-readable artifact, read [references/reporting-contract.md](./references/reporting-contract.md) and use its stable shapes.

## Rewrite Mode

If the user asks you to fix the skill:

1. preserve the user's domain-specific knowledge
2. fix spec violations first
3. tighten the `description` before expanding the body
4. keep `SKILL.md` lean and move bulky content to `references/` when needed
5. prefer minimal, high-signal edits over adding more text

If the skill has real setup requirements, add or update `references/INSTALLS.md` and make `SKILL.md` point to it with a clear trigger such as "read `references/INSTALLS.md` before using this skill if command X is missing".

When rewriting, keep the skill focused. If one skill is trying to cover unrelated workflows, recommend splitting it rather than patching around the scope problem.
