#!/bin/bash
#
# Docker Image Prune Runbook
# Reclaims disk space taken by Docker images left behind by repeated deploys.
#
# Policy (same one the standalone weekly docker-image-cleanup job uses):
#   • images used by any container (running OR stopped) are never touched
#   • per repository, the newest $KEEP_PER_REPO unused tags are kept
#   • surplus tags and dangling (<none>) images are removed once older than
#     $MIN_AGE_HOURS, so an in-flight deploy is not pulled out from under itself
#   • build cache older than $BUILD_CACHE_RETENTION is pruned
#
# It does NOT prune volumes or networks: named volumes on this class of host
# can hold live application state, and a blanket volume prune is unrecoverable.
#
# Environment overrides:
#   KEEP_PER_REPO          (default 3)
#   MIN_AGE_HOURS          (default 48)
#   BUILD_CACHE_RETENTION  (default 168h)
#   DRY_RUN=1              report what would be removed, delete nothing
#

set -uo pipefail

KEEP_PER_REPO="${KEEP_PER_REPO:-3}"
MIN_AGE_HOURS="${MIN_AGE_HOURS:-48}"
BUILD_CACHE_RETENTION="${BUILD_CACHE_RETENTION:-168h}"
DRY_RUN="${DRY_RUN:-0}"

LOG_FILE="/var/log/docker-prune-runbook.log"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "=== Docker Prune Runbook Started (keep=${KEEP_PER_REPO}/repo, min_age=${MIN_AGE_HOURS}h, dry_run=${DRY_RUN}) ==="

if ! command -v docker >/dev/null 2>&1; then
    log "ERROR: docker not installed"
    echo "ERROR: Docker is not installed on this host"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    log "ERROR: cannot talk to the Docker daemon"
    echo "ERROR: Cannot talk to the Docker daemon (is it running?)"
    exit 1
fi

# --- Before ---
AVAIL_BEFORE=$(df -B1 / | tail -1 | awk '{print $4}')
USED_BEFORE=$(df -h / | tail -1 | awk '{print $3}')
IMAGES_BEFORE=$(docker images -q | sort -u | wc -l)
log "Before: used=${USED_BEFORE}, images=${IMAGES_BEFORE}"

now=$(date +%s)
mincut=$(( now - MIN_AGE_HOURS * 3600 ))

# Image IDs referenced by any container, running or stopped — always protected.
USED_IDS="$(docker ps -aq | xargs -r docker inspect -f '{{.Image}}' 2>/dev/null | sort -u)"

# Rows: epoch|id|repo|tag, grouped by repo, newest first.
TMP_ROWS="$(mktemp)"
trap 'rm -f "$TMP_ROWS"' EXIT

docker images --no-trunc --format '{{.ID}}|{{.CreatedAt}}|{{.Repository}}|{{.Tag}}' \
 | while IFS='|' read -r id created repo tag; do
     epoch=$(date -d "${created:0:19}" +%s 2>/dev/null || echo 0)
     printf '%s|%s|%s|%s\n' "$epoch" "$id" "$repo" "$tag"
   done | sort -t'|' -k3,3 -k1,1nr > "$TMP_ROWS"

# Removal targets: "repo:tag" for tagged surplus, bare image ID for dangling.
TARGETS="$(awk -F'|' -v keep="$KEEP_PER_REPO" -v mincut="$mincut" -v used="$USED_IDS" '
  BEGIN { n = split(used, a, "\n"); for (i = 1; i <= n; i++) if (a[i] != "") U[a[i]] = 1 }
  {
    epoch = $1; id = $2; repo = $3; tag = $4
    inuse = (id in U)
    if (repo == "<none>" || tag == "<none>") { if (!inuse && epoch < mincut) print id; next }
    if (inuse) next                          # never touch in-use images
    cnt[repo]++
    if (cnt[repo] <= keep) next              # keep newest N unused tags per repo
    if (epoch < mincut) print repo ":" tag   # remove older surplus
  }' "$TMP_ROWS" | sort -u)"

TARGET_COUNT=0
if [ -n "$TARGETS" ]; then
    TARGET_COUNT=$(printf '%s\n' "$TARGETS" | wc -l)
fi

log "Removal targets: ${TARGET_COUNT}"
[ -n "$TARGETS" ] && printf '%s\n' "$TARGETS" >> "$LOG_FILE"

if [ "$DRY_RUN" = "1" ]; then
    echo "=== DOCKER PRUNE PREVIEW (dry run) ==="
    echo ""
    echo "Policy: keep newest ${KEEP_PER_REPO} unused tags per repo, older than ${MIN_AGE_HOURS}h"
    echo "Images now: ${IMAGES_BEFORE}"
    echo "Would remove: ${TARGET_COUNT}"
    echo ""
    if [ "$TARGET_COUNT" -gt 0 ]; then
        printf '%s\n' "$TARGETS" | head -25
        [ "$TARGET_COUNT" -gt 25 ] && echo "... and $((TARGET_COUNT - 25)) more"
    else
        echo "Nothing to remove."
    fi
    log "=== Docker Prune Runbook Completed (dry run) ==="
    exit 0
fi

if [ "$TARGET_COUNT" -gt 0 ]; then
    log "Removing images..."
    printf '%s\n' "$TARGETS" | xargs -r docker rmi >> "$LOG_FILE" 2>&1 || true
else
    log "No images to remove"
fi

log "Pruning build cache older than ${BUILD_CACHE_RETENTION}..."
docker builder prune --force --filter "until=${BUILD_CACHE_RETENTION}" >> "$LOG_FILE" 2>&1 || true

# --- After ---
AVAIL_AFTER=$(df -B1 / | tail -1 | awk '{print $4}')
USED_AFTER=$(df -h / | tail -1 | awk '{print $3}')
USAGE_PERCENT=$(df -h / | tail -1 | awk '{print $5}')
IMAGES_AFTER=$(docker images -q | sort -u | wc -l)

FREED_BYTES=$(( AVAIL_AFTER - AVAIL_BEFORE ))
[ "$FREED_BYTES" -lt 0 ] && FREED_BYTES=0
FREED=$(numfmt --to=iec --suffix=B "$FREED_BYTES" 2>/dev/null || echo "${FREED_BYTES}B")

log "After: used=${USED_AFTER} (${USAGE_PERCENT}), images=${IMAGES_AFTER}, freed=${FREED}"

echo "=== DOCKER PRUNE COMPLETE ==="
echo ""
echo "Images removed: $(( IMAGES_BEFORE - IMAGES_AFTER )) (${IMAGES_BEFORE} -> ${IMAGES_AFTER})"
echo "Freed: ${FREED}"
echo "Disk used: ${USED_BEFORE} -> ${USED_AFTER}"
echo "Current usage: ${USAGE_PERCENT}"
echo ""
echo "Kept newest ${KEEP_PER_REPO} unused tags per repo; in-use images and volumes untouched."

log "=== Docker Prune Runbook Completed ==="

exit 0
