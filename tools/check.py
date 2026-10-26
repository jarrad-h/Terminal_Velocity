"""One command that says whether the build is healthy.  python tools/check.py

1. Every data/**/*.json parses.
2. Godot imports the project with no script errors.
3. GUT unit tests in tests/unit pass (skipped if GUT isn't installed yet).
4. Smoke test: boots tests/smoke/smoke.tscn headless for ~10 s of game time and fails
   on any error/warning printed (skipped until the smoke scene exists).
5. Scenario test: tests/smoke/scenario.tscn flies, fights, streams scenery and drives
   every debug command, then exits non-zero on any failed check. Its negative checks
   (unknown IDs) print expected errors, so only the exit code counts.

Exit code 0 = green. Claude Code runs this before every commit.
"""
import glob
import json
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT_PATH") or shutil.which("godot") or shutil.which("godot4")
ERROR_MARKERS = ("SCRIPT ERROR", "Parse Error", "ERROR:", "USER ERROR", "WARNING:")
# Known harmless output of the import step only: the GUT editor plugin starts a 1 s
# SceneTreeTimer in _enter_tree, and --import quits before it fires.
IMPORT_NOISE = ("WARNING: ObjectDB instances leaked at exit",)
failed = []


def step(name, ok, detail=""):
    print(f"[{'PASS' if ok else 'FAIL'}] {name}")
    if not ok:
        failed.append(name)
        if detail:
            print("    " + detail.replace("\n", "\n    "))


def run_godot(args, timeout=300):
    out = subprocess.run([GODOT, "--headless", "--path", ROOT, *args],
                         capture_output=True, text=True, timeout=timeout)
    return out.returncode, (out.stdout or "") + (out.stderr or "")


def problems(text):
    return [l for l in text.splitlines() if any(m in l for m in ERROR_MARKERS)]


# 1. JSON
bad = []
for f in glob.glob(os.path.join(ROOT, "data", "**", "*.json"), recursive=True):
    try:
        json.load(open(f, encoding="utf-8"))
    except Exception as e:
        bad.append(f"{os.path.relpath(f, ROOT)}: {e}")
step("data JSON parses", not bad, "\n".join(bad))

if not GODOT:
    print("Godot not found (set GODOT_PATH or put godot on PATH); skipping engine checks.")
    sys.exit(1 if failed else 0)

# 2. Import
code, text = run_godot(["--import"])
p = [l for l in problems(text) if not l.startswith(IMPORT_NOISE)]
step("project imports cleanly", code == 0 and not p, "\n".join(p[:30]))

# 3. Unit tests
if os.path.exists(os.path.join(ROOT, "addons", "gut", "gut_cmdln.gd")):
    code, text = run_godot(["-s", "addons/gut/gut_cmdln.gd", "-gdir=res://tests/unit", "-ginclude_subdirs", "-gexit"])
    step("unit tests (GUT)", code == 0, "\n".join(text.splitlines()[-40:]))
else:
    print("[SKIP] unit tests: addons/gut not installed")

# 4. Smoke
if os.path.exists(os.path.join(ROOT, "tests", "smoke", "smoke.tscn")):
    code, text = run_godot(["res://tests/smoke/smoke.tscn", "--quit-after", "600"], timeout=180)
    p = problems(text)
    step("smoke run (600 frames)", not p, "\n".join(p[:30]))
else:
    print("[SKIP] smoke test: tests/smoke/smoke.tscn not created yet")

# 5. Scenario
if os.path.exists(os.path.join(ROOT, "tests", "smoke", "scenario.tscn")):
    code, text = run_godot(["res://tests/smoke/scenario.tscn"], timeout=300)
    fails = [l for l in text.splitlines() if l.startswith("FAIL") or "SCRIPT ERROR" in l]
    step("scenario test", code == 0 and not fails, "\n".join(fails[:30] or text.splitlines()[-20:]))
else:
    print("[SKIP] scenario test: tests/smoke/scenario.tscn not found")

print("\nGREEN" if not failed else f"\nRED: {', '.join(failed)}")
sys.exit(1 if failed else 0)
