#!/bin/bash
# fetch-pending.sh - Fetch all pending FAQ questions from the API
# Usage: ./fetch-pending.sh
# Requires: DASHBOARD_PASSWORD environment variable

set -euo pipefail

if [[ -z "${DASHBOARD_PASSWORD:-}" ]]; then
    echo "Error: DASHBOARD_PASSWORD environment variable is not set."
    echo "Set it with: export DASHBOARD_PASSWORD='your-password'"
    exit 1
fi

curl -s \
    -H "Authorization: Bearer $DASHBOARD_PASSWORD" \
    "https://matrixshader.com/api/faq?status=pending"
