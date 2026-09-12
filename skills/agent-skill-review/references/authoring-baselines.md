# Authoring Baselines

Use this file when reviewing trigger quality, instruction quality, dependency/setup readiness, or eval readiness.

This file is heuristic guidance, not a hard-rule source.

## Trigger Quality

Review the `description` using these rules:

- tell the agent when to use the skill
- describe user intent, not internal implementation
- include adjacent contexts where the skill should trigger
- stay specific enough to avoid false positives
- stay concise enough to remain readable in a skill catalog

Call out both failure modes:

- under-triggering: too narrow, too abstract, or missing nearby real prompts
- over-triggering: broad enough to catch adjacent but different tasks

Near-miss prompts are useful evidence for explaining trigger problems.

## Instruction Quality

Look for these qualities:

- grounded in real expertise, artifacts, or correction history
- focused on what the model would not know by default
- coherent scope
- moderate detail instead of exhaustive catch-all prose
- defaults instead of menus
- procedures over declarations
- gotchas for non-obvious environment facts
- supporting files that are reachable with explicit load conditions

Red flags:

- generic filler
- many options with no default
- long concept explanations the model already knows
- multiple unrelated workflows forced into one skill
- supporting documents exist but `SKILL.md` never tells the agent to read them
- `SKILL.md` is carrying bulky reference material that should move to `references/`
- output guidance is so heavy that it hides the actual workflow

## Dependency And Setup Readiness

Review whether the skill depends on tools, runtimes, packages, credentials, MCP servers, or network access that may be missing.

If setup is needed:

- the requirement should be explicit
- installation or configuration steps should be documented
- `references/INSTALLS.md` is the preferred place for non-trivial setup guidance
- `SKILL.md` should say when to read `references/INSTALLS.md`

Treat missing install guidance as a real execution-risk issue, even when the skill is otherwise solid.

## Eval Readiness

A reusable skill should be easy to evaluate. When coverage is missing, review against this minimum:

- 2-3 realistic prompts
- expected outputs
- a few objective assertions
- at least one edge case or boundary condition

When the skill is meant to improve behavior over baseline, with-skill versus baseline comparison is a strong recommendation, but not every quick review needs a full eval harness.
