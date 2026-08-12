"""MkDocs build hook for the Google Play landing page and audio demos."""

from pathlib import Path
from shutil import copy2, copytree


_PRESERVE_BLANK_LINE_TAGS = ("pre", "script", "style", "textarea")


def _compact_generated_html(html: str) -> str:
    """Remove generated blank-line noise without changing code blocks."""
    lines = []
    preserve_blank_lines = False

    for raw_line in html.splitlines():
        line = raw_line.rstrip()
        lower = line.lower()

        if preserve_blank_lines or line.strip():
            lines.append(line)

        if any(f"<{tag}" in lower and f"</{tag}>" not in lower for tag in _PRESERVE_BLANK_LINE_TAGS):
            preserve_blank_lines = True
        if preserve_blank_lines and any(f"</{tag}>" in lower for tag in _PRESERVE_BLANK_LINE_TAGS):
            preserve_blank_lines = False

    return "\n".join(lines) + "\n"


def _strip_generated_text_whitespace(path: Path) -> None:
    """Normalize generated text assets so repository checks stay clean."""
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return

    lines = [line.rstrip() for line in text.splitlines()]
    while lines and not lines[-1]:
        lines.pop()
    path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")


def on_post_build(config, **kwargs):
    """Add non-MkDocs public files to the final GitHub Pages artifact."""
    repository_root = Path(config.config_file_path).resolve().parent
    site_dir = Path(config.site_dir)

    for filename in ("index.html", "styles.css", "app-ads.txt"):
        copy2(repository_root / filename, site_dir / filename)

    homepage_images = site_dir / "images"
    homepage_images.mkdir(parents=True, exist_ok=True)
    for filename in ("app_launcher_icon.png", "menu_logo.png"):
        copy2(repository_root / "images" / filename, homepage_images / filename)

    copytree(
        repository_root / "assets" / "audio",
        site_dir / "assets" / "audio",
        dirs_exist_ok=True,
    )

    # Keep checked-in generated pages diff-clean without modifying the
    # hand-maintained Google Play landing page copied above.
    for html_path in site_dir.glob("*.html"):
        if html_path.name == "index.html":
            continue
        html = html_path.read_text(encoding="utf-8")
        html_path.write_text(_compact_generated_html(html), encoding="utf-8", newline="\n")

    for pattern in ("*.css", "*.js", "*.map", "*.json", "*.xml"):
        for text_path in site_dir.rglob(pattern):
            if (site_dir / "assets" / "audio") in text_path.parents:
                continue
            _strip_generated_text_whitespace(text_path)