#!/usr/bin/env bash
#
# run-tests.sh
#
# Runs the project's unit tests (the `npm test` command documented in the README,
# i.e. `ng test --watch false`) and collects the JUnit reports into `test-results/`.
#
# Behaviour:
#   - Verifies required dependencies (node, npm, installed modules, a Chrome browser)
#     are present before launching the tests.
#   - Cleans up artifacts from previous runs before starting a new one.
#   - Propagates the test runner's exit code so CI fails when tests fail.
#
# Usage: ./run-tests.sh

set -euo pipefail

# Always operate from the project root (the directory holding this script),
# so the script works no matter where it is invoked from.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# Where karma writes its JUnit report (see `junitReporter.outputDir` in karma.conf.js)
# and where we want the final reports to live.
KARMA_REPORT_DIR="reports"
TEST_RESULTS_DIR="test-results"

# --- Pretty logging helpers ---------------------------------------------------
log()  { printf '\033[1;34m[run-tests]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[run-tests]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[run-tests]\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[1;31m[run-tests]\033[0m %s\n' "$*" >&2; }

# --- 1. Verify required dependencies -----------------------------------------
log "Checking required dependencies..."

missing=0
for cmd in node npm; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    err "Required command '$cmd' is not installed or not in PATH."
    missing=1
  fi
done
if [ "$missing" -ne 0 ]; then
  err "Please install the missing dependencies and try again."
  exit 1
fi

log "node $(node -v) / npm v$(npm -v)"

# The test runner (karma) needs the installed node modules.
if [ ! -d "node_modules" ]; then
  err "Dependencies are not installed (no 'node_modules' directory)."
  err "Run 'npm ci' (or 'npm install') before launching the tests."
  exit 1
fi

# Karma launches ChromeHeadless (see karma.conf.js). Make sure a Chrome-like
# browser is available, and point karma at it via CHROME_BIN for reliability.
if [ -z "${CHROME_BIN:-}" ]; then
  for candidate in \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium" \
    "$(command -v google-chrome-stable 2>/dev/null || true)" \
    "$(command -v google-chrome 2>/dev/null || true)" \
    "$(command -v chromium 2>/dev/null || true)" \
    "$(command -v chromium-browser 2>/dev/null || true)"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      export CHROME_BIN="$candidate"
      break
    fi
  done
fi

if [ -z "${CHROME_BIN:-}" ]; then
  err "No Chrome/Chromium browser found. Karma needs ChromeHeadless to run the tests."
  err "Install Google Chrome or Chromium, or set CHROME_BIN to the browser path."
  exit 1
fi
ok "Using browser: $CHROME_BIN"

# --- 2. Clean up artifacts from previous runs --------------------------------
log "Cleaning up previous test artifacts..."
rm -rf "$TEST_RESULTS_DIR" "$KARMA_REPORT_DIR"
mkdir -p "$TEST_RESULTS_DIR"

# --- 3. Run the tests --------------------------------------------------------
log "Running tests (npm test)..."
# Don't let 'set -e' abort here: we want to capture the exit code, collect the
# reports, and exit cleanly with that same code.
test_exit_code=0
npm test || test_exit_code=$?

# --- 4. Collect the reports --------------------------------------------------
if [ -d "$KARMA_REPORT_DIR" ] && [ -n "$(ls -A "$KARMA_REPORT_DIR" 2>/dev/null)" ]; then
  mv "$KARMA_REPORT_DIR"/* "$TEST_RESULTS_DIR"/
  rmdir "$KARMA_REPORT_DIR" 2>/dev/null || true
  ok "Test reports written to '$TEST_RESULTS_DIR/'."
else
  warn "No test reports were generated in '$KARMA_REPORT_DIR/'."
fi

# --- 5. Report final status --------------------------------------------------
if [ "$test_exit_code" -eq 0 ]; then
  ok "All tests passed."
else
  err "Tests failed (exit code $test_exit_code)."
fi

exit "$test_exit_code"
