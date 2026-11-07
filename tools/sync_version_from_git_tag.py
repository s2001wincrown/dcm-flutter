from __future__ import annotations

import re
import subprocess
from pathlib import Path


def run_git(args: list[str], cwd: Path) -> subprocess.CompletedProcess[str] | None:
    try:
        return subprocess.run(
            ['git', *args],
            cwd=str(cwd),
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        return None


def resolve_tag(cwd: Path) -> str | None:
    local_fetch = run_git(['tag', '--list', '--sort=-version:refname'], cwd)
    if local_fetch is not None and local_fetch.returncode == 0:
        output = local_fetch.stdout.strip()
        if output:
            for line in output.splitlines():
                tag = line.strip()
                if tag:
                    tag = tag[1:] if tag.startswith(('v', 'V')) else tag
                    return tag

    fetch_result = run_git(['fetch', '--tags', 'origin'], cwd)
    if fetch_result is not None and fetch_result.returncode == 0:
        remote_fetch = run_git(['tag', '--list', '--sort=-version:refname'], cwd)
        if remote_fetch is not None and remote_fetch.returncode == 0:
            output = remote_fetch.stdout.strip()
            if output:
                for line in output.splitlines():
                    tag = line.strip()
                    if tag:
                        tag = tag[1:] if tag.startswith(('v', 'V')) else tag
                        return tag

    describe_result = run_git(['describe', '--tags', '--abbrev=0'], cwd)
    if describe_result is not None and describe_result.returncode == 0:
        output = describe_result.stdout.strip()
        if output:
            tag = output.splitlines()[0].strip()
            tag = tag[1:] if tag.startswith(('v', 'V')) else tag
            if tag:
                return tag

    return None


def sync_pubspec_version(repo_root: Path) -> str:
    pubspec = repo_root / 'pubspec.yaml'
    if not pubspec.exists():
        raise FileNotFoundError(f'pubspec.yaml not found in {repo_root}')

    tag = resolve_tag(repo_root)
    if tag is None:
        print('No git tag found; leaving pubspec.yaml unchanged.')
        return 'unchanged'

    text = pubspec.read_text(encoding='utf-8')
    new_line = f'version: {tag}'
    updated, count = re.subn(
        r'(?m)^version:\s*.*$',
        new_line,
        text,
        count=1,
    )
    if count == 0:
        raise ValueError('Could not find a version line in pubspec.yaml')

    pubspec.write_text(updated, encoding='utf-8')
    print(f'Updated pubspec.yaml version to {tag}')
    return tag


if __name__ == '__main__':
    repo_root = Path(__file__).resolve().parent.parent
    sync_pubspec_version(repo_root)
