#!/usr/bin/env bash
set -euo pipefail

# ========================================================
# Configuration
# ========================================================

# Automatically determine the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LOCK_DIR="$SCRIPT_DIR/locks"
LOG_DIR="$SCRIPT_DIR/logs"

SHAKEMAP_SCRIPT="$SCRIPT_DIR/run_shakemap.sh"

MIN_MAGNITUDE=3.0

# ========================================================
# Initialization
# ========================================================

mkdir -p "$LOCK_DIR" "$LOG_DIR"

# ========================================================
# Arguments
# ========================================================

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 SC_EVENTID SM_EVENTID EVENT_DIR" >&2
    exit 1
fi

SC_EVENTID="$1"
SM_EVENTID="$2"
EVENT_DIR="$3"

INPUT_DIR="$EVENT_DIR/input"
EVENT_XML="$INPUT_DIR/event.xml"

LOCK_FILE="$LOCK_DIR/${SM_EVENTID}.lock"
LOG_FILE="$LOG_DIR/${SM_EVENTID}.log"

# ========================================================
# Execute ShakeMap with event-specific locking
# ========================================================

(
    flock -x 200

    echo ""
    echo "========================================================"
    echo "ShakeMap callback started"
    echo "Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "SeisComP event: $SC_EVENTID"
"callback.sh" 123L, 3315B
#!/usr/bin/env bash
set -euo pipefail

# ========================================================
# Configuration
# ========================================================

# Automatically determine the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LOCK_DIR="$SCRIPT_DIR/locks"
LOG_DIR="$SCRIPT_DIR/logs"

SHAKEMAP_SCRIPT="$SCRIPT_DIR/run_shakemap.sh"

MIN_MAGNITUDE=3.0

# ========================================================
# Initialization
# ========================================================

mkdir -p "$LOCK_DIR" "$LOG_DIR"

# ========================================================
# Arguments
# ========================================================

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 SC_EVENTID SM_EVENTID EVENT_DIR" >&2
    exit 1
fi

SC_EVENTID="$1"
SM_EVENTID="$2"
EVENT_DIR="$3"

INPUT_DIR="$EVENT_DIR/input"
EVENT_XML="$INPUT_DIR/event.xml"

LOCK_FILE="$LOCK_DIR/${SM_EVENTID}.lock"
LOG_FILE="$LOG_DIR/${SM_EVENTID}.log"

# ========================================================
# Execute ShakeMap with event-specific locking
# ========================================================

(
    flock -x 200

    echo ""
    echo "========================================================"
    echo "ShakeMap callback started"
    echo "Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "SeisComP event: $SC_EVENTID"
    echo "ShakeMap event: $SM_EVENTID"
    echo "Input directory: $INPUT_DIR"
    echo "========================================================"

    # ====================================================
    # Validate input files
    # ====================================================

    if [[ ! -f "$EVENT_XML" ]]; then
        echo "ERROR: Event XML not found: $EVENT_XML"
        exit 1
    fi

    if [[ ! -x "$SHAKEMAP_SCRIPT" ]]; then
        echo "ERROR: ShakeMap script not found or not executable:"
        echo "$SHAKEMAP_SCRIPT"
        exit 1
    fi

    # ====================================================
    # Read event magnitude
    # ====================================================

    EVENT_MAGNITUDE=$(
        python3 - "$EVENT_XML" <<'PY'
import sys
import xml.etree.ElementTree as ET

root = ET.parse(sys.argv[1]).getroot()
magnitude = root.attrib.get("mag")

if magnitude is None:
    raise ValueError("Magnitude attribute not found")

print(float(magnitude))
PY
    )

    echo "Event magnitude: $EVENT_MAGNITUDE"
    echo "Minimum magnitude: $MIN_MAGNITUDE"

    # ====================================================
    # Apply magnitude threshold
    # ====================================================

    if ! awk \
        -v mag="$EVENT_MAGNITUDE" \
        -v threshold="$MIN_MAGNITUDE" \
        'BEGIN { exit !(mag >= threshold) }'
    then
        echo "Skipping ShakeMap: M${EVENT_MAGNITUDE} < M${MIN_MAGNITUDE}"
        exit 0
    fi

    echo "Magnitude threshold satisfied."
    echo "Starting ShakeMap processing..."

    # ====================================================
    # Run ShakeMap
    # ====================================================

    "$SHAKEMAP_SCRIPT" \
        "$SM_EVENTID" \
        "$INPUT_DIR"

    echo "ShakeMap processing finished"
    echo "Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

) 200>"$LOCK_FILE" >>"$LOG_FILE" 2>&1
