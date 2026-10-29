#!/usr/bin/env bash
set -euo pipefail

# ========================================================
# Configuration
# ========================================================

# Automatically determine the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# SeisComP configuration
CONFIG_TEMPLATE="$SCRIPT_DIR/scwfparam_realtime.cfg"
CONFIG_FILE="$SCRIPT_DIR/scwfparam_realtime_runtime.cfg"

# ShakeMap output and callback
OUTPUT_DIR="$SCRIPT_DIR/scwfparam_output"
CALLBACK_SCRIPT="$SCRIPT_DIR/callback.sh"
SHAKEMAP_SCRIPT="$SCRIPT_DIR/run_shakemap.sh"

# Logging
LOG_DIR="$SCRIPT_DIR/logs"
LOG_FILE="$LOG_DIR/scwfparam_realtime.log"

# ShakeMap environment
SHAKEMAP_ENV="${SHAKEMAP_ENV:-}"
SHAKEMAP_DATA="${SHAKEMAP_DATA:-}"

# ========================================================
# Validate ShakeMap environment
# ========================================================

if [[ -z "$SHAKEMAP_ENV" ]]; then
    echo "ERROR: SHAKEMAP_ENV is not defined." >&2
    echo "Set it to your ShakeMap Conda/Micromamba environment." >&2
    echo "Example:" >&2
    echo '  export SHAKEMAP_ENV="$HOME/miniforge/envs/shakemap"' >&2
    exit 1
fi

if [[ ! -d "$SHAKEMAP_ENV" ]]; then
    echo "ERROR: ShakeMap environment not found: $SHAKEMAP_ENV" >&2
    exit 1
fi

if [[ -z "$SHAKEMAP_DATA" ]]; then
    echo "ERROR: SHAKEMAP_DATA is not defined." >&2
    echo "Set it to the data directory used by your ShakeMap installation." >&2
    echo "Example:" >&2
    echo '  export SHAKEMAP_DATA="/path/to/shakemap/data"' >&2
    exit 1
fi

if [[ ! -d "$SHAKEMAP_DATA" ]]; then
    echo "ERROR: ShakeMap data directory not found: $SHAKEMAP_DATA" >&2
    exit 1
fi

# Convert paths to absolute paths
SHAKEMAP_ENV="$(cd "$SHAKEMAP_ENV" && pwd -P)"
SHAKEMAP_DATA="$(cd "$SHAKEMAP_DATA" && pwd -P)"

# Export variables for callback.sh and run_shakemap.sh
export SHAKEMAP_ENV
export SHAKEMAP_DATA

# ========================================================
# Validate required files
# ========================================================

if [[ ! -f "$CONFIG_TEMPLATE" ]]; then
    echo "ERROR: Configuration file not found: $CONFIG_TEMPLATE" >&2
    exit 1
fi

if [[ ! -f "$CALLBACK_SCRIPT" ]]; then
    echo "ERROR: Callback script not found: $CALLBACK_SCRIPT" >&2
    exit 1
fi

if [[ ! -f "$SHAKEMAP_SCRIPT" ]]; then
    echo "ERROR: ShakeMap script not found: $SHAKEMAP_SCRIPT" >&2
    exit 1
fi

# Verify ShakeMap executables
if [[ ! -x "$SHAKEMAP_ENV/bin/python" ]]; then
    echo "ERROR: ShakeMap Python executable not found." >&2
    exit 1
fi

if [[ ! -x "$SHAKEMAP_ENV/bin/shake" ]]; then
    echo "ERROR: ShakeMap executable not found." >&2
    exit 1
fi

# ========================================================
# Initialization
# ========================================================

mkdir -p "$OUTPUT_DIR" "$LOG_DIR"

# Ensure scripts are executable
chmod +x "$CALLBACK_SCRIPT"
chmod +x "$SHAKEMAP_SCRIPT"

# ========================================================
# Generate runtime configuration
# ========================================================

# Keep the original configuration unchanged.
# Replace only the ShakeMap output and callback paths.

sed \
    -e "s|^[[:space:]]*wfparam\.output\.shakeMap\.path[[:space:]]*=.*|wfparam.output.shakeMap.path = $OUTPUT_DIR|" \
    -e "s|^[[:space:]]*wfparam\.output\.shakeMap\.script[[:space:]]*=.*|wfparam.output.shakeMap.script = $CALLBACK_SCRIPT|" \
    "$CONFIG_TEMPLATE" > "$CONFIG_FILE"

# Verify both settings exist in the generated configuration
if ! grep -Eq \
    '^wfparam\.output\.shakeMap\.path[[:space:]]*=' \
    "$CONFIG_FILE"; then
    echo "ERROR: ShakeMap output path setting not found." >&2
    exit 1
fi

if ! grep -Eq \
    '^wfparam\.output\.shakeMap\.script[[:space:]]*=' \
    "$CONFIG_FILE"; then
    echo "ERROR: ShakeMap callback setting not found." >&2
    exit 1
fi

# ========================================================
# Display configuration
# ========================================================

echo ""
echo "========================================================"
echo "SeisComP - ShakeMap real-time configuration"
echo "========================================================"

echo "Script directory: $SCRIPT_DIR"
echo "Configuration template: $CONFIG_TEMPLATE"
echo "Runtime configuration: $CONFIG_FILE"

echo ""
echo "ShakeMap environment: $SHAKEMAP_ENV"
echo "ShakeMap data directory: $SHAKEMAP_DATA"

echo ""
echo "ShakeMap output directory: $OUTPUT_DIR"
echo "Callback script: $CALLBACK_SCRIPT"
echo "ShakeMap processing script: $SHAKEMAP_SCRIPT"

echo ""
echo "Log file: $LOG_FILE"

echo ""
echo "ShakeMap settings:"
grep -E \
    '^wfparam\.output\.shakeMap\.(enable|path|script)[[:space:]]*=' \
    "$CONFIG_FILE"

echo "========================================================"

# ========================================================
# Run scwfparam
# ========================================================

echo ""
echo "Starting scwfparam..."
echo "Start time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

seiscomp exec scwfparam \
    --config-file "$CONFIG_FILE" \
    --debug 2>&1 | tee -a "$LOG_FILE"
