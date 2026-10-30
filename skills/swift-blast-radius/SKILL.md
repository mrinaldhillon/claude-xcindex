---
name: swift-blast-radius
description: Compute what a Swift or Objective-C file affects from Xcode's index (direct dependents, one hop of callers, covering tests) before editing a shared file or starting a refactor.
---

# When to use

Trigger on phrasing like "what does this file affect", "what depends on
AuthService.swift", "what will break if I change this", "what tests cover this
code", "blast radius of NetworkClient.swift", "scope this refactor", "how big a
change is this", "is it safe to edit X". Reach for this skill BEFORE editing
any shared utility, service, manager, or model file, and BEFORE starting any
non-trivial refactor — the result tells you the minimal set of files you
actually need to read. For broader scoping that includes risks and a
recommended execution path, use swift-refactor-plan. For symbol-level (not
file-level) impact, use swift-find-references. Skip when the file is an
obvious leaf (a specific View or ViewModel with no callers) or the index is
stale.

# What this skill does

Given a file path, returns three sets:

- `directDependents` — files that directly call symbols defined in the target.
- `affectedFiles` — `directDependents` plus one hop of transitive callers.
- `coveringTests` — test files within the affected set.

This replaces "read 20 files to understand the codebase before editing." The
index already knows.

# How to use

1. Call `blast_radius` with the absolute file path.
2. Read the result and decide:
   - Refactor or signature change: read **all** of `directDependents` plus
     `coveringTests`. Skip `affectedFiles` unless you're doing something deep.
   - Behavior-preserving internal change: skim `directDependents`, run
     `coveringTests`.
3. Treat `affectedFiles` as a *risk surface*, not a reading list — it's where
   regressions might surface, not where edits happen.

# Token-saving pattern

```
BAD:  Read 20 files to "understand the codebase" before editing NetworkClient.swift
GOOD: blast_radius("NetworkClient.swift")
      → directDependents: [APIService.swift, AuthManager.swift]
      → coveringTests:    [NetworkClientTests.swift]
      Read only those 3. Save 17 file reads.
```

# Example

User: "I need to refactor `ModelData.swift`. What do I need to read first?"

1. `blast_radius(filePath: "/abs/path/ModelData.swift")`
2. Returns 5 direct dependents + 2 covering tests.
3. Read those 7 files. Refactor with confidence in the impact surface.

# When it won't help

- The unit of analysis is a *symbol*, not a file → use `swift-find-references`.
- The file is a leaf with obviously no inbound callers (e.g. a screen-specific
  View) — `blast_radius` will just confirm that, but it's not the cheapest path.
- The index is stale (the user edited but didn't build) — the MCP server will
  attach a freshness warning; respect it.

# Related skills

- **swift-refactor-plan** — when the user wants a full written plan with risks
  and a recommended next step, not just an impact list.
- **swift-find-references** — for symbol-level scoping.
- **swift-rename-symbol** — once the user has decided to act.
