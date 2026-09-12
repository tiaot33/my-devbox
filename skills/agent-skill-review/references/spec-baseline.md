# Spec Baseline

Use this file to decide whether a finding is a real Agent Skill contract problem or just a quality recommendation.

This is the hard-rule baseline for this review skill. Keep it narrow.

## Hard Structure Rules

- A skill is a directory containing `SKILL.md` at minimum.
- `scripts/`, `references/`, and `assets/` are optional.
- `SKILL.md` must start with YAML frontmatter, followed by Markdown body content.

## Required Frontmatter

Required fields:

- `name`
- `description`

Allowed optional fields:

- `license`
- `compatibility`
- `metadata`
- `allowed-tools`

Treat unknown frontmatter fields as a spec problem.

## `name` Rules

- 1-64 characters
- lowercase letters, digits, and hyphens only
- must not start or end with `-`
- must not contain consecutive hyphens
- should match the parent directory name

## `description` Rules

- 1-1024 characters
- non-empty
- should describe both what the skill does and when to use it

A weak description may pass the minimum presence check but still deserve a trigger-quality finding.

## Optional Field Checks

- `license`: if present, keep it short and specific
- `compatibility`: if present, must be a concise string
- `metadata`: if present, must be a string key/value mapping
- `allowed-tools`: if present, must be a string; deeper syntax review is manual unless a validator explicitly implements more checks

## Progressive-Disclosure Baseline

Use these rules when deciding whether a structure or bundled-file issue is real:

- `name` and `description` are the catalog surface
- `SKILL.md` should hold the reusable core workflow
- bulky or conditional detail belongs in `references/` or similar supporting files
- if supporting Markdown files exist, `SKILL.md` should point to them explicitly
- `SKILL.md` should say when to read each supporting file, not just that the files exist
- if setup guidance exists in `references/INSTALLS.md`, `SKILL.md` should say when to read it
