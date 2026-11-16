#!/usr/bin/env python3
"""ReelGold release helper.

  python tools/release.py bump --interface 16002 --client 1.60.2
      Point the addon at a new WoW: Forever client: updates the TOC
      "## Interface" line and Data/GameVersion.lua, and adds a CHANGELOG entry.

  python tools/release.py data --note "Added Riverglades spots"
      Bump DATA_VERSION after editing Data/*.lua (users get a notice in game).

  python tools/release.py package --version 1.1.0
      Build dist/ReelGold-1.1.0.zip ready for a manual CurseForge upload
      (the GitHub workflow does the same automatically on a "v*" tag).

Then commit and tag:
  git commit -am "Update for 1.60.2" && git tag v1.1.0 && git push --follow-tags
"""
import argparse
import datetime
import pathlib
import re
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOC = ROOT / "ReelGold.toc"
GAMEVER = ROOT / "Data" / "GameVersion.lua"
CHANGELOG = ROOT / "CHANGELOG.md"
PACKAGE_IGNORE = {"README.md", "CHANGELOG.md", "tools", ".github", ".git", ".gitignore",
                  ".editorconfig", ".gitattributes", ".pkgmeta", "dist",
                  "tests", "package.json", "package-lock.json", "node_modules"}


def read(p):
    return p.read_text(encoding="utf-8")


def write(p, text):
    p.write_text(text, encoding="utf-8", newline="")


def sub_once(pattern, repl, text, what):
    new, n = re.subn(pattern, repl, text, count=1, flags=re.M)
    if n != 1:
        sys.exit(f"Could not find {what}")
    return new


def changelog(line):
    today = datetime.date.today().isoformat()
    text = read(CHANGELOG)
    header = "## Unreleased"
    if header not in text:
        text = text.replace("# Changelog\n", f"# Changelog\n\n{header}\n", 1)
    text = text.replace(header + "\n", f"{header}\n- {line} ({today})\n", 1)
    write(CHANGELOG, text)


def cmd_bump(a):
    toc = read(TOC)
    toc = sub_once(r"^## Interface: .*$", f"## Interface: {a.interface}", toc, "## Interface line")
    write(TOC, toc)

    gv = read(GAMEVER)
    gv = sub_once(r"TESTED_INTERFACE = \d+", f"TESTED_INTERFACE = {a.interface}", gv, "TESTED_INTERFACE")
    gv = sub_once(r'TESTED_CLIENT = "[^"]*"', f'TESTED_CLIENT = "{a.client}"', gv, "TESTED_CLIENT")
    write(GAMEVER, gv)
    changelog(f"Updated for WoW: Forever {a.client} (interface {a.interface})")
    print(f"Interface -> {a.interface}, client -> {a.client}")


def cmd_data(a):
    gv = read(GAMEVER)
    m = re.search(r"DATA_VERSION = (\d+)", gv)
    if not m:
        sys.exit("DATA_VERSION not found")
    new = int(m.group(1)) + 1
    gv = gv.replace(m.group(0), f"DATA_VERSION = {new}", 1)
    gv = sub_once(r'DATA_DATE = "[^"]*"', f'DATA_DATE = "{datetime.date.today().isoformat()}"', gv, "DATA_DATE")
    write(GAMEVER, gv)
    changelog(f"Data v{new}: {a.note}")
    print(f"DATA_VERSION -> {new}")


def cmd_package(a):
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    out = dist / f"ReelGold-{a.version}.zip"
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(ROOT.rglob("*")):
            rel = f.relative_to(ROOT)
            if f.is_dir() or rel.parts[0] in PACKAGE_IGNORE:
                continue
            arc = "ReelGold/" + rel.as_posix()
            if f.suffix in (".toc", ".lua"):
                z.writestr(arc, read(f).replace("@project-version@", a.version))
            else:
                z.write(f, arc)
    print(out)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    s = p.add_subparsers(dest="cmd", required=True)
    b = s.add_parser("bump")
    b.add_argument("--interface", type=int, required=True, help="value of /dump select(4, GetBuildInfo())")
    b.add_argument("--client", required=True, help="client version, e.g. 1.60.2")
    b.set_defaults(fn=cmd_bump)
    d = s.add_parser("data")
    d.add_argument("--note", required=True)
    d.set_defaults(fn=cmd_data)
    k = s.add_parser("package")
    k.add_argument("--version", required=True)
    k.set_defaults(fn=cmd_package)
    a = p.parse_args()
    a.fn(a)


if __name__ == "__main__":
    main()
