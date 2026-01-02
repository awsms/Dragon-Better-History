#!/usr/bin/env bash
set -euo pipefail

# Rebuild script for Dragon-Better-History
#
# Outputs:
#   build/assets/application.css
#   build/assets/application.js
#
# Requires:
#   - lessc (from the "less" node package)
#   - terser
#
# Usage:
#   ./run-build.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SRC_CSS="$ROOT_DIR/src/css/history.less"
OUT_CSS="$ROOT_DIR/build/assets/application.css"

SRC_JS_DIR="$ROOT_DIR/src/js"
COMPILED_JS_DIR="$SRC_JS_DIR/compiled"
MERGE_LIST="$SRC_JS_DIR/_merge.txt"
OUT_JS="$ROOT_DIR/build/assets/application.js"

mkdir -p "$ROOT_DIR/build/assets"
mkdir -p "$COMPILED_JS_DIR"

run_terser() {
  if [[ -x "$ROOT_DIR/node_modules/.bin/terser" ]]; then
    "$ROOT_DIR/node_modules/.bin/terser" "$@"
  elif command -v terser >/dev/null 2>&1; then
    terser "$@"
  elif command -v npx >/dev/null 2>&1; then
    npx terser "$@"
  else
    echo "Error: terser not found. Install with: npm i -D terser (or npm i -g terser)" >&2
    exit 1
  fi
}

run_lessc() {
  if [[ -x "$ROOT_DIR/node_modules/.bin/lessc" ]]; then
    "$ROOT_DIR/node_modules/.bin/lessc" "$@"
  elif command -v lessc >/dev/null 2>&1; then
    lessc "$@"
  elif command -v npx >/dev/null 2>&1; then
    npx lessc "$@"
  else
    echo "Error: lessc not found. Install with: npm i -D less (or npm i -g less)" >&2
    exit 1
  fi
}

echo "==> Rebuilding Dragon-Better-History"
echo "Project root: $ROOT_DIR"

if [[ ! -f "$SRC_CSS" ]]; then
  echo "Error: missing $SRC_CSS" >&2
  exit 1
fi

echo "==> Compiling Less -> CSS"
run_lessc "$SRC_CSS" "$OUT_CSS" --clean-css="--s0 --advanced"
echo "Wrote: $OUT_CSS"

# JS (terser each file -> compiled/, then merge)
if [[ ! -f "$MERGE_LIST" ]]; then
  echo "Error: missing $MERGE_LIST" >&2
  exit 1
fi

echo "==> Compiling JavaScript -> $COMPILED_JS_DIR"

# compile every top-level src/js/*.js file (excluding compiled outputs)
mapfile -t JS_SOURCES < <(find "$SRC_JS_DIR" -maxdepth 1 -type f -name "*.js" -print | sort)

for src in "${JS_SOURCES[@]}"; do
  base="$(basename "$src")"
  out="$COMPILED_JS_DIR/${base%.js}.js"
  echo "  terser: $base -> compiled/${base%.js}.js"
  run_terser "$src" --output "$out" --comments false
done

echo "==> Merging compiled JS into: $OUT_JS"
: > "$OUT_JS"

# merge in the order listed in _merge.txt
while IFS= read -r line || [[ -n "$line" ]]; do
  # trim whitespace + strip CR (for Windows line endings)
  f="$(printf '%s' "$line" | sed -e 's/\r$//' -e 's/^[[:space:]]\+//' -e 's/[[:space:]]\+$//')"
  [[ -z "$f" ]] && continue
  [[ "$f" =~ ^# ]] && continue

  # accept entries with or without ".js"
  c1="$COMPILED_JS_DIR/$f"
  c2="$COMPILED_JS_DIR/$f.js"
  c3="$COMPILED_JS_DIR/${f%.js}.js"

  if [[ -f "$c1" ]]; then
    cat "$c1" >> "$OUT_JS"
    printf "\n" >> "$OUT_JS"
  elif [[ -f "$c2" ]]; then
    cat "$c2" >> "$OUT_JS"
    printf "\n" >> "$OUT_JS"
  elif [[ -f "$c3" ]]; then
    cat "$c3" >> "$OUT_JS"
    printf "\n" >> "$OUT_JS"
  else
    echo "Error: merge entry '$f' not found in $COMPILED_JS_DIR" >&2
    echo "Tried: $c1" >&2
    echo "       $c2" >&2
    echo "       $c3" >&2
    exit 1
  fi
done < "$MERGE_LIST"

echo "Wrote: $OUT_JS"
echo "==> Done."
