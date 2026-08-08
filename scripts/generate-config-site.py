#!/usr/bin/env python3
"""Generate a single-page site from the repository's config files."""

import argparse
import fnmatch
import hashlib
import html
import os
import subprocess
import sys
import tempfile
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EMACS_SOURCE = Path(".emacs.d/bootstrap.org")
EMACS_RENDERER = ROOT / "scripts" / "render-emacs-config-to-html.sh"
STYLESHEET = ROOT / "scripts" / "config-site.css"
MAX_FILE_BYTES = 1_000_000
DEFAULT_EXCLUDES = (
    ".DS_Store",
    "*.lock",
    "*.db",
    "*.elc",
    "*.png",
    "*.jpg",
    "*.jpeg",
    "*.gif",
    "*.webp",
    "*.icns",
    "*.woff*",
    "*.ttf",
    "*.pdf",
    ".env*",
    "*credentials*",
    "*secret*",
    "id_rsa*",
    "site/**",
    "scripts/output/**",
    "**/__pycache__/**",
)

LANGUAGES = {
    ".css": "css",
    ".el": "lisp",
    ".html": "markup",
    ".ini": "ini",
    ".json": "json",
    ".jsonc": "json",
    ".lua": "lua",
    ".md": "markdown",
    ".nix": "nix",
    ".org": "markup",
    ".rasi": "css",
    ".scss": "scss",
    ".sh": "bash",
    ".toml": "toml",
    ".xml": "markup",
    ".yaml": "yaml",
    ".yml": "yaml",
    ".yuck": "lisp",
}

SPECIAL_LANGUAGES = {
    "Brewfile": "ruby",
    ".gitconfig": "ini",
    ".ideavimrc": "vim",
    ".tmux.conf": "bash",
    ".vimrc": "vim",
    ".Xmodmap": "text",
}

GROUP_NAMES = {
    ".emacs.d": "Emacs",
    ".github": "GitHub",
    ".pi": "Pi",
    "nix-darwin": "Nix Darwin",
    "nixos": "NixOS",
    "zsh": "Zsh",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=ROOT / "site" / "index.html",
        help="output HTML path (default: site/index.html)",
    )
    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        metavar="GLOB",
        help="additional repository-relative glob to exclude; repeatable",
    )
    return parser.parse_args()


def repository_files() -> list[Path]:
    """Return tracked files, failing closed outside a Git checkout."""
    try:
        result = subprocess.run(
            ["git", "ls-files", "-z"],
            cwd=ROOT,
            check=True,
            capture_output=True,
        )
    except FileNotFoundError as error:
        raise RuntimeError("Git is required to discover publishable files") from error
    except subprocess.CalledProcessError as error:
        detail = error.stderr.decode(errors="replace").strip()
        message = "not inside a Git repository"
        raise RuntimeError(f"could not list tracked files: {detail or message}") from error

    return [ROOT / os.fsdecode(item) for item in result.stdout.split(b"\0") if item]


def is_excluded(relative: Path, patterns: tuple[str, ...]) -> bool:
    name = relative.as_posix()
    return any(
        fnmatch.fnmatch(name, pattern) or fnmatch.fnmatch(relative.name, pattern)
        for pattern in patterns
    )


def read_text(path: Path) -> str | None:
    try:
        data = path.read_bytes()
    except OSError as error:
        print(f"warning: skipping {path}: {error}", file=sys.stderr)
        return None
    if len(data) > MAX_FILE_BYTES:
        print(f"warning: skipping {path}: larger than {MAX_FILE_BYTES:,} bytes", file=sys.stderr)
        return None
    if b"\0" in data:
        return None
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return None


def group_name(relative: Path) -> str:
    if len(relative.parts) == 1:
        return "General"
    first = relative.parts[0]
    return GROUP_NAMES.get(first, first.lstrip(".").replace("-", " ").title())


def language_for(path: Path, source: str) -> str:
    if path.name in SPECIAL_LANGUAGES:
        return SPECIAL_LANGUAGES[path.name]
    if path.suffix in LANGUAGES:
        return LANGUAGES[path.suffix]
    if source.startswith("#!") and "sh" in source.splitlines()[0]:
        return "bash"
    return "text"


def file_id(relative: Path) -> str:
    path = relative.as_posix()
    slug = "".join(char if char.isalnum() else "-" for char in path).strip("-")
    digest = hashlib.sha256(path.encode()).hexdigest()[:10]
    return f"file-{slug}-{digest}"


def render_file(relative: Path, source: str) -> str:
    path = relative.as_posix()
    line_count = len(source.splitlines())
    language = language_for(relative, source)
    return f"""
<article class="file" id="{file_id(relative)}">
  <header class="file-header">
    <div>
      <h3>{html.escape(relative.name)}</h3>
      <p>{html.escape(path)} · {line_count:,} lines</p>
    </div>
    <button class="copy" type="button" aria-label="Copy {html.escape(path, quote=True)}">Copy</button>
  </header>
  <pre><code class="language-{language}">{html.escape(source)}</code></pre>
</article>"""


