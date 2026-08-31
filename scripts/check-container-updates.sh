#!/bin/bash
#
# Container Update Checker (Telegram Version)
# Check running containers for available updates
#

# Load Telegram notification library
source /usr/local/lib/monitoring/telegram-notify.sh

# Detect docker compose command (new vs old syntax)
if docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
else
    DOCKER_COMPOSE="docker-compose"  # fallback
fi

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    MESSAGE="*Docker Not Running*

⚠️ Docker service is not running!

Please check the Docker service manually:
\`systemctl status docker\`"

    telegram_send_alert "critical" "Docker Not Running" "$MESSAGE"
    exit 1
fi

# Get list of running containers
CONTAINERS=$(docker ps --format "{{.ID}}|{{.Image}}|{{.Names}}" 2>/dev/null)

if [ -z "$CONTAINERS" ]; then
    MESSAGE="*No Containers Running*

No running containers found.

All services may be offline."

    telegram_send_alert "info" "No Containers Running" "$MESSAGE"
    exit 0
fi

# Arrays to track results
UPDATES_AVAILABLE=()
UP_TO_DATE=()
CHECK_FAILED=()
AFFECTED_PROJECTS=()  # Track compose project directories for containers with updates

# Check each container
while IFS='|' read -r CONTAINER_ID IMAGE_NAME CONTAINER_NAME; do
    # Get local image digest
    LOCAL_DIGEST=$(docker inspect --format='{{.Image}}' "$CONTAINER_ID" 2>/dev/null | cut -d':' -f2 | cut -c1-12)

    if [ -z "$LOCAL_DIGEST" ]; then
        CHECK_FAILED+=("$CONTAINER_NAME ($IMAGE_NAME): Failed to get local digest")
        continue
    fi

    # If IMAGE_NAME is just a hash, get original image from container config
    if [[ "$IMAGE_NAME" =~ ^[a-f0-9]{12}$ ]]; then
        CONFIG_IMAGE=$(docker inspect --format='{{.Config.Image}}' "$CONTAINER_ID" 2>/dev/null)

        if [ -n "$CONFIG_IMAGE" ] && [ "$CONFIG_IMAGE" != "<no value>" ]; then
            IMAGE_NAME="$CONFIG_IMAGE"
        else
            CHECK_FAILED+=("$CONTAINER_NAME: Cannot determine original image name")
            continue
        fi
    fi

    # Parse image name and tag
    if [[ "$IMAGE_NAME" == *":"* ]]; then
        IMAGE_TAG="${IMAGE_NAME##*:}"
        IMAGE_REPO="${IMAGE_NAME%:*}"
    else
        IMAGE_TAG="latest"
        IMAGE_REPO="$IMAGE_NAME"
    fi

    # Try to pull latest manifest
    PULL_OUTPUT=$(docker pull "$IMAGE_REPO:$IMAGE_TAG" 2>&1)

    # Check if this is a local-only image
    if echo "$PULL_OUTPUT" | grep -q "does not exist or may require 'docker login'"; then
        # Local image - check base image
        COMPOSE_WORKDIR=$(docker inspect --format='{{index .Config.Labels "com.docker.compose.project.working_dir"}}' "$CONTAINER_ID" 2>/dev/null)

        if [ -n "$COMPOSE_WORKDIR" ] && [ "$COMPOSE_WORKDIR" != "<no value>" ]; then
            DOCKERFILE_PATH=""
            if [ -f "$COMPOSE_WORKDIR/Dockerfile" ]; then
                DOCKERFILE_PATH="$COMPOSE_WORKDIR/Dockerfile"
            fi

            if [ -f "$DOCKERFILE_PATH" ]; then
                BASE_IMAGE=$(grep "^FROM" "$DOCKERFILE_PATH" | head -1 | awk '{print $2}')

                if [ -n "$BASE_IMAGE" ]; then
                    # Check base image
                    BASE_PULL_OUTPUT=$(docker pull "$BASE_IMAGE" 2>&1)

                    if ! echo "$BASE_PULL_OUTPUT" | grep -q "does not exist"; then
                        RUNNING_IMAGE_ID=$(docker inspect --format='{{.Image}}' "$CONTAINER_ID" 2>/dev/null)
                        CURRENT_BUILT=$(docker inspect --format='{{.Created}}' "$RUNNING_IMAGE_ID" 2>/dev/null | sed 's/T/ /' | cut -d'.' -f1)
                        BASE_AVAILABLE_CREATED=$(docker inspect --format='{{.Created}}' "$BASE_IMAGE" 2>/dev/null | sed 's/T/ /' | cut -d'.' -f1)

                        if [ "$CURRENT_BUILT" \< "$BASE_AVAILABLE_CREATED" ]; then
                            UPDATES_AVAILABLE+=("$CONTAINER_NAME [local build]
   Image: $IMAGE_NAME
   Base: $BASE_IMAGE
   Built: ${CURRENT_BUILT}
   Base Updated: ${BASE_AVAILABLE_CREATED}")
                            # Track the project directory for this container
                            if [ -n "$COMPOSE_WORKDIR" ] && [ "$COMPOSE_WORKDIR" != "<no value>" ]; then
                                AFFECTED_PROJECTS+=("$COMPOSE_WORKDIR")
                            fi
                        else
                            UP_TO_DATE+=("$CONTAINER_NAME ($IMAGE_NAME)")
                        fi
                        continue
                    fi
                fi
            fi
        fi
        UP_TO_DATE+=("$CONTAINER_NAME ($IMAGE_NAME) [local]")
        continue
    fi

    # Get digests
    NEW_LOCAL_DIGEST=$(docker inspect "$IMAGE_REPO:$IMAGE_TAG" 2>/dev/null | grep -m1 '"Id":' | cut -d'"' -f4 | cut -d':' -f2 | cut -c1-12)
    RUNNING_DIGEST=$(docker inspect --format='{{.Image}}' "$CONTAINER_ID" 2>/dev/null | cut -d':' -f2 | cut -c1-12)

    if [ -z "$NEW_LOCAL_DIGEST" ]; then
        CHECK_FAILED+=("$CONTAINER_NAME ($IMAGE_NAME): Failed to check registry")
        continue
    fi

    # Get metadata (include time to differentiate same-day builds)
    RUNNING_CREATED=$(docker inspect --format='{{.Created}}' "$RUNNING_DIGEST" 2>/dev/null | sed 's/T/ /' | cut -d'.' -f1)
    AVAILABLE_CREATED=$(docker inspect --format='{{.Created}}' "$NEW_LOCAL_DIGEST" 2>/dev/null | sed 's/T/ /' | cut -d'.' -f1)

    # Compare
    if [ "$RUNNING_DIGEST" != "$NEW_LOCAL_DIGEST" ]; then
        UPDATES_AVAILABLE+=("$CONTAINER_NAME
   Image: $IMAGE_NAME
   Current: ${RUNNING_CREATED}
   Available: ${AVAILABLE_CREATED}")
        # Track the project directory for this container
        COMPOSE_WORKDIR=$(docker inspect --format='{{index .Config.Labels "com.docker.compose.project.working_dir"}}' "$CONTAINER_ID" 2>/dev/null)
        if [ -n "$COMPOSE_WORKDIR" ] && [ "$COMPOSE_WORKDIR" != "<no value>" ]; then
            AFFECTED_PROJECTS+=("$COMPOSE_WORKDIR")
        fi
    else
        UP_TO_DATE+=("$CONTAINER_NAME ($IMAGE_NAME)")
    fi

done <<< "$CONTAINERS"

# Build message
UPDATE_COUNT=${#UPDATES_AVAILABLE[@]}
UP_TO_DATE_COUNT=${#UP_TO_DATE[@]}
FAILED_COUNT=${#CHECK_FAILED[@]}

# Build details
DETAILS=""

if [ $UPDATE_COUNT -gt 0 ]; then
    DETAILS="${DETAILS}*Updates Available (${UPDATE_COUNT}):*"
    for item in "${UPDATES_AVAILABLE[@]}"; do
        DETAILS="${DETAILS}
📦 ${item}
"
    done
fi

if [ $UP_TO_DATE_COUNT -gt 0 ]; then
    DETAILS="${DETAILS}
✅ *Up to Date (${UP_TO_DATE_COUNT}):*"
    for item in "${UP_TO_DATE[@]}"; do
        DETAILS="${DETAILS}
   • ${item}"
    done
fi

if [ $FAILED_COUNT -gt 0 ]; then
    DETAILS="${DETAILS}
⚠️ *Check Failed (${FAILED_COUNT}):*"
    for item in "${CHECK_FAILED[@]}"; do
        DETAILS="${DETAILS}
   • ${item}"
    done
fi

# Send notification
if [ $UPDATE_COUNT -gt 0 ]; then
    # Save list of affected project directories for the runbook to use
    PROJECTS_FILE="/tmp/containers-to-update.list"

    # Only create the file if we have project directories
    if [ ${#AFFECTED_PROJECTS[@]} -gt 0 ]; then
        # Write unique project directories to file
        printf '%s\n' "${AFFECTED_PROJECTS[@]}" | sort -u > "$PROJECTS_FILE"
    else
        # No compose projects found, create empty file as signal to update all
        > "$PROJECTS_FILE"
    fi

    MESSAGE="*Container Updates Available*

Summary:
• Updates: ${UPDATE_COUNT}
• Up to Date: ${UP_TO_DATE_COUNT}
• Failed: ${FAILED_COUNT}

${DETAILS}

Would you like to update containers?"

    telegram_send_with_buttons "$MESSAGE" \
        "🔄 Update Containers|update_containers" \
        "❌ Dismiss|dismiss"

elif [ $FAILED_COUNT -gt 0 ]; then
    MESSAGE="*Container Check Issues*

Summary:
• Updates: ${UPDATE_COUNT}
• Up to Date: ${UP_TO_DATE_COUNT}
• Failed: ${FAILED_COUNT}

${DETAILS}"

    telegram_send_alert "warning" "Container Check Issues" "$MESSAGE"

else
    MESSAGE="*All Containers Up to Date*

Summary:
• Up to Date: ${UP_TO_DATE_COUNT}

${DETAILS}"

    telegram_send_alert "success" "All Containers Up to Date" "$MESSAGE"
fi

exit 0
