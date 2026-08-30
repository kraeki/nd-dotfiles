# Managing AI Coding Assistant Configs in Dotfiles — Best Practices

> Research note for this repo (NixOS + GNU Stow dotfiles). How to back up / version-control Claude Code, Codex, Cursor, Gemini CLI, and oh-my-claudecode configs **without** committing secrets or session churn.
>
> **Date:** 2026-08-01 · **Status:** research only, no changes made yet.

---

## ⚠️ Do this first (before any versioning)

These directories currently hold **live auth tokens**. Snapshot them somewhere *outside* the git repo before touching anything:

```bash
tar czf ~/ai-config-backup-$(date +%Y%m%d).tgz \
  ~/.claude ~/.claude.json ~/.codex ~/.cursor ~/.gemini ~/.omc
```

Then version selectively per the tables below — **allow-list** what goes in, never dump a whole dir.

---

## TL;DR — what to version, what to ignore, where the secrets are

| Tool | ✅ Version (declarative config) | 🚫 Ignore (state / churn) | 🔑 Secrets — never commit |
|------|-------------------------------|---------------------------|---------------------------|
| **Claude Code** (`~/.claude/`, `~/.claude.json`) | `settings.json`*, `CLAUDE.md`, `agents/`, `commands/`, `skills/`, `hooks/`, `output-styles/`, `statusline.sh`, `keybindings.json` | `projects/`, `sessions/`, `history.jsonl`, `todos/`, `file-history/`, `shell-snapshots/`, `session-env/`, `plugins/`, `backups/`, `statsig/`, `cache/`, `debug/`, `telemetry/`, `.last-cleanup`, `*.json.backup` | `.credentials.json`, `~/.claude.json` (OAuth + MCP state), any auth token inside `settings.json` |
| **OpenAI Codex** (`~/.codex/`) | `config.toml`, `AGENTS.md`, `prompts/` | `sessions/`, `logs/`, `history.jsonl`, `version.json`, `*.sqlite*` | `auth.json` |
| **Gemini CLI** (`~/.gemini/`) | `settings.json`, `GEMINI.md` | `history/`, `tmp/`, `installation_id` | `oauth_creds.json`, `google_accounts.json`, `.env` |
| **Cursor CLI** (`~/.cursor/`) | `cli-config.json` (non-secret prefs), project `.cursor/` rules | logs / caches | stored OAuth token file |
| **oh-my-claudecode** (`~/.omc/`) | *(nothing routine)* | entire dir — `plans/`, `state/`, `logs/`, `artifacts/`, `research/`, `sessions/` | — (runtime state only) |

\* `settings.json` is worth versioning **but** see the Stow-symlink warning below — copy it, don't symlink it, and strip any embedded token.

---

## Claude Code (`~/.claude/`, `~/.claude.json`)

### Settings model (official)
Claude Code resolves settings from a precedence chain: enterprise → CLI args → local project (`.claude/settings.local.json`) → shared project (`.claude/settings.json`) → **user** (`~/.claude/settings.json`). See the official settings docs: <https://docs.claude.com/en/docs/claude-code/settings>.

