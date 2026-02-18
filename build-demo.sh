#!/bin/bash
set -e

# Build a demo site and copy it to the sites directory
# Usage: ./build-demo.sh <project-path> <demo-name>
# Example: ./build-demo.sh ../eliteautocaresa eliteautocare

PROJECT_PATH="$1"
DEMO_NAME="$2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -z "$PROJECT_PATH" ] || [ -z "$DEMO_NAME" ]; then
  echo "Usage: ./build-demo.sh <project-path> <demo-name>"
  echo "Example: ./build-demo.sh ../eliteautocaresa eliteautocare"
  exit 1
fi

# Resolve to absolute path
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"

echo "Building demo: $DEMO_NAME from $PROJECT_PATH"

# Build the static export with basePath
cd "$PROJECT_PATH"
DEMO_BASE_PATH="/$DEMO_NAME" npm run build:demo

# Copy the output to sites directory
rm -rf "$SCRIPT_DIR/sites/$DEMO_NAME"
cp -r "$PROJECT_PATH/out" "$SCRIPT_DIR/sites/$DEMO_NAME"

echo "Demo built successfully at sites/$DEMO_NAME"
echo "To test locally: cd $SCRIPT_DIR && docker build -t kasel-demos . && docker run -p 8080:80 kasel-demos"
