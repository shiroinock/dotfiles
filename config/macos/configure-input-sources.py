#!/usr/bin/env python3
import os
import plistlib
import sys
import tempfile
from pathlib import Path


AZOOKEY_BUNDLE_ID = "dev.ensan.inputmethod.azooKeyMac"
AZOOKEY_JAPANESE_MODE = "dev.ensan.inputmethod.azooKeyMac.Japanese"

AZOOKEY_INPUT_METHOD = {
    "Bundle ID": AZOOKEY_BUNDLE_ID,
    "InputSourceKind": "Keyboard Input Method",
}

AZOOKEY_JAPANESE_INPUT_MODE = {
    "Bundle ID": AZOOKEY_BUNDLE_ID,
    "Input Mode": AZOOKEY_JAPANESE_MODE,
    "InputSourceKind": "Input Mode",
}


def plist_path() -> Path:
    if len(sys.argv) > 1:
        return Path(sys.argv[1]).expanduser()
    return Path.home() / "Library/Preferences/com.apple.HIToolbox.plist"


def load_plist(path: Path) -> dict:
    if not path.exists():
        return {}

    with path.open("rb") as f:
        return plistlib.load(f)


def source_exists(sources: list, source: dict) -> bool:
    return any(all(candidate.get(key) == value for key, value in source.items()) for candidate in sources)


def append_once(sources: list, source: dict) -> bool:
    if source_exists(sources, source):
        return False

    sources.append(source)
    return True


def write_plist(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as f:
            plistlib.dump(data, f, fmt=plistlib.FMT_BINARY)
        os.replace(tmp_name, path)
    finally:
        if os.path.exists(tmp_name):
            os.unlink(tmp_name)


def main() -> int:
    path = plist_path()
    data = load_plist(path)
    enabled_sources = data.setdefault("AppleEnabledInputSources", [])
    history = data.setdefault("AppleInputSourceHistory", [])

    changed = False
    changed |= append_once(enabled_sources, AZOOKEY_JAPANESE_INPUT_MODE)
    changed |= append_once(enabled_sources, AZOOKEY_INPUT_METHOD)
    changed |= append_once(history, AZOOKEY_JAPANESE_INPUT_MODE)

    if changed:
        write_plist(path, data)
        print("Configured azooKey input source.")
    else:
        print("azooKey input source is already configured.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
