## What does this PR do?

<!-- One or two sentences. Link the issue it closes, e.g. "Closes #4". -->

## Type of change

- [ ] Skill / reference docs
- [ ] Slash command
- [ ] Setup / launcher scripts (`*.ps1`, `lib/`)
- [ ] Sync of bundled `revit-bim/mcp-server` (upstream SHA: `_______`)
- [ ] Docs / manifests / other

## How was it tested?

<!-- Prompts you tried and what Claude did; -DryRun output; test results; Revit version. -->

## Checklist

- [ ] I did **not** hand-edit `revit-bim/mcp-server/` (server changes go to revit-mcp-server first)
- [ ] PowerShell changes work in Windows PowerShell 5.1 and support `-DryRun`
- [ ] `tests\Test-*.ps1` pass (added a test for new `lib/` functions)
- [ ] Commands' `allowed-tools` only reference tools that exist on the server
- [ ] Tool counts / READMEs updated if tools were added or removed
