# Contributing to the Revit MCP Plugin

Thanks for helping make natural-language BIM better! This repo holds the
**Claude plugin** (skill, slash commands, marketplace manifest) and the
**one-click Windows setup scripts**. The Revit tools themselves live in a
separate repo. Read the first section so your change lands in the right place.

- [Where does my change go?](#where-does-my-change-go)
- [Repository map](#repository-map)
- [Development setup](#development-setup)
- [Working on the skill and commands](#working-on-the-skill-and-commands)
- [Working on the setup scripts](#working-on-the-setup-scripts)
- [Syncing the bundled MCP server](#syncing-the-bundled-mcp-server)
- [Versioning and releases](#versioning-and-releases)
- [Submitting a pull request](#submitting-a-pull-request)

---

## Where does my change go?

| I want to… | Repo |
|---|---|
| Add or fix a **tool** / Revit behavior (`tools/`, `revit_mcp/`, `main.py`) | **[revit-mcp-server](https://github.com/Demolinator/revit-mcp-server)** ([its CONTRIBUTING](https://github.com/Demolinator/revit-mcp-server/blob/master/CONTRIBUTING.md)) |
| Improve how Claude **uses** the tools (skill, workflows, references) | **This repo**, `revit-bim/skills/` |
| Add or change a **slash command** | **This repo**, `revit-bim/commands/` |
| Fix the **setup / launcher scripts** or config detection | **This repo**, root `*.ps1` + `lib/` |
| Plugin install / marketplace manifest | **This repo**, `.claude-plugin/`, `revit-bim/.claude-plugin/` |

> ⚠️ **Don't edit `revit-bim/mcp-server/` directly.** It is a vendored copy of
> revit-mcp-server. Make the change upstream first, then sync it here (see
> [Syncing the bundled MCP server](#syncing-the-bundled-mcp-server)). Edits
> made only here get overwritten by the next sync.

---

## Repository map

```
revit-mcp-plugin/
├── .claude-plugin/marketplace.json   # Marketplace catalog (plugin version lives here)
├── revit-bim/                        # ← the plugin
│   ├── .claude-plugin/plugin.json    # Plugin manifest
│   ├── .mcp.json                     # Launches the bundled server via uv
│   ├── commands/*.md                 # Slash commands (/revit-bim:<name>)
│   ├── skills/revit-bim/SKILL.md     # BIM expertise Claude loads on demand
│   ├── skills/revit-bim/references/  # Deeper workflow docs the skill links to
│   ├── CONNECTORS.md                 # Connection setup docs
│   └── mcp-server/                   # Vendored copy of revit-mcp-server (don't edit here)
├── setup-revit-mcp.bat/.ps1          # One-time local setup (default path)
├── setup-web-mobile.bat/.ps1         # Optional ngrok path for web/phone
├── start-revit-mcp.bat/.ps1          # Per-session launcher (web/mobile path)
├── lib/*.ps1                         # Setup helpers (config detection, connector writer, Routes)
├── tests/*.ps1                       # PowerShell tests for setup helpers
└── docs/specs, docs/plans            # Design specs and implementation plans
```

---

## Development setup

Prerequisites: Windows 10/11, Git, [uv](https://docs.astral.sh/uv/), and
[Claude Code](https://claude.com/claude-code). You only need Revit + pyRevit to test
end to end, and many skill/command/docs changes can be reviewed without it.

```powershell
# Fork on GitHub first, then:
git clone https://github.com/<your-username>/revit-mcp-plugin.git
cd revit-mcp-plugin
git remote add upstream https://github.com/Demolinator/revit-mcp-plugin.git
```

### Install your working copy as a plugin

In Claude Code, add your clone as a local marketplace and install from it:

```
/plugin marketplace add C:\path\to\revit-mcp-plugin
/plugin install revit-bim@revit-mcp
```

If you already installed the published plugin, uninstall it first so you know
which copy is running. After editing, update the marketplace
(`/plugin marketplace update revit-mcp`) and restart Claude Code to pick up changes.

To exercise tools end to end, open Revit with a project, make sure the
revit-mcp pyRevit extension is loaded, and check
<http://localhost:48884/revit_mcp/status/>.

---

## Working on the skill and commands

The skill and commands are **prompts**. Their quality is measured by how well
Claude behaves, so please test them in a real conversation.

### Skill (`revit-bim/skills/revit-bim/`)

- `SKILL.md` frontmatter `description` decides **when** Claude loads the skill.
  Keep it listing concrete trigger phrases.
- Keep `SKILL.md` focused on principles and sequencing. Put long procedures in
  `references/*.md` and link them.
- All lengths are **millimeters** (see `references/unit-handling.md`). Keep
  examples consistent with that.
- When the server gains or renames a tool, update `references/available-tools.md`.

### Commands (`revit-bim/commands/*.md`)

- Each command's frontmatter `allowed-tools` pre-approves the MCP tools it
  may call, using the form `mcp__revit__<tool_name>`. When a new server tool
  is relevant to a command, **add it here**. Otherwise users get permission
  prompts mid-workflow.
- `argument-hint` is shown in the command picker. Give a realistic example.
- Keep commands task-shaped (`design-building`, `query-model`) rather than
  tool-shaped.

Check that every tool referenced by a command really exists on the server:

```bash
grep -ho "mcp__revit__[a-z_]*" revit-bim/commands/*.md | sed 's/mcp__revit__//' | sort -u > /tmp/cmd.txt
grep -h -A1 "@mcp.tool" revit-bim/mcp-server/tools/*.py | grep -o "def [a-z_]*" | sed 's/def //' | sort -u > /tmp/srv.txt
comm -23 /tmp/cmd.txt /tmp/srv.txt   # must print nothing
```

### Testing skill and command changes

In your PR, describe at least one real prompt you tried (e.g.
`/revit-bim:design-building 2-storey clinic 20x12 m`) and what Claude did
before and after your change.

---

## Working on the setup scripts

The setup scripts are aimed at **non-developers** (architects and engineers),
so robustness and clear messages matter more than cleverness.

Conventions:

- **Windows PowerShell 5.1 compatible.** No `&&`/`||`, ternaries, or `??`
  (users may not have PowerShell 7).
- **Idempotent.** Running setup twice must be safe. The config writer
  backs up `claude_desktop_config.json` before changing it.
- **Every step supports `-DryRun`**, and dry runs change nothing on disk.
- Native tools (uv, pyrevit.exe) write to stderr. Don't let that become a
  fatal error under `$ErrorActionPreference = 'Stop'` (see
  `lib/Enable-PyRevitRoutes.ps1` for the pattern).
- User-facing output uses the `Section` / `Ok` / `Info` / `Warn` helpers, and
  every failure prints a **manual fallback** the user can follow.
- Put logic in `lib/*.ps1` functions so it's testable. Keep the top-level
  scripts as orchestration.

### Running the tests

```powershell
Get-ChildItem tests\Test-*.ps1 | ForEach-Object {
  Write-Host "== $($_.Name)"; powershell -ExecutionPolicy Bypass -File $_.FullName
}
```

Each test prints `[PASS]`/`[FAIL]` lines and exits non-zero on failure. They
use the tiny helper in `tests/_assert.ps1` (`Assert`, `AssertEq`, `EndTests`).
`Test-EnablePyRevitRoutes.ps1` additionally probes a live Routes server, so
run it with Revit open if you touched Routes logic.

Add a test for any new `lib/` function. If your change affects the whole
flow, include `setup-revit-mcp.ps1 -DryRun` output in your PR.

---

## Syncing the bundled MCP server

`revit-bim/mcp-server/` should match a specific commit of
[revit-mcp-server](https://github.com/Demolinator/revit-mcp-server). To update it:

```powershell
git clone https://github.com/Demolinator/revit-mcp-server.git $env:TEMP\rms
robocopy $env:TEMP\rms revit-bim\mcp-server /MIR /XD .git .venv __pycache__ .github /XF CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md
git -C $env:TEMP\rms rev-parse --short HEAD   # note the SHA
```

Then commit **only** the sync, mentioning the upstream SHA:

```
chore(mcp-server): sync to revit-mcp-server@<sha>
```

After syncing, check whether new tools need adding to command
`allowed-tools`, `references/available-tools.md`, and the tool counts in the
READMEs and manifests (which say "48 tools" in several places).

---

## Versioning and releases

The plugin uses semantic versioning. The version is in
`.claude-plugin/marketplace.json` (`plugins[0].version`).

- **Patch**: docs, prompt wording, setup-script fixes
- **Minor**: new commands, new tools via a server sync, new skill references
- **Major**: breaking changes to install or configuration

Maintainers bump the version when releasing, so you don't need to bump it in
your PR unless asked.

---

## Submitting a pull request

1. Branch from `main`: `git fetch upstream && git checkout -b my-change upstream/main`
2. Keep it focused: one logical change per PR, and **server syncs in their own PR**.
3. Use [Conventional Commits](https://www.conventionalcommits.org/) as in the
   history: `feat(setup): …`, `fix(setup): …`, `docs: …`, `test: …`, `chore: …`.
4. Fill in the PR template: what you tested (dry-run output, prompts tried,
   Revit version).
5. Be patient with review. Setup scripts run on other people's machines,
   so we're careful.

By contributing, you agree your contributions are licensed under the
[Apache License 2.0](LICENSE) (the bundled MCP server remains MIT).

## Code of Conduct and security

Please follow the [Code of Conduct](CODE_OF_CONDUCT.md). Report security
issues privately as described in [SECURITY.md](SECURITY.md), not in public issues.

Questions? Open an issue with the `question` label. 🏗️
