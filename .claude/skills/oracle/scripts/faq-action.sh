#!/bin/bash
# faq-action.sh - Execute FAQ admin actions via the API
# Usage:
#   ./faq-action.sh publish <id> "<answer>" [category]
#   ./faq-action.sh dismiss <id>
#   ./faq-action.sh delete <id>
#   ./faq-action.sh update <id> [category]
# Requires: DASHBOARD_PASSWORD environment variable

set -euo pipefail

if [[ -z "${DASHBOARD_PASSWORD:-}" ]]; then
    echo "Error: DASHBOARD_PASSWORD environment variable is not set."
    exit 1
fi

ACTION="${1:-}"
ID="${2:-}"
API="https://matrixshader.com/api/faq"
AUTH="Authorization: Bearer $DASHBOARD_PASSWORD"

if [[ -z "$ACTION" || -z "$ID" ]]; then
    echo "Usage: faq-action.sh <publish|dismiss|delete|update> <id> [answer] [category]"
    exit 1
fi

case "$ACTION" in
    publish)
        ANSWER="${3:-}"
        CATEGORY="${4:-}"
        if [[ -z "$ANSWER" ]]; then
            echo "Error: Answer is required for publish action."
            exit 1
        fi
        BODY="{\"id\":\"$ID\",\"action\":\"publish\",\"answer\":$(echo "$ANSWER" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')"
        if [[ -n "$CATEGORY" ]]; then
            BODY="${BODY%\}},\"category\":\"$CATEGORY\"}"
        else
            BODY="$BODY}"
        fi
        curl -s -X PATCH -H "$AUTH" -H "Content-Type: application/json" -d "$BODY" "$API"
        ;;
    dismiss)
        curl -s -X PATCH -H "$AUTH" -H "Content-Type: application/json" \
            -d "{\"id\":\"$ID\",\"action\":\"dismiss\"}" "$API"
        ;;
    delete)
        curl -s -X DELETE -H "$AUTH" "$API?id=$ID"
        ;;
    update)
        CATEGORY="${3:-}"
        if [[ -n "$CATEGORY" ]]; then
            curl -s -X PATCH -H "$AUTH" -H "Content-Type: application/json" \
                -d "{\"id\":\"$ID\",\"action\":\"update\",\"category\":\"$CATEGORY\"}" "$API"
        else
            echo "Error: Category required for update action."
            exit 1
        fi
        ;;
    *)
        echo "Error: Unknown action '$ACTION'. Use: publish, dismiss, delete, update"
        exit 1
        ;;
esac
