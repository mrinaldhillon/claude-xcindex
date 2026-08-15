# Work plan: upstream the portable fixes to drewalth/claude-xcindex

Status: **planned, not started** — soaking the fixes in daily use first.
This doc is the executable brief for a future session (any model tier); the
draft PR carrying it tracks the work. Delete this file when the upstream
PRs are opened.

## What goes upstream (portable — upstream has the same bug or gap)

1. **Custom DerivedData resolution + WorkspacePath provenance** (from
   `d368e00`). Upstream only scans the default
   `~/Library/Developer/Xcode/DerivedData` root. Ours adds
   `IDECustomDerivedDataLocation` (absolute, and relative resolved against
   the project's own directory) and refuses any candidate container whose
   `info.plist` `WorkspacePath` doesn't match the project — provenance
   beats mtime. Files: `service/Sources/xcindex/DerivedData.swift`,
   `service/Tests/xcindexTests/DerivedDataLocatorTests.swift`,
   `hooks/session-start.sh`, `tests/hooks/test-session-start.sh`, plus the
   bash mirror in `bin/xcindex-doctor`.
2. **`/usr/bin/stat` explicit in hook + doctor** (from `2d679f3`). GNU
   coreutils `stat` earlier on PATH reads `-f` as `--file-system` and
   corrupts the freshness math.
3. **Doctor embedded-workspace exclusion** (from `a24f1b5`). Upstream's
   `session-start.sh` already excludes `*.xcodeproj/*`; their doctor still
   lacks it, so `find` traversal order can pick the auto-generated
   `project.xcworkspace` and poison the DerivedData lookup
   (`project_name` → `project`).
4. **`status` tool grant to `swift-refactor-specialist`** (from `ca871e8`),
   both namespace prefixes — without it the agent can't check freshness or
   self-resolve the store.
5. **Plugin-install tool namespace docs** — the
   `mcp__plugin_<plugin>_<server>__` prefix for marketplace installs, in
   `README.md`, `CLAUDE.md`, `docs/tools-reference.md`,
   `docs/troubleshooting.md`, `commands/xcindex-setup.md`,
   `commands/xcindex-status.md`.
6. **`bin/run`: `XCINDEX_BINARY` env override + prefer source build over
   release download** (from `d368e00`) — but NOT the download-URL swap
   (see exclusions).
7. **`.gitignore` transient-state hardening** (from `6de4bfa`) — global
   `.build/`, `.swiftpm/`, `DerivedData/`. Optional ride-along.

## What never goes upstream (fork-only)

- `plugin.json` 1.2.x version bumps, fork `CHANGELOG.md` sections.
- `marketplace.json` / `scripts/build.sh` / README `mrinal-xcindex`
  install lines.
- `bin/run` download URL pointing at the fork's releases (upstream keeps
  `drewalth/claude-xcindex`), and the fork-rationale comment above it.

## Execution recipe

1. `git fetch upstream && git switch -c <branch> upstream/main`
2. Copy the portable files wholesale from fork `main`:
   `git checkout main -- service/Sources/xcindex/DerivedData.swift
   service/Tests/xcindexTests/DerivedDataLocatorTests.swift
   hooks/session-start.sh tests/hooks/test-session-start.sh
   bin/xcindex-doctor bin/run agents/swift-refactor-specialist.md
   docs/tools-reference.md docs/troubleshooting.md
   commands/xcindex-setup.md commands/xcindex-status.md CLAUDE.md
   README.md .gitignore`
3. Strip the two fork-only lines: `bin/run` release URL back to
   `drewalth/claude-xcindex` (and drop the fork-rationale comment);
   README install line back to `xcindex@xcindex-local`.
4. Verify no branding leaks: `rg -in mrinal .` must return nothing.
5. Gates: `make test-hooks`, `make build`, `make lint`, `make test_ci`.

## Known blocker to resolve first

On a 2026-08-05 dry run of exactly this recipe, `make test-hooks`,
`make build`, and `make lint` passed, but **`make test_ci` failed: 87
tests, 33 issues**. Not diagnosed. Before blaming the mix, baseline
`make test_ci` on pristine `upstream/main` and on fork `main` — the
failures may pre-exist upstream (their CI runs on macos-26 with fixture
caches; local runs skip external fixtures via
`XCINDEX_ALLOW_FIXTURE_SKIP=1`). Only the delta vs baseline is this
plan's problem.

## Upstream PR shape

Two or three small PRs matching upstream's granularity (they
squash-merge; conventional-commit subjects feed semantic-release):

- (a) `fix:` DerivedData resolution + provenance + tests + bash mirrors
  (items 1) — the valuable one; upstream CI's fixture matrix gives the
  Swift changes real verification.
- (b) `fix:` script hardening — `/usr/bin/stat` + doctor exclusion
  (items 2–3).
- (c) `fix:`/`docs:` agent status grant + namespace docs + bin/run
  override (items 4–6).

Note for PR text: upstream's own `plugin.json` is frozen at `1.1.0`
while their tags are v3.x (semantic-release with no write-back plugin) —
don't reference fork version numbers anywhere.

## Gate to un-draft

Keep this PR draft until the fixes have soaked in daily handled-next use
(doctor discovery, custom-DerivedData resolution, freshness math) with no
regressions. Then execute the recipe and open the upstream PRs.
