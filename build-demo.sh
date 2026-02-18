#!/bin/bash
set -e

# ============================================================================
# build-demo.sh — Build and deploy a client demo site to demo.kasel.tech
#
# Usage:
#   ./build-demo.sh <project-path> <demo-name> [--deploy]
#
# Examples:
#   ./build-demo.sh ../eliteautocaresa eliteautocare           # Build only
#   ./build-demo.sh ../eliteautocaresa eliteautocare --deploy  # Build + deploy
#
# What it does:
#   1. Runs `npm run build:demo` in the client project with DEMO_BASE_PATH set
#   2. Copies the static export output to sites/<demo-name>/
#   3. With --deploy: commits, pushes, and triggers Coolify deployment
# ============================================================================

PROJECT_PATH="$1"
DEMO_NAME="$2"
DEPLOY_FLAG="$3"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

COOLIFY_API="http://178.156.247.227:8000/api/v1"
COOLIFY_TOKEN="2|HR9QiNo0u7DmFBFSKZOWcl6PLIS8i64u17MzsygHd363f540"
COOLIFY_APP_UUID="lcgssowgkc444w4k004o0cck"

# --- Validate args ---
if [ -z "$PROJECT_PATH" ] || [ -z "$DEMO_NAME" ]; then
  echo "Usage: ./build-demo.sh <project-path> <demo-name> [--deploy]"
  echo ""
  echo "Examples:"
  echo "  ./build-demo.sh ../eliteautocaresa eliteautocare"
  echo "  ./build-demo.sh ../eliteautocaresa eliteautocare --deploy"
  echo ""
  echo "Options:"
  echo "  --deploy    Commit, push, and trigger Coolify deployment"
  exit 1
fi

if [ ! -d "$PROJECT_PATH" ]; then
  echo "Error: Project path '$PROJECT_PATH' does not exist"
  exit 1
fi

# Resolve to absolute path
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"

# Check that the project has build:demo script
if ! grep -q '"build:demo"' "$PROJECT_PATH/package.json" 2>/dev/null; then
  echo "Error: $PROJECT_PATH/package.json does not have a 'build:demo' script"
  echo ""
  echo "Add demo export support to the client project first. See README.md."
  exit 1
fi

# --- Step 1: Build ---
echo ""
echo "=== Building demo: $DEMO_NAME ==="
echo "Source: $PROJECT_PATH"
echo ""

cd "$PROJECT_PATH"
DEMO_BASE_PATH="/$DEMO_NAME" NEXT_PUBLIC_BASE_PATH="/$DEMO_NAME" npm run build:demo

# --- Step 2: Copy output ---
echo ""
echo "=== Copying static export to sites/$DEMO_NAME ==="

rm -rf "$SCRIPT_DIR/sites/$DEMO_NAME"
cp -r "$PROJECT_PATH/out" "$SCRIPT_DIR/sites/$DEMO_NAME"

echo "Done. Demo files at: $SCRIPT_DIR/sites/$DEMO_NAME"

# --- Step 3: Deploy (optional) ---
if [ "$DEPLOY_FLAG" = "--deploy" ]; then
  echo ""
  echo "=== Deploying to demo.kasel.tech ==="

  cd "$SCRIPT_DIR"

  # Commit
  git add -A
  git commit -m "Update demo: $DEMO_NAME

Built from $(basename "$PROJECT_PATH") at $(date -u '+%Y-%m-%d %H:%M UTC')" || {
    echo "Nothing to commit (no changes detected)"
  }

  # Push
  git push

  # Trigger Coolify deployment
  echo "Triggering Coolify deployment..."
  RESPONSE=$(curl -sk -X POST "$COOLIFY_API/deploy" \
    -H "Authorization: Bearer $COOLIFY_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"uuid\": \"$COOLIFY_APP_UUID\"}" 2>&1)

  echo "$RESPONSE" | grep -q "deployment queued" && \
    echo "Deployment queued. Site will be live at https://demo.kasel.tech/$DEMO_NAME/ in ~30 seconds." || \
    echo "Deployment response: $RESPONSE"
else
  echo ""
  echo "=== Build complete (not deployed) ==="
  echo ""
  echo "To deploy, either:"
  echo "  1. Re-run with --deploy flag:"
  echo "     ./build-demo.sh $1 $DEMO_NAME --deploy"
  echo ""
  echo "  2. Or manually:"
  echo "     cd $SCRIPT_DIR"
  echo "     git add -A && git commit -m 'Update $DEMO_NAME' && git push"
  echo "     # Coolify auto-deploys on push, or trigger manually from dashboard"
fi

echo ""
echo "Done."
