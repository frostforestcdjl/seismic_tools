#!/usr/bin/env bash
set -euo pipefail

# ========================================================
# Configuration
# ========================================================

# Automatically determine the directory containing this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ShakeMap Conda/Micromamba environment
# Must be specified by the user
SHAKEMAP_ENV="${SHAKEMAP_ENV:-}"

# ShakeMap data directory
# Must match the data directory configured in ShakeMap
SHAKEMAP_DATA="${SHAKEMAP_DATA:-}"

# ========================================================
# Arguments
# ========================================================

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 EVENTID INPUT_DIR" >&2
    exit 1
fi

EVENTID="$1"
INPUT_DIR="$2"

# Validate event ID to prevent unintended filesystem paths
if [[ ! "$EVENTID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "ERROR: Invalid event ID: $EVENTID" >&2
    exit 1
fi

# ========================================================
# Validate ShakeMap environment
# ========================================================

if [[ -z "$SHAKEMAP_ENV" ]]; then
    echo "ERROR: SHAKEMAP_ENV is not defined." >&2
    echo "Set it to your ShakeMap Conda/Micromamba environment path." >&2
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

# ========================================================
# Isolate ShakeMap environment
# ========================================================

# Prevent conflicts with SeisComP Python and system Python
unset PYTHONPATH
unset PYTHONHOME

# Use ShakeMap Conda/Micromamba environment
export PATH="$SHAKEMAP_ENV/bin:$PATH"

# Configure PROJ database
export PROJ_DATA="$SHAKEMAP_ENV/share/proj"
export PROJ_LIB="$PROJ_DATA"

# Executables
PYTHON="$SHAKEMAP_ENV/bin/python"
SHAKE="$SHAKEMAP_ENV/bin/shake"

# ========================================================
# Verify executables
# ========================================================

if [[ ! -x "$PYTHON" ]]; then
    echo "ERROR: Python executable not found: $PYTHON" >&2
    exit 1
fi

if [[ ! -x "$SHAKE" ]]; then
    echo "ERROR: ShakeMap executable not found: $SHAKE" >&2
    exit 1
fi

if [[ ! -f "$PROJ_DATA/proj.db" ]]; then
    echo "ERROR: PROJ database not found: $PROJ_DATA/proj.db" >&2
    exit 1
fi

# ========================================================
# Validate input files
# ========================================================

if [[ ! -d "$INPUT_DIR" ]]; then
    echo "ERROR: Input directory not found: $INPUT_DIR" >&2
    exit 1
fi

for FILE in event.xml event_dat.xml; do

    if [[ ! -f "$INPUT_DIR/$FILE" ]]; then
        echo "ERROR: Missing input file: $INPUT_DIR/$FILE" >&2
        exit 1
    fi

done

# Convert input directory to absolute path
INPUT_DIR="$(cd "$INPUT_DIR" && pwd -P)"

# ========================================================
# Configure event directory
# ========================================================

TARGET_DIR="$SHAKEMAP_DATA/$EVENTID/current"

echo ""
echo "========================================================"
echo "ShakeMap configuration"
echo "========================================================"
echo "Script directory: $SCRIPT_DIR"
echo "ShakeMap environment: $SHAKEMAP_ENV"
echo "ShakeMap data: $SHAKEMAP_DATA"
echo "ShakeMap executable: $SHAKE"
echo "Python executable: $PYTHON"
echo "PROJ data directory: $PROJ_DATA"
echo "Event ID: $EVENTID"
echo "Input directory: $INPUT_DIR"
echo "Target directory: $TARGET_DIR"
echo "========================================================"

# ========================================================
# Prepare event directory
# ========================================================

mkdir -p "$TARGET_DIR"

cp "$INPUT_DIR/event.xml" "$TARGET_DIR/"
cp "$INPUT_DIR/event_dat.xml" "$TARGET_DIR/"

echo "Copied ShakeMap input files to: $TARGET_DIR"

# ========================================================
# Hotfix for ShakeMap event.xml
# ========================================================

"$PYTHON" - "$TARGET_DIR/event.xml" <<'PY'
import sys
import re
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

# ========================================================
# Read XML
# ========================================================

xml_file = sys.argv[1]

with open(xml_file, "r", encoding="utf-8") as f:
    xml_text = f.read()

# Parse XML
root = ET.fromstring(xml_text)

# ========================================================
# Extract event information
# ========================================================

# Get network ID
netid = root.get("netid") or "NC"

# Extract origin time
origin_time = datetime(
    year=int(root.get("year")),
    month=int(root.get("month")),
    day=int(root.get("day")),
    hour=int(root.get("hour")),
    minute=int(root.get("minute")),
    second=int(root.get("second")),
    tzinfo=timezone.utc
)

time_str = origin_time.strftime("%Y-%m-%dT%H:%M:%SZ")

# ========================================================
# Update earthquake opening tag
# ========================================================

# Preserve the original XML declaration and DOCTYPE
match = re.search(r"<earthquake\b[^>]*>", xml_text)

if match is None:
    raise ValueError("Cannot find <earthquake> element")

tag = match.group(0)

# Add or update netid
if re.search(r'\bnetid\s*=', tag):

    tag = re.sub(
        r'\bnetid\s*=\s*["\'][^"\']*["\']',
        lambda _: f'netid="{netid}"',
        tag
    )

else:

    tag = tag.replace(
        "<earthquake",
        f'<earthquake netid="{netid}"',
        1
    )

# Add or update time
if re.search(r'\btime\s*=', tag):

    tag = re.sub(
        r'\btime\s*=\s*["\'][^"\']*["\']',
        lambda _: f'time="{time_str}"',
        tag
    )

else:

    tag = tag.replace(
        "<earthquake",
        f'<earthquake time="{time_str}"',
        1
    )

# ========================================================
# Replace opening tag
# ========================================================

xml_text = (
    xml_text[:match.start()]
    + tag
    + xml_text[match.end():]
)

# ========================================================
# Save updated XML
# ========================================================

with open(xml_file, "w", encoding="utf-8") as f:
    f.write(xml_text)

print("")
print("Updated event.xml:")
print(f"  netid = {netid}")
print(f"  time  = {time_str}")
PY

# ========================================================
# Execute ShakeMap
# ========================================================

COMMENT="Automatic SeisComP processing at $(date -u +%Y-%m-%dT%H:%M:%SZ) $EVENTID"

echo ""
echo "========================================================"
echo "Starting ShakeMap processing"
echo "========================================================"
echo "Event ID: $EVENTID"
echo "Start time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "========================================================"

# Select ShakeMap configuration
echo ""
echo "[1/5] Running ShakeMap select..."
"$SHAKE" "$EVENTID" select

# Assemble event and station data
echo ""
echo "[2/5] Running ShakeMap assemble..."
"$SHAKE" -c "$COMMENT" "$EVENTID" assemble

# Compute ground-motion model
echo ""
echo "[3/5] Running ShakeMap model..."
"$SHAKE" "$EVENTID" model

# Generate contours
echo ""
echo "[4/5] Running ShakeMap contour..."
"$SHAKE" "$EVENTID" contour

# Generate maps
echo ""
echo "[5/5] Running ShakeMap mapping..."
"$SHAKE" "$EVENTID" mapping

# ========================================================
# Completed
# ========================================================

echo ""
echo "========================================================"
echo "ShakeMap completed successfully"
echo "========================================================"
echo "Event ID: $EVENTID"
echo "Completion time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "========================================================"
