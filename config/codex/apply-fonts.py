#!/usr/bin/env python3
import os
import re
import sys
import tempfile


THEME_TABLE = "[desktop.appearanceDarkChromeTheme]"
FONTS_TABLE = "[desktop.appearanceDarkChromeTheme.fonts]"
SEMANTIC_TABLE = "[desktop.appearanceDarkChromeTheme.semanticColors]"


def table_bounds(lines, header):
    start = None
    for index, line in enumerate(lines):
        if line.strip() == header:
            start = index
            break

    if start is None:
        return None

    end = len(lines)
    for index in range(start + 1, len(lines)):
        if re.match(r"^\s*\[[^\]]+\]\s*(?:#.*)?$", lines[index]):
            end = index
            break

    return start, end


def first_existing_table(lines, headers):
    positions = []
    for header in headers:
        bounds = table_bounds(lines, header)
        if bounds is not None:
            positions.append(bounds[0])
    return min(positions) if positions else len(lines)


def format_line(key, value):
    return f"{key} = {value}\n"


def upsert_table(lines, header, values, insert_at=None):
    bounds = table_bounds(lines, header)

    if bounds is None:
        block = []
        if lines and lines[insert_at - 1 if insert_at else -1].strip():
            block.append("\n")
        block.append(f"{header}\n")
        block.extend(format_line(key, value) for key, value in values.items())

        if insert_at is None:
            insert_at = len(lines)
        lines[insert_at:insert_at] = block
        return lines

    start, end = bounds
    seen = set()
    for index in range(start + 1, end):
        match = re.match(r"^(\s*)([A-Za-z0-9_-]+)(\s*=).*$", lines[index])
        if match is None:
            continue

        key = match.group(2)
        if key in values:
            lines[index] = format_line(key, values[key])
            seen.add(key)

    missing = [format_line(key, value) for key, value in values.items() if key not in seen]
    if missing:
        insert_at = end
        while insert_at > start + 1 and not lines[insert_at - 1].strip():
            insert_at -= 1
        lines[insert_at:insert_at] = missing

    return lines


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: apply-fonts.py CONFIG_PATH FONT_FAMILY")

    config_path = os.path.expanduser(sys.argv[1])
    font_family = sys.argv[2]

    os.makedirs(os.path.dirname(config_path), exist_ok=True)

    try:
        with open(config_path, "r", encoding="utf-8") as config_file:
            original = config_file.readlines()
    except FileNotFoundError:
        original = []

    lines = list(original)
    quoted_font_family = '"' + font_family.replace("\\", "\\\\").replace('"', '\\"') + '"'

    theme_values = {
        "accent": '"#339cff"',
        "contrast": "60",
        "ink": '"#ffffff"',
        "opaqueWindows": "false",
        "surface": '"#181818"',
    }
    font_values = {
        "ui": quoted_font_family,
        "code": quoted_font_family,
    }
    semantic_values = {
        "diffAdded": '"#40c977"',
        "diffRemoved": '"#fa423e"',
        "skill": '"#ad7bf9"',
    }

    theme_insert_at = first_existing_table(lines, [FONTS_TABLE, SEMANTIC_TABLE])
    lines = upsert_table(lines, THEME_TABLE, theme_values, theme_insert_at)

    theme_bounds = table_bounds(lines, THEME_TABLE)
    fonts_insert_at = theme_bounds[1] if theme_bounds is not None else len(lines)
    lines = upsert_table(lines, FONTS_TABLE, font_values, fonts_insert_at)

    fonts_bounds = table_bounds(lines, FONTS_TABLE)
    semantic_insert_at = fonts_bounds[1] if fonts_bounds is not None else len(lines)
    lines = upsert_table(lines, SEMANTIC_TABLE, semantic_values, semantic_insert_at)

    if lines == original:
        return

    fd, tmp_path = tempfile.mkstemp(
        prefix=".config.toml.",
        dir=os.path.dirname(config_path),
        text=True,
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as tmp_file:
            tmp_file.writelines(lines)
        os.replace(tmp_path, config_path)
    except Exception:
        try:
            os.unlink(tmp_path)
        except FileNotFoundError:
            pass
        raise


if __name__ == "__main__":
    main()
