#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: scripts/update-spec-state.sh <version> [date]" >&2
  exit 2
fi

version="$1"
updated_on="${2:-$(date +%Y-%m-%d)}"

phase="$(./scripts/release-info.sh phase "$version")"
milestone="$(./scripts/release-info.sh milestone "$version")"

cat > SPEC_STATE.md <<STATE
# Specification State

Current milestone: ${milestone}
Current state: ${phase}
Current version: ${version}
Last updated: ${updated_on}

## Milestone Targets

- v0.6 Developed
- v0.8 Stable
- v0.9 Frozen
- v0.99 Ratification-Ready
- v1.0 Ratified

## State Definitions

### Draft and Development

Assume everything is subject to change. At this stage, ideas, structures, and content are still evolving. Feedback and iteration are encouraged as nothing is final, and adjustments may be frequent.

### Developed

Assume everything is subject to change. At this stage, ideas, structures, and content are still evolving. Feedback and iteration are encouraged as nothing is final, and adjustments may be frequent.

### Stable

Changes may still occur, but they should be limited in scope. The core structure and content are mostly settled, with only refinements or necessary adjustments expected. Any modifications should be carefully considered to maintain stability.

### Frozen

Changes are highly unlikely. A high threshold will be applied, and modifications will only be made in response to critical issues. Any other proposed changes should be addressed through a follow-on extension.

### Ratification-Ready

The specification is preparing for ratification. Only critical, ratification-blocking issues should be considered for change.

### Ratified

No changes are allowed. Any necessary or desired modifications must be addressed through a follow-on extension. Ratified extensions are never revised.
STATE
