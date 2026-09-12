# Reporting Contract

Read this file only when the user explicitly asks for `summary.json` or another machine-readable review artifact.

Default human-readable reviews do not need this file.

## Human-Readable Default

Unless the user asks for a machine-readable artifact:

- put findings before summaries
- group top-level findings by severity
- cite file paths and lines when possible
- include only sections that carry real information
- say plainly when no findings were found

## `summary.json`

When `summary.json` is requested, prefer this top-level layout:

```json
{
  "target": {
    "skill_dir": "path/to/skill",
    "skill_file": "path/to/SKILL.md"
  },
  "validator": {
    "ran": true,
    "command": "python3 scripts/validate_skill.py path/to/skill",
    "result": "valid"
  },
  "overall_verdict": "valid_but_needs_improvement",
  "hard_spec_violations": [],
  "trigger_problems": [],
  "structure_issues": [],
  "workflow_issues": [],
  "file_reference_issues": {
    "subdirectory_markdown_present": false,
    "subdirectory_markdown_files": [],
    "referenced_from_skill_md": true,
    "skill_md_explains_when_to_read_them": true,
    "notes": ""
  },
  "extraction_targets": [],
  "dependencies": {
    "cli_tools": [],
    "python_packages": [],
    "node_packages": [],
    "runtimes": [],
    "external_services": [],
    "environment_requirements": [],
    "credentials": []
  },
  "install_doc_recommended": false,
  "install_doc_notes": [],
  "eval_coverage": {
    "present": false,
    "recommended_prompts": []
  },
  "optional_suggestions": []
}
```

## Stable Shape Rules

Use stable shapes for these keys:

- `structure_issues`
- `workflow_issues`
- `file_reference_issues`
- `extraction_targets`
- `dependencies`
- `install_doc_recommended`

Rules:

- `structure_issues` must always be an array
- `workflow_issues` must always be an array
- `extraction_targets` must always be an array
- `file_reference_issues` must always be an object with the documented keys
- `dependencies` must always be an object with the documented keys
- `install_doc_recommended` must always be a boolean

Use `workflow_issues` only for non-structural workflow, wording, or instruction-quality problems.

## Structured Shapes

Use this object shape for each structure issue:

```json
{
  "area": "SKILL.md|references",
  "files": ["references/foo.md"],
  "principles": ["SoC", "low_coupling"],
  "problem": "Short description",
  "why_it_matters": "Operational impact",
  "fix": "Concrete rewrite direction"
}
```

When progressive-disclosure or file-reference issues are relevant, use this object shape:

```json
{
  "file_reference_issues": {
    "subdirectory_markdown_present": true,
    "subdirectory_markdown_files": [
      "path/to/reference-a.md"
    ],
    "referenced_from_skill_md": false,
    "skill_md_explains_when_to_read_them": false,
    "notes": "Short explanation"
  },
  "extraction_targets": [
    {
      "file": "path/to/SKILL.md",
      "lines": "10-30",
      "target_reference": "path/to/reference-a.md",
      "reason": "Why this should move"
    }
  ]
}
```

When dependency or installation issues are relevant, use this object shape:

```json
{
  "dependencies": {
    "cli_tools": ["uv", "jq"],
    "python_packages": ["pandas"],
    "node_packages": [],
    "runtimes": ["Python 3"],
    "external_services": ["partner API"],
    "environment_requirements": ["network access"],
    "credentials": ["staging profile credentials"]
  },
  "install_doc_recommended": true
}
```
