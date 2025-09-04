#!/usr/bin/env bash
# Usage: ./create_issues.sh owner/repo [issues.json] [--force]
# Requires: gh, jq
set -euo pipefail

REPO="${1:-}"
JSON_PATH="${2:-issues_nonqa.json}"
FORCE="0"

# Parse optional flags (any position after REPO/JSON)
for arg in "$@"; do
  [ "$arg" = "--force" ] && FORCE="1"
done

if [ -z "$REPO" ]; then
  echo "Usage: $0 owner/repo [issues.json] [--force]"
  exit 1
fi

for bin in gh jq; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Error: $bin not found."
    exit 1
  fi
done

if ! gh auth status >/dev/null 2>&1; then
  echo "You must authenticate first: gh auth login"
  exit 1
fi

if [ ! -f "$JSON_PATH" ]; then
  echo "$JSON_PATH not found in current directory."
  exit 1
fi

echo "Repo: $REPO"
echo "JSON: $JSON_PATH"
echo "Force update labels: $([ "$FORCE" = "1" ] && echo yes || echo no)"
echo

# --- 1) Fetch current labels via REST API (exact names)
# This avoids ambiguous grep matches and works across gh versions.
EXISTING_LABELS="$(
  gh api -H "Accept: application/vnd.github+json" \
    "/repos/${REPO}/labels" --paginate -q '.[].name'
)"
# helper: returns 0 if label exists (exact match)
label_exists() {
  local name="$1"
  # Use grep -Fx for exact full-line match; avoid regex pitfalls with ':'
  echo "$EXISTING_LABELS" | grep -Fxq "$name"
}

DEFAULT_COLOR="ededed"

# --- 2) Ensure labels from JSON exist (and update when --force)
echo "Ensuring labels exist..."
ALL_LABELS_SORTED="$(jq -r '.[] | .labels[]?' "$JSON_PATH" | sort -u)"

# Iterate lines safely (no mapfile, no pipelines that spawn subshells)
while IFS= read -r L; do
  [ -z "${L:-}" ] && continue

  if label_exists "$L"; then
    if [ "$FORCE" = "1" ]; then
      # Edit color & description recursively when --force
      gh label edit "$L" -R "$REPO" --color "$DEFAULT_COLOR" --description "$L" >/dev/null || true
      echo "Updated label (force): $L"
    else
      echo "Label exists: $L"
    fi
  else
    # Create new label; if a race occurs and it already exists, ignore the error
    if gh label create "$L" -R "$REPO" --color "$DEFAULT_COLOR" --description "$L" >/dev/null 2>&1; then
      echo "Created label: $L"
      # Keep local cache in sync so later checks see it as existing
      EXISTING_LABELS="$(printf "%s\n%s" "$EXISTING_LABELS" "$L")"
    else
      # If creation failed due to existing, just log and continue
      echo "Label reportedly exists now: $L"
    fi
  fi
done <<EOF
$ALL_LABELS_SORTED
EOF

# --- 3) Create issues
COUNT="$(jq 'length' "$JSON_PATH")"
echo "Creating $COUNT issues in $REPO ..."
i=0
while [ "$i" -lt "$COUNT" ]; do
  TITLE="$(jq -r ".[$i].title" "$JSON_PATH")"
  BODY="$(jq -r ".[$i].body" "$JSON_PATH")"

  echo "-> Creating: $TITLE"

  # Build args with repeated --label (robust for older/newer gh)
  # shellcheck disable=SC2206
  ARGS=(-R "$REPO" --title "$TITLE" --body "$BODY")

  LABELS_BLOCK="$(jq -r ".[$i].labels[]?" "$JSON_PATH")"
  while IFS= read -r L; do
    [ -z "${L:-}" ] && continue
    ARGS+=(--label "$L")
  done <<EOF
$LABELS_BLOCK
EOF

  # Create issue; if something fails, print context
  if ! gh issue create "${ARGS[@]}" >/dev/null 2>&1; then
    echo "ERROR: failed to create issue: $TITLE"
    echo "       Try running with: gh issue create ${ARGS[*]}"
    exit 1
  fi

  i=$(( i + 1 ))
done

echo "Done."
