# Agent Skill Review Rubric

Use this checklist to review an Agent Skill with stable issue categories.

## 1. Hard specification checks

Primary source:

- `references/spec-baseline.md`

Check:

- required directory structure is present
- `SKILL.md` begins with valid YAML frontmatter
- required fields exist
- unknown frontmatter fields are flagged
- `name` follows the hard rules
- `description` is present and not empty
- optional fields that are present have the expected shape

## 2. Trigger quality

Primary source:

- `references/authoring-baselines.md`

Check:

- the `description` says when to use the skill
- it is grounded in user intent, not internal implementation
- it includes nearby real request shapes
- it is specific enough to avoid false positives
- it stays concise
- `agents/*.yaml` stays aligned with `SKILL.md` when present

Watch for:

- under-triggering
- over-triggering

## 3. Structure and responsibility boundaries

Primary sources:

- `references/spec-baseline.md`
- `references/authoring-baselines.md`

Check:

- `SKILL.md` carries the reusable core workflow
- supporting files have a single clear purpose
- related material is not scattered without an entry point
- optional detail is reachable without being tightly coupled to the main flow
- one conceptual change would not require touching too many files

Treat these as quality and maintainability findings by default.

Raise severity when the structure problem directly causes:

- execution mistakes
- obvious mis-triggering
- contradictory instructions
- repeated maintenance drift

## 4. Progressive disclosure and bundled file references

Primary sources:

- `references/spec-baseline.md`
- `references/authoring-baselines.md`

Check:

- bundled Markdown files are referenced from `SKILL.md`
- `SKILL.md` explains when to read each bundled file
- bulky or conditional detail is extracted out of `SKILL.md` when helpful
- setup guidance is reachable through `references/INSTALLS.md` when needed

Keep these findings separate from structure findings.

## 5. Instruction quality

Primary source:

- `references/authoring-baselines.md`

Check:

- defaults are clear
- procedures generalize beyond one example
- the guidance contains non-obvious expertise
- the scope is coherent
- the body is concise enough to stay executable
- review-only and rewrite-mode expectations stay distinct

Red flags:

- generic filler
- many options with no default
- commentary-heavy prose
- bulky output guidance hiding the core workflow

## 6. Dependency and installation readiness

Primary source:

- `references/authoring-baselines.md`

Check:

- the reviewed skill depends on tools, runtimes, packages, credentials, or setup that may be missing
- those requirements are explicit
- setup instructions exist somewhere discoverable
- `references/INSTALLS.md` is recommended when setup is non-trivial
- `SKILL.md` tells the agent when to read `references/INSTALLS.md`

Treat missing install guidance as a real usability and execution-risk issue.

## 7. Eval readiness

Primary source:

- `references/authoring-baselines.md`

Check whether the skill could reasonably support:

- 2-3 realistic prompts
- expected outputs
- a few objective assertions
- at least one edge case or boundary condition
