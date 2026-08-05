#!/usr/bin/env bash
# Write a release version into .claude-plugin/plugin.json.
#
# Claude Code caches an installed plugin under a directory named for the
# `version` field of .claude-plugin/plugin.json, and `claude plugin update`
# re-copies the marketplace clone only when that field advertises something
# newer. The field is the plugin's cache key, not decoration.
#
# It used to be hand-maintained, and it drifted: upstream tags v3.0.0 and
# v3.0.2 both shipped a manifest reading 1.1.0, and this fork sat at 1.2.3
# with a newest release of v1.2.1. The failure that exposed it: a merged fix
# plus a published release still left every installed copy running the old
# binary, because the advertised version never moved and so `plugin update`
# was a permanent no-op. semantic-release now calls this from its `prepare`
# step, so the manifest always matches the tag being cut.
#
# Usage: scripts/set-plugin-version.sh <version>

set -euo pipefail

version="${1:-}"
[[ -n "$version" ]] || {
    echo "usage: ${0##*/} <version>" >&2
    exit 2
}

# Reject anything that is not semver. A malformed value would be baked into the
# manifest and break resolution at install time, where the error surfaces far
# from its cause.
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)*$ ]] || {
    echo "error: '${version}' is not a valid semver version" >&2
    exit 2
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="${REPO_ROOT}/.claude-plugin/plugin.json"
[[ -f "$manifest" ]] || {
    echo "error: ${manifest} not found" >&2
    exit 1
}

# node rather than jq or sed: the release job already guarantees it via
# actions/setup-node, it parses the manifest instead of pattern-matching it,
# and JSON.stringify preserves key order so the diff stays one line.
#
# The monotonicity check is the load-bearing part. Because the version is a
# cache key rather than a label, moving it *down* is not cosmetic: every install
# already sitting on the higher value stops seeing updates entirely, silently
# and permanently. That is not hypothetical -- release v1.2.2 rewrote a manifest
# that read 1.2.3, because semantic-release baselines on the tags the release
# runner can see and the higher tags existed only in a contributor's local
# clone. Refusing the write turns that class of mistake into a failed release,
# which is loud, instead of a dead update path, which is silent.
#
# shellcheck disable=SC2016  # the ${...} below are JS template literals; the
# single quotes keeping the shell out of them are deliberate.
node -e '
const fs = require("fs");
const [manifest, next] = process.argv.slice(1);
const json = JSON.parse(fs.readFileSync(manifest, "utf8"));
const current = json.version;

// Compare release cores only. Prerelease ordering is irrelevant here: this
// project ships from one channel, and the guard only needs to catch a genuine
// backwards step.
const core = (v) => String(v).split(/[-+]/)[0].split(".").map(Number);
const compare = (a, b) => {
  const [x, y] = [core(a), core(b)];
  for (let i = 0; i < 3; i += 1) {
    if (x[i] !== y[i]) return x[i] < y[i] ? -1 : 1;
  }
  return 0;
};

if (current && compare(next, current) < 0) {
  console.error(
    `error: refusing to move plugin.json version backwards (${current} -> ${next}).`
  );
  console.error(
    "The version is the plugin install cache key: any install already on " +
    `${current} would never see an update again. Check that the release tag ` +
    "train is ahead of the manifest before retrying."
  );
  process.exit(1);
}

json.version = next;
fs.writeFileSync(manifest, JSON.stringify(json, null, 2) + "\n");
' "$manifest" "$version"

echo "plugin.json version -> ${version}"
