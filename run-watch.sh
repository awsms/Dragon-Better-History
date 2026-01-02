#!/usr/bin/env bash
set -euo pipefail

# Watch + rebuild script for Dragon-Better-History
#
# Rebuilds only when source inputs change (fast fingerprint: mtime+size):
#   - src/css/*.less
#   - src/js/*.js
#   - src/js/_merge.txt
#
# Uses inotify to wake up quickly
#
# Optional:
#   WATCH_CMD="..." ./run-watch.sh
#
# Requires (recommended):
#   - inotifywait (package: inotify-tools)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_SCRIPT="$ROOT_DIR/run-build.sh"

WATCH_CMD="${WATCH_CMD:-}"
DEBOUNCE_MS="${DEBOUNCE_MS:-120}"
POLL_INTERVAL="${POLL_INTERVAL:-1}"

WATCH_DIRS=(
  "$ROOT_DIR/src/css"
  "$ROOT_DIR/src/js"
)

list_inputs() {
  (
    cd "$ROOT_DIR"
    find src \
      -type f \
      \( -path 'src/css/*.less' -o -path 'src/js/*.js' -o -path 'src/js/_merge.txt' \) \
      ! -path 'src/js/compiled/*' \
      -print0 \
    | sort -z
  )
}

# stat lines only (name|size|mtime)
fingerprint_inputs() {
  (
    cd "$ROOT_DIR"
    list_inputs \
    | xargs -0 stat -c '%n|%s|%Y' 2>/dev/null \
    | sha256sum \
    | awk '{print $1}'
  )
}

should_ignore_event_path() {
  local p="$1"

  case "$p" in
    *"/.git/"*|*"/build/"*|*"/node_modules/"*|*"/compiled/"*)
      return 0
      ;;
  esac

  local b
  b="$(basename "$p")"
  case "$b" in
    *"~"|*.swp|*.swo|*.swx|*.tmp|*.temp|*.bak|*.orig|*.rej|*.part)
      return 0
      ;;
    *"#"*|*.kate-swp|*.goutputstream-*|.nfs*)
      return 0
      ;;
  esac
  return 1
}

run_build() {
  echo
  echo "==> $(date '+%H:%M:%S') rebuilding..."
  if "$BUILD_SCRIPT"; then
    if [[ -n "$WATCH_CMD" ]]; then
      echo "==> Running WATCH_CMD: $WATCH_CMD"
      bash -lc "$WATCH_CMD" || true
    fi
    echo "==> Watching..."
  else
    echo "==> Build failed (watch continues)."
  fi
}

msleep() {
  local ms="$1"
  python3 - <<'PY' "$ms" 2>/dev/null || sleep 0.12
import sys, time
time.sleep(int(sys.argv[1]) / 1000.0)
PY
}

initial_sanity() {
  [[ -x "$BUILD_SCRIPT" ]] || {
    echo "Error: $BUILD_SCRIPT not found or not executable (chmod +x run-build.sh)" >&2
    exit 1
  }
  [[ -d "$ROOT_DIR/src" ]] || {
    echo "Error: missing src directory: $ROOT_DIR/src" >&2
    exit 1
  }
}

watch_inotify() {
  echo "==> Using inotifywait (inotify-tools)"
  echo "==> Watching: ${WATCH_DIRS[*]}"
  echo "==> Debounce: ${DEBOUNCE_MS}ms"
  echo "==> Watching... (Ctrl+C to stop)"

  local last_fp
  last_fp="$(fingerprint_inputs || true)"

  inotifywait -m -r \
    -e close_write,moved_to,create,delete \
    --format '%e %w%f' \
    "${WATCH_DIRS[@]}" | while IFS= read -r line; do
      path="${line#* }"

      if should_ignore_event_path "$path"; then
        continue
      fi

      msleep "$DEBOUNCE_MS"

      local now_fp
      now_fp="$(fingerprint_inputs || true)"

      if [[ "$now_fp" != "$last_fp" ]]; then
        last_fp="$now_fp"
        echo "   change confirmed"
        run_build
      fi
    done
}

watch_poll() {
  echo "==> inotifywait not found; using polling fallback"
  echo "==> Install for best experience: sudo pacman -S inotify-tools"
  echo "==> Poll interval: ${POLL_INTERVAL}s"
  echo "==> Watching... (Ctrl+C to stop)"

  local last
  last="$(fingerprint_inputs || true)"
  while true; do
    sleep "$POLL_INTERVAL"
    local now
    now="$(fingerprint_inputs || true)"
    if [[ "$now" != "$last" ]]; then
      last="$now"
      run_build
    fi
  done
}

main() {
  initial_sanity
  echo "==> Project root: $ROOT_DIR"
  run_build

  if command -v inotifywait >/dev/null 2>&1; then
    watch_inotify
  else
    watch_poll
  fi
}

main "$@"
