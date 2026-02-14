# beadboard.nvim

Neovim frontend for the [beads](https://github.com/anthropics/beads)
issue tracker. Browse, triage, and manage issues without leaving
your editor.

## Features

- **List view** — columnar issue browser with filtering, sorting,
  and bulk operations
- **Detail view** — rich single-issue display with inline editing
- **Create wizard** — step-by-step issue creation flow
- **Dependency graph** — ASCII art visualization of issue
  relationships
- **Epic tracking** — progress bars for epics and their children
- **Activity feed** — live event stream with auto-refresh
- **Project dashboard** — summary charts by status, priority,
  type, assignee, and label
- **Statusline** — drop-in function for lualine or any statusline
- **Picker integration** — fuzzy issue picker via snacks.nvim
  or telescope.nvim, with graceful fallback to `vim.ui.select`
- **Bulk operations** — visual-mode multi-issue status changes,
  close, delete, and defer
- **Claude Code integration** — dispatch Claude skills from any
  bead view with per-bead session tracking and auto-refresh

## Requirements

- Neovim >= 0.10
- [`bd`](https://github.com/anthropics/beads) CLI on `$PATH`
- (Optional) [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
  for fuzzy issue picking
- (Optional) [snacks.nvim](https://github.com/folke/snacks.nvim)
  for modern fuzzy issue picking (preferred over telescope)
- (Optional) [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
  CLI for skill dispatch

## Installation

### lazy.nvim

```lua
{
  'jfmyers9/beadboard',
  config = function()
    require('beadboard').setup()
  end,
}
```

### packer.nvim

```lua
use {
  'jfmyers9/beadboard',
  config = function()
    require('beadboard').setup()
  end,
}
```

### Manual

Clone the repository and add it to your runtimepath:

```bash
git clone https://github.com/jfmyers9/beadboard ~/.local/share/nvim/site/pack/plugins/start/beadboard
```

Then in your config:

```lua
require('beadboard').setup()
```

## Configuration

All options are optional. Pass a table to `setup()` to override
defaults:

```lua
require('beadboard').setup({
  bd_cmd = 'bd',            -- path to the bd CLI binary
  default_limit = 50,       -- max issues per list query
  default_sort = 'priority', -- default sort field
})
```

| Option | Type | Default | Description |
|---|---|---|---|
| `bd_cmd` | string | `'bd'` | Path to the `bd` CLI binary |
| `default_limit` | number | `50` | Maximum issues fetched per list query |
| `default_sort` | string | `'priority'` | Default sort field for list view |
| `picker` | string | `'auto'` | Issue picker backend: `'auto'`, `'snacks'`, `'telescope'`, or `'basic'` |
| `claude_cmd` | string | `'claude'` | Path to the Claude Code CLI binary |
| `claude_permission_mode` | string | `nil` | Claude Code `--permission-mode` flag (`"acceptEdits"`, `"bypassPermissions"`, etc.) |
| `claude_extra_args` | list | `{}` | Extra CLI args passed to Claude Code (escape hatch for future flags) |
| `claude_allowed_tools` | list | `nil` | Tool patterns passed via `--allowedTools` (e.g. `{"Bash(bd *)", "Edit", "Read"}`) |

## Commands

| Command | Args | Description |
|---|---|---|
| `:Beadboard` | — | Open the issue list |
| `:BdSearch <term>` | required | Full-text search |
| `:BdQuery <expr>` | required | Query with expression |
| `:BdReady` | — | Show issues with ready status |
| `:BdBlocked` | — | Show blocked issues |
| `:BdStale [days]` | optional | Show stale issues (default threshold) |
| `:BdCreate` | — | Open the create wizard |
| `:BdStatus` | — | Project dashboard |
| `:BdEpicStatus` | — | Epic progress view |
| `:BdGraph [id]` | optional | Dependency graph (one issue or all) |
| `:BdActivity` | — | Activity feed |
| `:BdClaude <skill> <id>` | required | Run a Claude skill on a bead |
| `:BdQuickExplore <topic>` | required | Create bead and launch explore |
| `:BdQuickFix [feedback]` | optional | Create issues from feedback |

## Keybindings

### List View (Normal Mode)

| Key | Action |
|---|---|
| `<CR>` | Open issue detail |
| `R` | Refresh |
| `q` | Close |
| `s` | Cycle status forward |
| `S` | Pick status from menu |
| `p` | Priority up (lower number) |
| `P` | Priority down (higher number) |
| `c` | Close issue |
| `o` | Reopen issue |
| `gK` | Claim (assign to self) |
| `C` | Open create wizard |
| `dd` | Delete (with confirmation) |
| `gD` | Defer (optional "until" date) |
| `gU` | Undefer |
| `f` | Filter by dimension |
| `F` | Clear all filters |
| `gs` | Sort by field |
| `gS` | Reverse sort order |
| `/` | Text search |
| `gq` | Query expression |
| `gC` | Pick and run Claude skill on issue |
| `?` | Show help |

### List View (Visual Mode — Bulk Operations)

| Key | Action |
|---|---|
| `c` | Bulk close selected issues |
| `dd` | Bulk delete selected issues |
| `gD` | Bulk defer selected issues |
| `s` | Bulk set status |

All bulk operations prompt for confirmation.

### Detail View

| Key | Action |
|---|---|
| `q` / `<BS>` | Close |
| `R` | Refresh |
| `s` | Cycle status forward |
| `S` | Pick status from menu |
| `p` / `P` | Priority up / down |
| `c` | Close issue |
| `o` | Reopen issue |
| `gK` | Claim |
| `a` | Set assignee |
| `gl` | Add label |
| `gL` | Remove label |
| `<C-c>` | Add comment |
| `gD` | Defer |
| `gU` | Undefer |

#### Editing Fields

| Key | Action |
|---|---|
| `ed` | Edit description |
| `eD` | Edit design |
| `en` | Edit notes |
| `ea` | Edit acceptance criteria |
| `et` | Edit title |
| `eU` | Edit due date |
| `eE` | Edit estimate (minutes) |
| `eI` | Rename issue ID |

Edit commands open a scratch buffer. Write with `:w` to save,
`q` to discard.

Due dates accept: `+6h`, `+1d`, `+2w`, `tomorrow`, `YYYY-MM-DD`,
or empty to clear.

#### Dependencies & Navigation

| Key | Action |
|---|---|
| `da` | Add dependency (this depends on target) |
| `db` | Add blocking dep (this blocks target) |
| `dr` | Remove dependency |
| `dR` | Relate to issue |
| `dU` | Unrelate from issue |
| `gP` | Set parent |
| `gp` | Go to parent |
| `gc` | Show children |
| `gd` | Show dependency list |
| `gG` | Open dependency graph |
| `gx` | Mark as duplicate |
| `gX` | Supersede with another issue |
| `gW` | Promote wisp to permanent issue |
| `gC` | Pick and run Claude skill on issue |
| `gT` | Jump to active Claude session |

### Activity Feed

| Key | Action |
|---|---|
| `<CR>` | Open issue under cursor |
| `R` | Refresh |
| `a` | Toggle auto-refresh (10s interval) |
| `q` | Close |
| `?` | Show help |

### Graph View

| Key | Action |
|---|---|
| `<CR>` | Open issue under cursor |
| `R` | Refresh |
| `q` | Close |
| `?` | Show help |

### Epic Status

| Key | Action |
|---|---|
| `R` | Refresh |
| `q` | Close |

## Filtering

Press `f` in the list view to filter by any of these dimensions:

| Dimension | Input |
|---|---|
| `status` | Select from menu |
| `type` | Select from menu |
| `priority` | Select P0–P4 |
| `assignee` | Text input |
| `label` | Text input (AND logic) |
| `label-any` | Comma-separated (OR logic) |
| `created-after` | Date (YYYY-MM-DD) |
| `created-before` | Date (YYYY-MM-DD) |
| `updated-after` | Date (YYYY-MM-DD) |
| `updated-before` | Date (YYYY-MM-DD) |
| `show-all` | Toggle (includes closed) |
| `empty-description` | Toggle |

Filters compose — add multiple dimensions, press `F` to clear all.

## Sorting

Press `gs` in list view. Available fields:

`priority` · `created` · `updated` · `status` · `id` · `title` ·
`type` · `assignee`

Press `gS` to reverse the current sort order.

## Statusline

Add open/in-progress counts to your statusline:

```lua
require('beadboard').statusline()
-- Returns: "beads: 12 open, 3 wip"
```

### lualine example

```lua
require('lualine').setup({
  sections = {
    lualine_x = {
      { require('beadboard').statusline },
    },
  },
})
```

## Picker Integration

Issue pickers (set parent, add dependency, relate, mark
duplicate, supersede) use the best available fuzzy finder.

The `picker` config key controls which backend is used:

| Value | Behavior |
|---|---|
| `'auto'` (default) | snacks.nvim > telescope.nvim > `vim.ui.select` |
| `'snacks'` | Force snacks.nvim (errors if not installed) |
| `'telescope'` | Force telescope.nvim (errors if not installed) |
| `'basic'` | Always use `vim.ui.select` |

With [snacks.nvim](https://github.com/folke/snacks.nvim) and
its `ui_select = true` option enabled, even the `'basic'`
fallback renders as a modern floating picker.

## Claude Code Integration

Press `gC` from any list or detail view to pick a Claude skill
and launch an interactive session in a terminal split. Skills are
discovered dynamically from `SKILL.md` frontmatter in your Claude
configuration.

Each bead tracks its active Claude session — pressing `gC` again
focuses the existing terminal instead of spawning a duplicate.
Views auto-refresh when a session exits.

Quick-action commands for common workflows:

- `:BdQuickExplore <topic>` — creates a new bead and immediately
  launches the `explore` skill
- `:BdQuickFix [feedback]` — runs the `fix` skill to turn
  feedback into issues (prompts for input if no argument given)

## Reducing Permission Prompts

Claude Code prompts for confirmation on each tool use (file edits,
shell commands, etc.). For plugin-driven workflows where the
commands are predictable, this friction is usually unnecessary.
There are two ways to reduce it: plugin config or project settings.

### Plugin Config

Set `claude_permission_mode` in `setup()` to control how Claude
Code handles permissions for all plugin-launched sessions.

**Fully autonomous** — no prompts at all:

```lua
require('beadboard').setup({
  claude_permission_mode = 'bypassPermissions',
})
```

**Auto-accept file edits** — still prompts for shell commands:

```lua
require('beadboard').setup({
  claude_permission_mode = 'acceptEdits',
})
```

**Granular tool approval** — allow specific tools, prompt for
the rest:

```lua
require('beadboard').setup({
  claude_allowed_tools = {
    'Bash(bd *)', 'Bash(git *)', 'Edit', 'Write',
  },
})
```

Print mode (`:BdClaude print`) auto-defaults to
`bypassPermissions` when no explicit mode is configured, since
print output is non-destructive.

### Project Settings Alternative

Instead of plugin config, you can create a
`.claude/settings.local.json` in your project root. This file
is per-user (gitignored) and applies to all Claude Code
sessions in the project, not just plugin-launched ones.

```json
{
  "permissions": {
    "allow": [
      "Bash(bd *)",
      "Bash(git *)",
      "Edit",
      "Write"
    ]
  }
}
```

A shared `.claude/settings.json` (committed to the repo) can
set team-wide defaults. Use `.claude/settings.local.json` for
personal overrides.

## Highlight Groups

All groups use `default = true` — override them in your colorscheme
or config:

| Group | Default Link | Used For |
|---|---|---|
| `BeadboardPriorityCritical` | `DiagnosticError` | P0 |
| `BeadboardPriorityHigh` | `DiagnosticError` | P1 |
| `BeadboardPriorityMedium` | `DiagnosticWarn` | P2 |
| `BeadboardPriorityLow` | `DiagnosticHint` | P3 |
| `BeadboardPriorityBacklog` | `Comment` | P4 |
| `BeadboardStatusOpen` | `DiagnosticOk` | open |
| `BeadboardStatusInProgress` | `DiagnosticInfo` | in\_progress |
| `BeadboardStatusBlocked` | `DiagnosticError` | blocked |
| `BeadboardStatusDeferred` | `Comment` | deferred |
| `BeadboardStatusClosed` | `Comment` | closed |
| `BeadboardHeader` | `Title` | Section headers |
| `BeadboardId` | `Identifier` | Issue IDs |
| `BeadboardType` | `Type` | Type column |

Override example:

```lua
vim.api.nvim_set_hl(0, 'BeadboardPriorityCritical', {
  fg = '#ff0000', bold = true,
})
```

## License

MIT
