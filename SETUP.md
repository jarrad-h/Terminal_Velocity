# Terminal Velocity — Claude Code workflow setup (Windows)

About 20 minutes, once. After this, everything (design, build, test, playtest notes) happens in Claude Code against the repo.

## 1. Install the prerequisites

Open PowerShell:

```powershell
winget install OpenJS.NodeJS.LTS        # needed by the Godot MCP server (Node 18+)
winget install Python.Python.3.12       # runs tools/check.py and the edit hook
node --version; python --version        # close and reopen PowerShell first if these aren't found
```

You also need Git, GitHub CLI and the Claude Code command-line tool. If `claude --version` says "not recognized":

```powershell
Test-Path "$env:USERPROFILE\.local\bin\claude.exe"     # False = not installed
irm https://claude.ai/install.ps1 | iex                 # install it
# if it's installed but still not found, add it to PATH, then reopen PowerShell:
$p = [Environment]::GetEnvironmentVariable('PATH', 'User')
[Environment]::SetEnvironmentVariable('PATH', "$p;$env:USERPROFILE\.local\bin", 'User')
```

## 2. Pin a Godot path Claude can use headless

Use the **console** build of Godot (`Godot_v4.7.2-stable_win64_console.exe`, it ships in the same zip as the normal exe). The console exe prints errors to the terminal, which is how Claude reads them.

```powershell
# adjust to where your Godot lives
setx GODOT_PATH "C:\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe"
```

Reopen PowerShell, then check: `& $env:GODOT_PATH --version`

## 3. Give Claude Code eyes on the running game (Godot MCP)

```powershell
claude mcp add godot --scope user -e GODOT_PATH="$env:GODOT_PATH" -- npx -y @coding-solo/godot-mcp
claude mcp list        # 'godot' should show as connected
```

This lets Claude launch the editor, run the project in debug mode and read the console output and errors itself, instead of you pasting stack traces.

*Optional upgrade later:* GDAI MCP (paid plugin, about US$19 one-off) adds screenshots of the running game and simulated key presses, so Claude can fly the ship and look at the radar. Worth it once you're tired of describing visual bugs.

## 4. Drop this kit into the repo

Copy the contents of this folder into the root of your Terminal_Velocity clone (merge `.claude/`, `docs/`, `tools/`). If `docs/devlog.md` already exists, keep yours.

## 5. Run the bootstrap prompt

In the repo folder: `claude`, then paste the prompt below.

```
We're switching to a repo-first workflow. Read SETUP.md, CLAUDE.workflow.md, docs/spec.md and docs/decisions.md.

First run `git status`. If there is uncommitted Milestone 3 work, stop and ask me what to do with it.

Then, on a new branch `workflow-setup`:
1. Merge CLAUDE.workflow.md into CLAUDE.md (keep existing conventions, resolve contradictions in favour of the new section and tell me which), then delete CLAUDE.workflow.md.
   Fill in the "Pinned Godot version" line with the exact version from `& $env:GODOT_PATH --version`. Make sure .gitignore excludes `.godot/` but not `*.uid`.
2. Install GUT (Godot Unit Test, latest version for our Godot 4.x) into addons/gut and enable it in project.godot.
3. Create tests/unit/ with first tests for code that already exists: flight maths (F2 speed cap and drift, F3 values from data) and the data loader (bad reference names the file and field; mod override replaces by ID). If the flight maths isn't separable from the scene yet, make the smallest refactor needed so it is, per the "simulation separate from visuals" architecture rule.
4. Create tests/smoke/smoke.tscn: boots the main system scene headless, spawns one of every ship ID through DebugCommands (or the nearest existing equivalent), and lets it run. It must print nothing containing ERROR or WARNING on a healthy build.
5. Run `python tools/check.py` until GREEN. Then run the game via the godot MCP server for a few seconds and confirm no runtime errors.
6. Confirm the PostToolUse hook fires: make a deliberate JSON typo in a scratch file under data/, see the hook reject it, then delete the file.
7. Commit, push the branch, and summarise what you changed and anything that looked wrong.
```

Review the summary, then tell it to merge to main.

## 6. Turn on Remote Control

In Claude Code run `/config` and enable Remote Control for all sessions. Your PC sessions then appear in the Claude phone app (Code tab), so you can type playtest notes from the couch and they land in the same session that has the repo, the tests and the running game.

## 7. Second PC

On the other machine, do steps 1, 2, 3 and 6 only, using the **same Godot version**. Then clone the repo (outside OneDrive), open Claude Code in it and say "start". Skills, hooks, tests and docs all arrive with the clone; the bootstrap prompt is not needed again.

## Daily loop

| You want to… | Say in Claude Code |
|---|---|
| Begin a session (either PC) | "start" → pulls, checks Godot version and MCP, runs checks, reads back where you stopped |
| Talk design / change scope | "design: should boarding take time?" → spec + decisions updated, committed |
| Build | "/milestone 3" → plan, you approve, it builds, tests, runs the game, hands you a checklist |
| Report a playtest | "playtest: missiles too slow, radar fine, ship got stuck on landing" → sorted into bug / tuning / design |
| Ship it | "milestone 3 is good" → check, merge, push, spec ticked |
| Stop / switch PCs | "wrap up" → handover note in devlog, commit, push |

The claude.ai Game Build project becomes optional: use it for big-picture brainstorming if you like, but the repo is what counts.
