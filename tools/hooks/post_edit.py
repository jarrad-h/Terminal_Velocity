"""Claude Code PostToolUse hook: fast feedback after every file edit.

- data/**/*.json  -> must parse as JSON
- *.gd            -> Godot parse check (--check-only), if Godot is found

Exit 2 with a message on stderr sends the problem straight back to Claude,
so it fixes the file before moving on. Exit 0 means all good / not our file.
"""
import json
import os
import shutil
import subprocess
import sys


def godot_exe():
    return os.environ.get("GODOT_PATH") or shutil.which("godot") or shutil.which("godot4")


def main():
    try:
        event = json.load(sys.stdin)
    except Exception:
        return 0
    path = (event.get("tool_input") or {}).get("file_path") or ""
    if not path or not os.path.isfile(path):
        return 0
    project = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()

    if path.endswith(".json"):
        try:
            with open(path, encoding="utf-8") as f:
                json.load(f)
        except json.JSONDecodeError as e:
            print(f"Invalid JSON in {path}: line {e.lineno} col {e.colno}: {e.msg}", file=sys.stderr)
            return 2
        return 0

    if path.endswith(".gd"):
        exe = godot_exe()
        if not exe:
            return 0  # no Godot on this machine (e.g. cloud session); skip quietly
        rel = os.path.relpath(path, project).replace("\\", "/")
        try:
            out = subprocess.run(
                [exe, "--headless", "--path", project, "--check-only", "--script", f"res://{rel}"],
                capture_output=True, text=True, timeout=90,
            )
        except subprocess.TimeoutExpired:
            return 0
        text = (out.stdout or "") + (out.stderr or "")
        bad = [l for l in text.splitlines() if "Parse Error" in l or "SCRIPT ERROR" in l or l.startswith("ERROR")]
        if out.returncode != 0 or bad:
            print(f"Godot parse check failed for {rel}:\n" + "\n".join(bad or text.splitlines()[-20:]), file=sys.stderr)
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
