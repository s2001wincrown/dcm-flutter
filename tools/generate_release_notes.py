from __future__ import annotations

import subprocess
import sys
from pathlib import Path


def run_git(args: list[str], cwd: Path) -> str:
    result = subprocess.run(
        ['git', *args],
        cwd=str(cwd),
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return ''
    return result.stdout.strip()


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    tag = sys.argv[1] if len(sys.argv) > 1 else run_git(['describe', '--tags', '--abbrev=0'], repo_root)
    tag = tag.strip()
    if not tag:
        tag = 'unreleased'

    tags = [line.strip() for line in run_git(['tag', '--list', '--sort=-version:refname'], repo_root).splitlines() if line.strip()]
    previous_tag = ''
    if len(tags) > 1:
        previous_tag = tags[1]

    if previous_tag:
        log_range = f'{previous_tag}..{tag}'
    elif tag != 'unreleased':
        log_range = tag
    else:
        log_range = ''

    if log_range:
        log_output = run_git(['log', '--pretty=format:- %s', log_range], repo_root)
    else:
        log_output = '- Initial release'

    if not log_output:
        log_output = '- Initial release'

    notes = [
        f'# Release {tag}',
        '',
        '## Changes',
        '',
        log_output,
        '',
    ]

    output_path = Path(sys.argv[2]) if len(sys.argv) > 2 else repo_root / 'release-artifacts' / 'release-notes.md'
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text('\n'.join(notes), encoding='utf-8')
    print(f'Generated release notes at {output_path}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
