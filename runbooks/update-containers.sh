#!/bin/bash
#
# Container Update Runbook
# Updates and restarts Docker containers
#

set -e

LOG_FILE="/var/log/container-update-runbook.log"
COMPOSE_DIRS=()

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Container Update Runbook Started ==="

# Detect docker compose command (new vs old syntax)
if docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
    log "Using modern docker compose (space)"
elif command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
    log "Using legacy docker-compose (dash)"
else
    log "ERROR: Neither 'docker compose' nor 'docker-compose' found"
    echo "ERROR: Docker Compose not found"
    exit 1
fi

# Check if we have a specific list of projects to update
PROJECTS_FILE="/tmp/containers-to-update.list"

if [ -f "$PROJECTS_FILE" ] && [ -s "$PROJECTS_FILE" ]; then
    log "Found targeted update list from monitoring script"
    while IFS= read -r dir; do
        if [ -n "$dir" ] && [ -d "$dir" ]; then
            COMPOSE_DIRS+=("$dir")
            log "  • Queued for update: $dir"
        else
            log "  • Skipped (not found): $dir"
        fi
    done < "$PROJECTS_FILE"

    log "Targeted update: ${#COMPOSE_DIRS[@]} compose project(s) will be updated"

    # Clean up the file after reading
    rm -f "$PROJECTS_FILE"
else
    # Fallback: Find all docker-compose directories
    if [ -f "$PROJECTS_FILE" ]; then
        log "WARNING: Targeted update list is empty - falling back to all projects"
    else
        log "No targeted update list found - falling back to all projects"
    fi
    COMPOSE_PROJECTS=$(docker ps --format '{{.Label "com.docker.compose.project.working_dir"}}' | sort -u | grep -v '^$' || true)

    if [ -z "$COMPOSE_PROJECTS" ]; then
        log "No docker-compose projects found"
        log "Looking for docker-compose.yml files in common locations..."

        # Common locations to check
        COMMON_DIRS=(
            "/opt"
            "/home/*/docker"
            "/srv"
            "$HOME/docker"
        )

        for dir_pattern in "${COMMON_DIRS[@]}"; do
            for dir in $dir_pattern; do
                if [ -f "$dir/docker-compose.yml" ]; then
                    COMPOSE_DIRS+=("$dir")
                    log "Found docker-compose.yml in: $dir"
                fi
            done
        done
    else
        # Use directories from running containers
        while IFS= read -r dir; do
            if [ -n "$dir" ] && [ -d "$dir" ]; then
                COMPOSE_DIRS+=("$dir")
            fi
        done <<< "$COMPOSE_PROJECTS"
    fi

    log "Fallback mode: ${#COMPOSE_DIRS[@]} compose project(s) will be updated"
fi

if [ ${#COMPOSE_DIRS[@]} -eq 0 ]; then
    log "ERROR: No docker-compose projects found"
    exit 1
fi

# Update each compose project
for compose_dir in "${COMPOSE_DIRS[@]}"; do
    log "Updating project in: $compose_dir"

    cd "$compose_dir"

    # Pull latest images
    log "Pulling latest images..."
    $DOCKER_COMPOSE pull 2>&1 | tee -a "$LOG_FILE"

    # Rebuild if there are local builds
    if grep -q "build:" docker-compose.yml 2>/dev/null; then
        log "Building local images..."
        $DOCKER_COMPOSE build --pull 2>&1 | tee -a "$LOG_FILE"
    fi

    # Recreate containers
    log "Recreating containers..."
    $DOCKER_COMPOSE up -d --force-recreate 2>&1 | tee -a "$LOG_FILE"

    # Wait a bit for containers to start
    sleep 3

    # Check container health
    log "Checking container status..."
    CONTAINERS=$($DOCKER_COMPOSE ps --format json 2>/dev/null | jq -r '.Name' 2>/dev/null || $DOCKER_COMPOSE ps --services)

    if [ -n "$CONTAINERS" ]; then
        while IFS= read -r container; do
            STATUS=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
            log "  $container: $STATUS"
        done <<< "$CONTAINERS"
    fi
done

log "=== Container Update Runbook Completed ==="
log "All containers have been updated and restarted"

exit 0
