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
ORIGINAL_SM_EVENTID="$2"
EVENT_DIR="$3"

# Use SeisComP publicID as the ShakeMap event ID
SM_EVENTID="$SC_EVENTID"

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
    echo "Original ShakeMap event: $ORIGINAL_SM_EVENTID"
    echo "ShakeMap event: $SM_EVENTID"
    echo "Input directory: $INPUT_DIR"
    echo "========================================================"

    # ====================================================
    # Validate input files and scripts
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
    # Read and validate event XML
    # ====================================================

    # Read the event ID and magnitude from event.xml
    # and verify that the XML ID matches the SeisComP ID.

    EVENT_INFO=$(
        python3 - "$EVENT_XML" "$SM_EVENTID" <<'PY'
import sys
import xml.etree.ElementTree as ET

xml_file = sys.argv[1]
expected_event_id = sys.argv[2]

root = ET.parse(xml_file).getroot()

xml_event_id = root.attrib.get("id")
magnitude = root.attrib.get("mag")

if not xml_event_id:
    raise ValueError("Event ID attribute not found in event.xml")

if xml_event_id != expected_event_id:
    raise ValueError(
        f"Event ID mismatch: XML={xml_event_id}, "
        f"ShakeMap={expected_event_id}"
    )

if magnitude is None:
    raise ValueError("Magnitude attribute not found in event.xml")

print(f"{xml_event_id} {float(magnitude)}")
PY
    )

    read -r XML_EVENTID EVENT_MAGNITUDE <<< "$EVENT_INFO"

    echo "XML event ID: $XML_EVENTID"
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
