#!/usr/bin/env python3
"""Fail a release PR when bilingual release documentation is missing or stale."""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys


DEFAULT_REQUIRED_FILES = ("README.md", "README.zh-CN.md", "CHANGELOG.md")

ENGLISH_SECTIONS = {
    "overview": ("overview", "introduction", "about", "what is"),
    "features": ("features", "capabilities"),
    "screenshots": ("screenshots", "demo", "preview"),
    "requirements": ("requirements", "compatibility", "supported platforms"),
    "installation": ("install", "setup"),
    "usage": ("quick start", "getting started", "usage"),
    "privacy": ("privacy", "data", "security"),
    "support": ("troubleshooting", "support", "feedback", "faq"),
    "license": ("license", "licence"),
}

CHINESE_SECTIONS = {
    "overview": ("概览", "简介", "介绍", "关于"),
    "features": ("功能", "特性", "能力"),
    "screenshots": ("截图", "演示", "预览"),
    "requirements": ("系统要求", "运行要求", "兼容性", "支持平台"),
    "installation": ("安装", "部署"),
    "usage": ("快速开始", "使用", "入门"),
    "privacy": ("隐私", "数据", "安全"),
    "support": ("故障排查", "问题反馈", "支持", "常见问题"),
    "license": ("许可证", "许可协议", "授权"),
}


def git(*args: str, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    completed = subprocess.run(
        ["git", *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if check and completed.returncode != 0:
        message = completed.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(message or f"git {' '.join(args)} failed")
    return completed


def ref_exists(ref: str) -> bool:
    return git("rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}", check=False).returncode == 0


def choose_base_ref(explicit: str | None) -> str:
    if explicit:
        return explicit
    github_base = os.environ.get("GITHUB_BASE_REF")
    if github_base:
        remote = f"origin/{github_base}"
        return remote if ref_exists(remote) else github_base
    previous_tag = git("describe", "--tags", "--abbrev=0", "HEAD^", check=False)
    if previous_tag.returncode == 0:
        value = previous_tag.stdout.decode("utf-8", errors="replace").strip()
        if value:
            return value
    return "HEAD^"


def file_at_ref(ref: str, path: str) -> str | None:
    completed = git("show", f"{ref}:{path}", check=False)
    if completed.returncode != 0:
        return None
    return completed.stdout.decode("utf-8", errors="replace")


def markdown_headings(text: str) -> list[str]:
    return [match.group(1).strip() for match in re.finditer(r"(?m)^#{1,6}\s+(.+?)\s*$", text)]


def missing_sections(text: str, aliases: dict[str, tuple[str, ...]]) -> list[str]:
    headings = "\n".join(markdown_headings(text)).casefold()
    return [
        section
        for section, choices in aliases.items()
        if not any(choice.casefold() in headings for choice in choices)
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-ref", help="Base commit/ref; defaults to PR base, previous tag, or HEAD^")
    parser.add_argument("--head-ref", default="HEAD", help="Release candidate commit/ref")
    parser.add_argument(
        "--required-file",
        action="append",
        dest="required_files",
        help="Required changed file. Repeat to override the default bilingual README and changelog set.",
    )
    parser.add_argument("--version", help="Expected version text in CHANGELOG.md")
    parser.add_argument(
        "--skip-section-check",
        action="store_true",
        help="Check changed files only. Prefer adapting heading aliases instead for a permanent release gate.",
    )
    args = parser.parse_args()

    try:
        root = git("rev-parse", "--show-toplevel").stdout.decode("utf-8", errors="replace").strip()
        os.chdir(root)
        base_ref = choose_base_ref(args.base_ref)
        head_ref = args.head_ref
        if not ref_exists(base_ref):
            raise RuntimeError(f"base ref does not exist: {base_ref}")
        if not ref_exists(head_ref):
            raise RuntimeError(f"head ref does not exist: {head_ref}")

        changed_output = git("diff", "--name-only", f"{base_ref}...{head_ref}").stdout.decode(
            "utf-8", errors="replace"
        )
        changed = {line.strip() for line in changed_output.splitlines() if line.strip()}
        required = tuple(args.required_files or DEFAULT_REQUIRED_FILES)
        errors: list[str] = []

        for path in required:
            if path not in changed:
                errors.append(f"required release document was not changed: {path}")
            if file_at_ref(head_ref, path) is None:
                errors.append(f"required release document is missing at {head_ref}: {path}")

        english = file_at_ref(head_ref, "README.md")
        chinese = file_at_ref(head_ref, "README.zh-CN.md")
        changelog = file_at_ref(head_ref, "CHANGELOG.md")

        if not args.skip_section_check:
            if english is not None:
                for section in missing_sections(english, ENGLISH_SECTIONS):
                    errors.append(f"README.md is missing a heading for: {section}")
            if chinese is not None:
                for section in missing_sections(chinese, CHINESE_SECTIONS):
                    errors.append(f"README.zh-CN.md 缺少对应标题: {section}")

        if english is not None and not re.search(r"(?i)\]\((?:\./)?README\.zh-CN\.md(?:#[^)]*)?\)", english):
            errors.append("README.md must link to README.zh-CN.md")
        if chinese is not None and not re.search(r"(?i)\]\((?:\./)?README\.md(?:#[^)]*)?\)", chinese):
            errors.append("README.zh-CN.md 必须链接到 README.md")

        if args.version and changelog is not None and args.version not in changelog:
            errors.append(f"CHANGELOG.md does not mention expected version: {args.version}")

        if errors:
            print("Release documentation gate failed:", file=sys.stderr)
            for error in errors:
                print(f"- {error}", file=sys.stderr)
            return 1

        print(
            f"Release documentation gate passed for {base_ref}...{head_ref}: "
            + ", ".join(required)
        )
        return 0
    except (RuntimeError, OSError) as exc:
        print(f"release gate error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