The user-level, version-worthy artifacts are the **declarative** pieces:
- `settings.json` — model, permissions, env, hooks config (strip any `apiKeyHelper`/token).
- `CLAUDE.md` — global memory/instructions (memory docs: <https://docs.claude.com/en/docs/claude-code/memory>).
- `agents/` — subagents (<https://docs.claude.com/en/docs/claude-code/sub-agents>).
- `commands/` — custom slash commands (<https://docs.claude.com/en/docs/claude-code/slash-commands>).
- `skills/` — agent skills.
- `hooks/` — hook scripts (<https://docs.claude.com/en/docs/claude-code/hooks>).
- `statusline.sh`, `output-styles/`, `keybindings.json`.

### Secrets (must never be committed)
- **`~/.claude/.credentials.json`** — OAuth credentials on Linux (mode `600`). Confirmed present in the local tree.
- **`~/.claude.json`** — large file (132 KB here) holding OAuth account info **and** MCP server config/state. Official docs attribute OAuth token storage to this file; the community and the local layout also show `.credentials.json`. **Both are sensitive — ignore both.**
- Any inline token in `settings.json`.

> ⚠️ *Community-observed vs official:* Anthropic **does not publish a full `~/.claude` directory tree**. The churn-dir names (`projects/`, `todos/`, `statsig/`, `session-env/`, `.credentials.json`) are observed from real installs, not documented. Treat the ignore-list as "safe by default," not gospel.

### State / churn — do NOT version
`projects/` (per-project session transcripts — can contain code + prompts from private repos), `sessions/`, `history.jsonl`, `todos/`, `file-history/`, `shell-snapshots/`, `session-env/` (136 entries here), `plugins/`, `backups/`, `statsig/`, `cache/`, `debug/`, `telemetry/`.

> **Contested:** versioning `projects/` for cross-machine "memory" is a real thing some people do, but it churns constantly and can leak private-repo content. **Opt-in only**, and only if you understand what's in it.

---

## OpenAI Codex CLI (`~/.codex/`)
- **Version:** `config.toml` (main config), `AGENTS.md` (project/global instructions), `prompts/` (custom prompts).
- **Secret:** `auth.json` (API key / ChatGPT OAuth). Never commit.
- **Ignore:** `sessions/`, `logs/`, `history.jsonl`, `version.json`, any `*.sqlite*`.
- Docs/repo: <https://github.com/openai/codex>.

## Google Gemini CLI (`~/.gemini/`)
- **Version:** `settings.json`, `GEMINI.md`.
- **Secrets:** `oauth_creds.json`, `google_accounts.json`, `.env`. Never commit.
- **Ignore:** `history/`, `tmp/`, `installation_id`.
- Docs/repo: <https://github.com/google-gemini/gemini-cli>.

## Cursor CLI (`~/.cursor/`)
- **Version:** `cli-config.json` (non-secret prefs) and project-level `.cursor/` rules.
- **Secret:** the stored OAuth token. *Least-documented of the four* — the exact token filename isn't clearly stated in Cursor's docs, so treat the whole credential area as sensitive and allow-list only known-safe files.
- Docs: <https://docs.cursor.com/>.

## oh-my-claudecode (`~/.omc/`)
Global runtime state for the OMC framework — `plans/`, `state/`, `logs/`, `artifacts/`, `research/`, `sessions/`. **Ignore the whole dir.** Nothing here is routinely version-worthy; the reusable OMC config lives with the framework install, not this runtime dir.

---

## Ready-to-use `.gitignore` blocks

### `~/.claude/.gitignore` (allow-list style — ignore everything, then un-ignore config)
```gitignore
# Ignore everything by default
/*

# --- Re-include declarative, version-worthy config ---
!settings.json
!CLAUDE.md
!keybindings.json
!statusline.sh
!agents/
!commands/
!skills/
!hooks/
!output-styles/

# --- Belt-and-suspenders: never commit secrets even if un-ignored above ---
.credentials.json
*.credentials.json
settings.local.json
```
> Note: `~/.claude.json` lives in `$HOME`, not `~/.claude/`, so it's covered by your top-level home `.gitignore`, not this one.

### Deny-list variant (if you'd rather list the junk explicitly)
```gitignore
projects/
sessions/
history.jsonl
todos/
file-history/
shell-snapshots/
session-env/
plugins/
backups/
statsig/
cache/
debug/
telemetry/
downloads/
paste-cache/
.last-cleanup
.session-stats.json
*.json.backup
.credentials.json
mcp-needs-auth-cache.json
```

### `~/.codex/.gitignore`
```gitignore
/*
!config.toml
!AGENTS.md
!prompts/
auth.json
```

### `~/.gemini/.gitignore`
```gitignore
/*
!settings.json
!GEMINI.md
oauth_creds.json
google_accounts.json
.env
```

---

## Stow symlink vs copy vs home-manager — recommendation for *this* setup

**Do NOT stow-symlink these directories. Copy the config files in.** Reasons:

1. **Known Claude Code symlink bug.** A symlinked `~/.claude/settings.json` causes phantom permission prompts and multi-second per-command latency; the documented workaround is to replace the symlink with a real file copy (Claude Code issue **#3575**: <https://github.com/anthropics/claude-code/issues/3575>). Confirmed for `settings.json`; unknown for `~/.claude.json`, so assume copy-everything.
2. **Atomic writes detach symlinks.** These tools rewrite config via `write-temp + rename()`. A `rename()` over a Stow symlink **replaces the symlink with a real file**, silently detaching it from the repo — your "backup" goes stale without warning.
3. **Whole-dir stow drags in junk.** Stowing `~/.claude` as a package would symlink the entire tree, pulling session transcripts, caches, and credentials into the repo path.

### Recommended approach here (NixOS + Stow)

Two clean options — pick one:

**Option A — home-manager (preferred, most declarative).**
Home-manager has a first-party **`programs.claude-code`** module. Crucially it **copies** the managed files into `~/.claude/` via an activation script rather than symlinking from the nix store, *precisely because* Claude mutates `settings.json` at runtime. That sidesteps both the read-only-store problem and issue #3575. Define `settings`, `agents`, `commands`, etc. in `home.nix`; keep tokens out of Nix (they'd land in the world-readable store) — inject via `sops-nix`/`agenix` or env vars. This fits your existing home-manager setup best.

**Option B — Stow with per-file packages + copy semantics.**
If you prefer to keep it in Stow: create narrow packages (`dotfiles/claude/.claude/settings.json`, `.../agents/`, etc.) containing **only** the allow-listed files, and either (a) accept that atomic rewrites will detach `settings.json` (so treat the repo copy as the source of truth and re-sync manually), or (b) use `make`-driven `cp` instead of `stow` for the churny files. Add the `.gitignore` above regardless.

Given you already run home-manager, **Option A is the cleaner fit** — declarative, survives rebuilds, no symlink footguns.

---

## Secrets strategy

Order of preference:

1. **Don't track them at all + use env vars.** All four tools accept credentials via environment (e.g. `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`) rather than their on-disk credential file. Cleanest: the credential files stay untracked, secrets come from your existing secret manager / env.
2. **If you must sync secrets across machines:** prefer **`sops-nix` / `sops` + `age`** over `git-crypt`. sops encrypts *values* while keeping the file structure diff-able; git-crypt stores opaque blobs. On NixOS, `sops-nix`/`agenix` integrate with home-manager to render decrypted files at activation time.
3. **Defense in depth:** add a `gitleaks` pre-commit hook, and set Claude Code `permissions.deny` for `.env` / `secrets/**` so the agent itself can't read them.

---

## Where official guidance is thin / sources conflict

- **No official full `~/.claude` tree.** Anthropic documents individual features (settings, memory, hooks, subagents) but never a canonical directory manifest — the ignore-list is community-derived.
- **`.credentials.json` vs `~/.claude.json`.** Official docs point at `~/.claude.json` for OAuth; the local layout and community also show `~/.claude/.credentials.json`. Both sensitive → ignore both.
- **Versioning `projects/`** is genuinely debated (cross-machine memory vs churn + private-code leakage). Opt-in only.
- **Cursor CLI** credential filename is under-documented; allow-list only known-safe files.
- **Symlink bug #3575** is confirmed for `settings.json`; behavior for `~/.claude.json` is untested — safe default is copy everything.

---

## Sources
- Claude Code — Settings: <https://docs.claude.com/en/docs/claude-code/settings>
- Claude Code — Memory (CLAUDE.md): <https://docs.claude.com/en/docs/claude-code/memory>
- Claude Code — Subagents: <https://docs.claude.com/en/docs/claude-code/sub-agents>
- Claude Code — Slash commands: <https://docs.claude.com/en/docs/claude-code/slash-commands>
- Claude Code — Hooks: <https://docs.claude.com/en/docs/claude-code/hooks>
- Claude Code — issue #3575 (symlinked settings.json → prompts + latency): <https://github.com/anthropics/claude-code/issues/3575>
- home-manager — `programs.claude-code` module: <https://nix-community.github.io/home-manager/options.xhtml>
- OpenAI Codex CLI: <https://github.com/openai/codex>
- Google Gemini CLI: <https://github.com/google-gemini/gemini-cli>
- Cursor docs: <https://docs.cursor.com/>
- sops-nix: <https://github.com/Mic92/sops-nix>
- agenix: <https://github.com/ryantm/agenix>
- gitleaks: <https://github.com/gitleaks/gitleaks>

---

*Research conducted via a background agent against primary sources (WebSearch); the agent could not write to disk in its sandbox, so this file was authored from its verified findings. Exact URLs for a few community-observed details (churn-dir names, Cursor token filename) are directional — verify against your live install before relying on them.*