def render_site(files: list[tuple[Path, str]], stylesheet: str) -> str:
    grouped: dict[str, list[tuple[Path, str]]] = defaultdict(list)
    for relative, source in files:
        grouped[group_name(relative)].append((relative, source))

    navigation = []
    sections = []
    for group in sorted(grouped, key=str.casefold):
        entries = sorted(grouped[group], key=lambda item: item[0].as_posix().casefold())
        group_id = "group-" + group.lower().replace(" ", "-")
        if group == "Emacs":
            navigation.append(
                '<a href="emacs.html"><span>Emacs guide</span><b>↗</b></a>'
            )
            heading = '<a href="emacs.html">Emacs <small>Open documented config →</small></a>'
        else:
            navigation.append(
                f'<a href="#{group_id}"><span>{html.escape(group)}</span><b>{len(entries)}</b></a>'
            )
            heading = html.escape(group)
        cards = "\n".join(render_file(path, source) for path, source in entries)
        sections.append(
            f'<section class="group" id="{group_id}"><h2>{heading}</h2>{cards}</section>'
        )

    return TEMPLATE.replace("{{NAVIGATION}}", "\n".join(navigation)).replace(
        "{{SECTIONS}}", "\n".join(sections)
    ).replace("{{FILE_COUNT}}", str(len(files))).replace(
        "{{GROUP_COUNT}}", str(len(grouped))
    ).replace("{{STYLESHEET}}", stylesheet)


TEMPLATE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Dotfiles</title>
  <link rel="preconnect" href="https://cdnjs.cloudflare.com">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism-tomorrow.min.css">
  <style>
{{STYLESHEET}}
  </style>
</head>
<body>
  <aside>
    <h1>Dotfiles</h1>
    <p>{{FILE_COUNT}} tracked files across {{GROUP_COUNT}} groups</p>
    <button class="nav-toggle" type="button" aria-expanded="false" aria-controls="site-navigation">Browse sections</button>
    <nav id="site-navigation">{{NAVIGATION}}</nav>
  </aside>
  <main>
    <header class="intro">
      <h1>Configuration,<br>documented by itself.</h1>
      <p>Generated from the repository source.</p>
    </header>
    {{SECTIONS}}
  </main>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-core.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/plugins/autoloader/prism-autoloader.min.js"></script>
  <script>
    const sidebar = document.querySelector('aside');
    const navToggle = document.querySelector('.nav-toggle');
    navToggle.addEventListener('click', () => {
      const open = sidebar.classList.toggle('nav-open');
      navToggle.setAttribute('aria-expanded', String(open));
    });
    document.querySelectorAll('.copy').forEach(button => button.addEventListener('click', async () => {
      await navigator.clipboard.writeText(button.closest('.file').querySelector('code').textContent);
      button.textContent = 'Copied';
      setTimeout(() => button.textContent = 'Copy', 1200);
    }));
  </script>
</body>
</html>
"""


def main() -> int:
    args = parse_args()
    patterns = DEFAULT_EXCLUDES + tuple(args.exclude)
    try:
        candidates = repository_files()
    except RuntimeError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    files: list[tuple[Path, str]] = []

    for path in candidates:
        try:
            relative = path.relative_to(ROOT)
        except ValueError:
            continue
        if is_excluded(relative, patterns) or relative == EMACS_SOURCE:
            continue
        source = read_text(path)
        if source is not None:
            files.append((relative, source))

    if not files:
        print("error: no publishable files found", file=sys.stderr)
        return 1

    output = args.output.expanduser().resolve()
    emacs_output = output.with_name("emacs.html")
    if output == emacs_output:
        print("error: the main output cannot be named emacs.html", file=sys.stderr)
        return 1

    try:
        stylesheet = STYLESHEET.read_text(encoding="utf-8")
    except OSError as error:
        print(f"error: could not read {STYLESHEET}: {error}", file=sys.stderr)
        return 1

    output.parent.mkdir(parents=True, exist_ok=True)
    try:
        with tempfile.TemporaryDirectory(
            prefix=".config-site-", dir=output.parent
        ) as staging_directory:
            staging = Path(staging_directory)
            staged_index = staging / output.name
            staged_emacs = staging / emacs_output.name
            subprocess.run(
                ["bash", str(EMACS_RENDERER), str(staged_emacs)],
                cwd=ROOT,
                check=True,
            )
            staged_index.write_text(
                render_site(files, stylesheet), encoding="utf-8"
            )
            os.replace(staged_emacs, emacs_output)
            os.replace(staged_index, output)
    except (OSError, subprocess.CalledProcessError) as error:
        print(f"error: could not generate site: {error}", file=sys.stderr)
        return 1

    print(f"Generated {output} from {len(files)} files")
    print(f"Generated {emacs_output} from {EMACS_SOURCE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
