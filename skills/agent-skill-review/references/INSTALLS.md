# INSTALLS

Read this file only when the local review workflow for `agent-skill-review` cannot run as written.

The default validation command is:

```bash
python3 scripts/validate_skill.py <skill-dir>
```

## Required Runtime

This skill expects:

- `python3` on `PATH`

Check it with:

```bash
python3 --version
```

If that command fails, install a usable Python 3 runtime and rerun the validator.

## Optional Package

The validator can use `PyYAML` when it is already available, but it does not require it.

Without `PyYAML`, the script falls back to a constrained frontmatter parser that covers the fields this skill validates directly.

## When To Read This File

Read this file when:

- `python3` is missing
- the validator script cannot start
- you need to confirm what this skill itself depends on before reviewing another skill

Do not read this file by default when the validator already runs.

## Notes For Review Work

This file documents how to run `agent-skill-review` itself.

When reviewing some other skill, a missing or unclear `references/INSTALLS.md` in that target skill is still a normal dependency/install finding.
