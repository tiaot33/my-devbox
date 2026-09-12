#!/usr/bin/env python3
"""Minimal validator for Agent Skill directories.

This script is intentionally lightweight so the skill can validate a target
directory without depending on external packages. When PyYAML is available,
it uses it. Otherwise it falls back to a constrained frontmatter parser that
supports the fields this skill cares about most.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ALLOWED_FIELDS = {
    "name",
    "description",
    "license",
    "compatibility",
    "metadata",
    "allowed-tools",
}

NAME_PATTERN = re.compile(r"^[a-z0-9-]+$")


@dataclass
class ValidationProblem:
    severity: str
    code: str
    message: str
    path: str
    line: int | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "severity": self.severity,
            "code": self.code,
            "message": self.message,
            "path": self.path,
            "line": self.line,
        }


def read_frontmatter(skill_md: Path) -> tuple[str, int]:
    content = skill_md.read_text()
    if not content.startswith("---\n"):
        raise ValueError("SKILL.md must start with YAML frontmatter delimited by ---")

    match = re.match(r"^---\n(.*?)\n---(?:\n|$)", content, re.DOTALL)
    if not match:
        raise ValueError("SKILL.md frontmatter is missing a closing --- delimiter")

    return match.group(1), match.start(1) + 1


def parse_with_pyyaml(frontmatter: str) -> dict[str, Any]:
    import yaml  # type: ignore

    parsed = yaml.safe_load(frontmatter)
    if not isinstance(parsed, dict):
        raise ValueError("Frontmatter must be a YAML mapping")
    return parsed


def parse_minimal_frontmatter(frontmatter: str) -> dict[str, Any]:
    parsed: dict[str, Any] = {}
    lines = frontmatter.splitlines()
    i = 0
    while i < len(lines):
        raw = lines[i]
        line = raw.rstrip()
        if not line.strip():
            i += 1
            continue
        if raw.startswith(" ") or raw.startswith("\t"):
            raise ValueError(f"Unexpected indentation at frontmatter line {i + 1}")
        if ":" not in line:
            raise ValueError(f"Invalid frontmatter line {i + 1}: {line}")

        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip()

        if value in {"|", ">", "|-", ">-"}:
            block_lines: list[str] = []
            i += 1
            while i < len(lines):
                block = lines[i]
                if block.startswith("  ") or block.startswith("\t"):
                    block_lines.append(block[2:] if block.startswith("  ") else block.lstrip("\t"))
                    i += 1
                    continue
                if not block.strip():
                    block_lines.append("")
                    i += 1
                    continue
                break
            parsed[key] = "\n".join(block_lines).strip()
            continue

        if value == "":
            nested: dict[str, str] = {}
            i += 1
            while i < len(lines):
                nested_line = lines[i]
                if not nested_line.strip():
                    i += 1
                    continue
                if not nested_line.startswith("  "):
                    break
                nested_text = nested_line[2:]
                if ":" not in nested_text:
                    raise ValueError(
                        f"Invalid nested metadata at frontmatter line {i + 1}: {nested_text}"
                    )
                nested_key, nested_value = nested_text.split(":", 1)
                nested[nested_key.strip()] = strip_quotes(nested_value.strip())
                i += 1
            parsed[key] = nested
            continue

        parsed[key] = strip_quotes(value)
        i += 1

    return parsed


def strip_quotes(value: str) -> str:
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        return value[1:-1]
    return value


def parse_frontmatter(frontmatter: str) -> dict[str, Any]:
    try:
        return parse_with_pyyaml(frontmatter)
    except ModuleNotFoundError:
        return parse_minimal_frontmatter(frontmatter)


def line_of(frontmatter: str, key: str) -> int | None:
    prefix = f"{key}:"
    for idx, line in enumerate(frontmatter.splitlines(), start=1):
        if line.startswith(prefix):
            return idx
    return None


def validate_allowed_tools(value: Any) -> str | None:
    if not isinstance(value, str):
        return "Field 'allowed-tools' must be a string when present"

    tokens = value.split()
    if not tokens:
        return "Field 'allowed-tools' must not be empty when present"

    if any(not token.strip() for token in tokens):
        return "Field 'allowed-tools' must contain space-separated tool entries"

    return None


def validate_skill(skill_path: Path) -> list[ValidationProblem]:
    problems: list[ValidationProblem] = []

    if skill_path.is_file() and skill_path.name.lower() == "skill.md":
        skill_path = skill_path.parent

    if not skill_path.exists():
        return [
            ValidationProblem(
                severity="error",
                code="missing_path",
                message=f"Path does not exist: {skill_path}",
                path=str(skill_path),
            )
        ]

    if not skill_path.is_dir():
        return [
            ValidationProblem(
                severity="error",
                code="not_directory",
                message=f"Not a directory: {skill_path}",
                path=str(skill_path),
            )
        ]

    skill_md = None
    for candidate in ("SKILL.md", "skill.md"):
        path = skill_path / candidate
        if path.exists():
            skill_md = path
            break

    if skill_md is None:
        return [
            ValidationProblem(
                severity="error",
                code="missing_skill_md",
                message="Missing required file: SKILL.md",
                path=str(skill_path),
            )
        ]

    try:
        frontmatter, _ = read_frontmatter(skill_md)
    except ValueError as exc:
        return [
            ValidationProblem(
                severity="error",
                code="frontmatter_error",
                message=str(exc),
                path=str(skill_md),
                line=1,
            )
        ]

    try:
        metadata = parse_frontmatter(frontmatter)
    except ValueError as exc:
        return [
            ValidationProblem(
                severity="error",
                code="parse_error",
                message=str(exc),
                path=str(skill_md),
            )
        ]

    extra = sorted(set(metadata) - ALLOWED_FIELDS)
    if extra:
        problems.append(
            ValidationProblem(
                severity="error",
                code="unexpected_fields",
                message=f"Unexpected frontmatter fields: {', '.join(extra)}",
                path=str(skill_md),
            )
        )

    name = metadata.get("name")
    if not isinstance(name, str) or not name.strip():
        problems.append(
            ValidationProblem(
                severity="error",
                code="missing_name",
                message="Field 'name' must be a non-empty string",
                path=str(skill_md),
                line=line_of(frontmatter, "name"),
            )
        )
    else:
        normalized = name.strip()
        if len(normalized) > 64:
            problems.append(
                ValidationProblem(
                    severity="error",
                    code="name_too_long",
                    message=f"Skill name exceeds 64 characters ({len(normalized)})",
                    path=str(skill_md),
                    line=line_of(frontmatter, "name"),
                )
            )
        if normalized != normalized.lower():
            problems.append(
                ValidationProblem(
                    severity="error",
                    code="name_not_lowercase",
                    message="Skill name must be lowercase",
                    path=str(skill_md),
                    line=line_of(frontmatter, "name"),
                )
            )
        if normalized.startswith("-") or normalized.endswith("-") or "--" in normalized:
            problems.append(
                ValidationProblem(
                    severity="error",
                    code="name_hyphen_rules",
                    message="Skill name cannot start/end with a hyphen or contain consecutive hyphens",
                    path=str(skill_md),
                    line=line_of(frontmatter, "name"),
                )
            )
        if not NAME_PATTERN.fullmatch(normalized):
            problems.append(
                ValidationProblem(
                    severity="error",
                    code="name_invalid_chars",
                    message="Skill name must use lowercase letters, digits, and hyphens only",
                    path=str(skill_md),
                    line=line_of(frontmatter, "name"),
                )
            )
        if skill_path.name != normalized:
            problems.append(
                ValidationProblem(
                    severity="error",
                    code="directory_name_mismatch",
                    message=f"Directory name '{skill_path.name}' must match skill name '{normalized}'",
                    path=str(skill_md),
                    line=line_of(frontmatter, "name"),
                )
            )

    description = metadata.get("description")
    if not isinstance(description, str) or not description.strip():
        problems.append(
            ValidationProblem(
                severity="error",
                code="missing_description",
                message="Field 'description' must be a non-empty string",
                path=str(skill_md),
                line=line_of(frontmatter, "description"),
            )
        )
    else:
        desc = description.strip()
        if len(desc) > 1024:
            problems.append(
                ValidationProblem(
                    severity="error",
                    code="description_too_long",
                    message=f"Description exceeds 1024 characters ({len(desc)})",
                    path=str(skill_md),
                    line=line_of(frontmatter, "description"),
                )
            )
        if len(desc) < 20:
            problems.append(
                ValidationProblem(
                    severity="warning",
                    code="description_too_weak",
                    message="Description is present but likely too short to describe what the skill does and when to use it",
                    path=str(skill_md),
                    line=line_of(frontmatter, "description"),
                )
            )

    compatibility = metadata.get("compatibility")
    if compatibility is not None:
        if not isinstance(compatibility, str):
            problems.append(
                ValidationProblem(
                    severity="error",
                    code="compatibility_not_string",
                    message="Field 'compatibility' must be a string when present",
                    path=str(skill_md),
                    line=line_of(frontmatter, "compatibility"),
                )
            )
        elif len(compatibility) > 500:
            problems.append(
                ValidationProblem(
                    severity="error",
                    code="compatibility_too_long",
                    message=f"Compatibility exceeds 500 characters ({len(compatibility)})",
                    path=str(skill_md),
                    line=line_of(frontmatter, "compatibility"),
                )
            )

    metadata_field = metadata.get("metadata")
    if metadata_field is not None:
        if not isinstance(metadata_field, dict):
            problems.append(
                ValidationProblem(
                    severity="error",
                    code="metadata_not_mapping",
                    message="Field 'metadata' must be a key-value mapping when present",
                    path=str(skill_md),
                    line=line_of(frontmatter, "metadata"),
                )
            )
        else:
            bad_entries = [
                key for key, value in metadata_field.items()
                if not isinstance(key, str) or not isinstance(value, str)
            ]
            if bad_entries:
                problems.append(
                    ValidationProblem(
                        severity="error",
                        code="metadata_non_string_values",
                        message="Field 'metadata' should use string keys and values only",
                        path=str(skill_md),
                        line=line_of(frontmatter, "metadata"),
                    )
                )

    allowed_tools = metadata.get("allowed-tools")
    if allowed_tools is not None:
        allowed_tools_error = validate_allowed_tools(allowed_tools)
        if allowed_tools_error:
            problems.append(
                ValidationProblem(
                    severity="error",
                    code="allowed_tools_invalid",
                    message=allowed_tools_error,
                    path=str(skill_md),
                    line=line_of(frontmatter, "allowed-tools"),
                )
            )

    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate an Agent Skill directory")
    parser.add_argument("skill_path", help="Path to the skill directory or SKILL.md file")
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit machine-readable JSON instead of text output",
    )
    args = parser.parse_args()

    skill_path = Path(args.skill_path).resolve()
    problems = validate_skill(skill_path)

    if args.json:
        print(json.dumps([problem.to_dict() for problem in problems], indent=2))
    else:
        if not problems:
            print("Skill is valid.")
        else:
            for problem in problems:
                line_suffix = f":{problem.line}" if problem.line else ""
                print(
                    f"[{problem.severity}] {problem.code} "
                    f"{problem.path}{line_suffix} - {problem.message}"
                )

    has_error = any(problem.severity == "error" for problem in problems)
    return 1 if has_error else 0


if __name__ == "__main__":
    sys.exit(main())
