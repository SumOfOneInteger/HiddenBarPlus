#!/usr/bin/env python3
"""Print the CHANGELOG section for one version, as Markdown or minimal HTML.

    scripts/release-notes.py 1.0.0           # Markdown (GitHub release body)
    scripts/release-notes.py 1.0.0 --html    # HTML (embedded in the Sparkle appcast)

The section is the first "## " heading whose text contains the version, up to
the next "## " heading. Exits non-zero when there is none: every release needs
notes.
"""
import html
import re
import sys
from pathlib import Path


def section(changelog: str, version: str) -> str:
    lines = changelog.splitlines()
    start = next(
        (i for i, line in enumerate(lines) if line.startswith("## ") and re.search(rf"(?<![\d.]){re.escape(version)}(?![\d.])", line)),
        None,
    )
    if start is None:
        sys.exit(f"CHANGELOG.md has no '## ...' section mentioning {version}")
    body = []
    for line in lines[start + 1:]:
        if line.startswith("## "):
            break
        body.append(line)
    text = "\n".join(body).strip("\n")
    if not text.strip():
        sys.exit(f"the CHANGELOG section for {version} is empty")
    return text


def to_html(markdown: str, version: str) -> str:
    """Enough Markdown for a changelog: ### headings, - bullets, paragraphs, `code`, links."""

    def inline(text: str) -> str:
        text = html.escape(text, quote=False)
        text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
        text = re.sub(r"\[([^\]]+)\]\((https?://[^)\s]+)\)", r'<a href="\2">\1</a>', text)
        text = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", text)
        text = re.sub(r"(?<!\*)\*([^*\n]+)\*(?!\*)", r"<em>\1</em>", text)
        return text

    out = [f"<h2>Hidden Bar Plus {html.escape(version)}</h2>"]
    paragraph: list[str] = []
    items: list[str] = []

    def flush_paragraph():
        if paragraph:
            out.append("<p>" + inline(" ".join(paragraph)) + "</p>")
            paragraph.clear()

    def flush_items():
        if items:
            out.append("<ul>" + "".join(f"<li>{inline(i)}</li>" for i in items) + "</ul>")
            items.clear()

    for line in markdown.splitlines():
        stripped = line.strip()
        if not stripped:
            flush_paragraph()
            flush_items()
        elif stripped.startswith("### "):
            flush_paragraph()
            flush_items()
            out.append(f"<h3>{inline(stripped[4:])}</h3>")
        elif re.match(r"^[-*] ", stripped):
            flush_paragraph()
            items.append(stripped[2:])
        elif items and line.startswith("  "):
            items[-1] += " " + stripped
        else:
            flush_items()
            paragraph.append(stripped)
    flush_paragraph()
    flush_items()
    return "\n".join(out) + "\n"


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 1:
        sys.exit(__doc__)
    version = args[0]
    changelog = (Path(__file__).resolve().parent.parent / "CHANGELOG.md").read_text(encoding="utf-8")
    notes = section(changelog, version)
    if "--html" in sys.argv:
        sys.stdout.write(to_html(notes, version))
    else:
        sys.stdout.write(notes + "\n")


if __name__ == "__main__":
    main()
