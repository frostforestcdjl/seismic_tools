# Real-Time ShakeMap Generation Using SeisComP

An automated workflow for generating **USGS ShakeMap products** from earthquake events processed by **SeisComP `scwfparam`**.

The integration receives ShakeMap-compatible XML files from `scwfparam`, filters events by magnitude, and runs the ShakeMap processing sequence. **SeisComP and ShakeMap must be installed and configured separately**; this repository does not ship ShakeMap profiles or regional model configuration.

## Features

- Real-time event processing via SeisComP `scwfparam`
- Automatic ShakeMap input generation and callback execution
- Configurable event-magnitude threshold (default: **M 3.0**)
- Event-specific locking with GNU `flock`
- Separate SeisComP and event logs
- Portable paths configured using environment variables
- Runtime SeisComP configuration generated without editing the tracked template

## Repository layout

```text
seiscomp-shakemap/
├── README.md
├── .gitignore
├── callback.sh
├── run_shakemap.sh
├── scwfparam_realtime.cfg
└── turn_on_sc_shakemap.sh
```

| File | Purpose |
| --- | --- |
| `turn_on_sc_shakemap.sh` | Validates settings, creates a runtime configuration, and starts `scwfparam`. |
| `scwfparam_realtime.cfg` | SeisComP configuration template; other processing settings must be adapted to the local installation. |
| `callback.sh` | Checks event magnitude, serializes callbacks for the same event, and launches ShakeMap processing. |
| `run_shakemap.sh` | Copies event XML, applies an XML compatibility fix, and runs ShakeMap modules. |

Generated files such as `scwfparam_realtime_runtime.cfg`, `scwfparam_output/`, `logs/`, and `locks/` should be excluded from Git using `.gitignore`.

## Processing workflow

```text
SeisComP event / waveforms
          |
          v
       scwfparam
          |
          | event.xml + event_dat.xml
          v
      callback.sh
          |
          | magnitude threshold + per-event lock
          v
    run_shakemap.sh
          |
          | copy XML + update event.xml
          v
         shake
          |
          +-- select
          +-- assemble
          +-- model
          +-- contour
          +-- mapping
          |
          v
    ShakeMap products
```

## Prerequisites

- **Linux** with Bash, `sed`, `grep`, `awk`, `tee`, and GNU `flock`.
- A working **SeisComP** installation with the `scwfparam` module and access to event and waveform data.
- A separately installed and configured **USGS ShakeMap** environment containing `bin/python`, `bin/shake`, and `share/proj/proj.db`.
- A working ShakeMap data directory and regional ShakeMap configuration, including any required ground-motion models and datasets.

**Important:** The `SHAKEMAP_DATA` variable tells these scripts where to copy event files. It does **not** change the data directory that ShakeMap itself uses. Both must point to the same location.

## Installation

### 1. Clone the repository

```bash
git clone <REPOSITORY_URL>
cd seiscomp-shakemap
```

Replace `<REPOSITORY_URL>` with this repository's clone URL.

### 2. Make scripts executable

```bash
chmod +x turn_on_sc_shakemap.sh callback.sh run_shakemap.sh
```

### 3. Configure your ShakeMap paths

Set both variables **in the shell that will launch `scwfparam`**:

```bash
export SHAKEMAP_ENV="/path/to/conda/envs/shakemap"
export SHAKEMAP_DATA="/path/to/your/shakemap/data"
```

Verify the paths:

```bash
test -x "$SHAKEMAP_ENV/bin/python"
test -x "$SHAKEMAP_ENV/bin/shake"
test -f "$SHAKEMAP_ENV/share/proj/proj.db"
test -d "$SHAKEMAP_DATA"
```

The launcher exports these variables so that its child `scwfparam` process and callbacks can inherit them. For unattended service operation, arrange for the service environment to set these variables too.

### 4. Configure SeisComP

Edit `scwfparam_realtime.cfg` for your local SeisComP installation. It must enable ShakeMap output and include these settings:

```ini
wfparam.output.shakeMap.enable = true
wfparam.output.shakeMap.path = __OUTPUT_DIR__
wfparam.output.shakeMap.script = __CALLBACK_SCRIPT__
```

The launcher replaces the **values** of the `path` and `script` settings with absolute paths in a generated file, `scwfparam_realtime_runtime.cfg`. It leaves `scwfparam_realtime.cfg` unchanged. The settings must be present in the template for this replacement to work.

Other `scwfparam` settings—such as waveform input, processing parameters, and event selection—remain the responsibility of the user.

## Start real-time processing

```bash
./turn_on_sc_shakemap.sh
```

The launcher:

1. Checks `SHAKEMAP_ENV`, `SHAKEMAP_DATA`, and required files.
2. Creates output and log directories.
3. Generates `scwfparam_realtime_runtime.cfg` from the template.
4. Starts `seiscomp exec scwfparam --config-file ... --debug`.
5. Writes the console output to `logs/scwfparam_realtime.log`.

The process runs in the foreground. Stop it with **Ctrl+C**. Avoid starting multiple instances unintentionally, as they may process the same events.

## Event callback and magnitude filter

`scwfparam` invokes the callback using three arguments:

```bash
./callback.sh SC_EVENTID SM_EVENTID EVENT_DIR
```

| Argument | Meaning |
| --- | --- |
| `SC_EVENTID` | SeisComP event identifier. |
| `SM_EVENTID` | ShakeMap event identifier. |
| `EVENT_DIR` | Directory containing the generated `input/` files. |

The callback reads the magnitude from `EVENT_DIR/input/event.xml` and compares it with the `MIN_MAGNITUDE` variable in `callback.sh` (default **3.0**). Smaller events are skipped.

The callback uses a lock file in `locks/` for each ShakeMap event ID. This **serializes** concurrent callbacks for the same event but does not prevent a later callback from reprocessing that event.

## Run ShakeMap manually

To process an event without waiting for a callback:

```bash
./run_shakemap.sh EVENTID /path/to/event/input
```

The input directory must contain:

```text
input/
├── event.xml
└── event_dat.xml
```

The script copies both files to:

```text
$SHAKEMAP_DATA/EVENTID/current/
```

It then updates the opening `<earthquake>` tag in the copied `event.xml` to include `netid` and a UTC-formatted `time` attribute while preserving the rest of the XML text, including the DOCTYPE. The current implementation assumes the source year/month/day/hour/minute/second attributes represent UTC and defaults to network ID `NC` when missing.

ShakeMap modules run in this order:

```bash
shake EVENTID select
shake -c "<automatic-processing-comment>" EVENTID assemble
shake EVENTID model
shake EVENTID contour
shake EVENTID mapping
```

The script stops if a command fails. Successful execution depends on a valid independent ShakeMap configuration and usable input data.

## Logs and generated files

| Path | Description |
| --- | --- |
| `logs/scwfparam_realtime.log` | SeisComP processing output. |
| `logs/<EVENTID>.log` | Per-event callback and ShakeMap output. |
| `locks/<EVENTID>.lock` | Per-event synchronization lock. |
| `scwfparam_output/` | XML output generated by `scwfparam`. |
| `scwfparam_realtime_runtime.cfg` | Generated, machine-specific SeisComP configuration. |

Monitor logs with:

```bash
tail -f logs/scwfparam_realtime.log
tail -f logs/<EVENTID>.log
```

Recommended `.gitignore`:

```gitignore
scwfparam_realtime_runtime.cfg
logs/
locks/
scwfparam_output/
__pycache__/
*.pyc
```

> `.gitignore` does not stop tracking files already committed to Git. Remove previously tracked runtime files from Git's index if needed.

## Troubleshooting

### `SHAKEMAP_ENV is not defined` or `SHAKEMAP_DATA is not defined`

Export both variables before running the launcher:

```bash
export SHAKEMAP_ENV="/path/to/conda/envs/shakemap"
export SHAKEMAP_DATA="/path/to/shakemap/data"
```

### `ShakeMap executable not found`

Check that the executable exists in the selected environment:

```bash
ls -l "$SHAKEMAP_ENV/bin/shake"
```

### `PROJ database not found`

Check:

```bash
ls -l "$SHAKEMAP_ENV/share/proj/proj.db"
```

### Events are not triggering ShakeMap

1. Inspect `logs/scwfparam_realtime.log`.
2. Verify the runtime configuration:

   ```bash
   grep -E '^wfparam\.output\.shakeMap\.(enable|path|script)' scwfparam_realtime_runtime.cfg
   ```

3. Confirm that `scwfparam` generates `event.xml` and `event_dat.xml`.
4. Check executable permissions for `callback.sh` and `run_shakemap.sh`.
5. Confirm that the event magnitude meets the callback threshold.
6. Inspect the event-specific log under `logs/`.
7. Confirm that the callback inherits `SHAKEMAP_ENV` and `SHAKEMAP_DATA`.

### ShakeMap cannot find the event

Check the files in `$SHAKEMAP_DATA/<EVENTID>/current/` and verify that ShakeMap's own configured data directory is the same directory.

### Duplicate processing

Check for multiple `scwfparam` instances:

```bash
ps aux | grep '[s]cwfparam'
```

The per-event lock coordinates simultaneous invocations but does not implement deduplication across successive updates.

## Limitations

- Designed for Linux and GNU `flock`.
- Requires independently configured SeisComP and ShakeMap installations.
- Does not supply regional ShakeMap profiles, models, or station metadata.
- Repeated callbacks can regenerate ShakeMap products for the same event.
- XML time conversion assumes UTC source fields; network ID defaults to `NC` when absent.
- Runs in the foreground without built-in restart supervision.

## Acknowledgments

This project integrates **SeisComP** seismic monitoring software with **USGS ShakeMap** ground-motion mapping software. Credit for those systems belongs to their respective developers and contributors.

## Disclaimer

Generated products depend on waveform quality, station metadata, processing settings, regional models, and the ShakeMap configuration. Validate results independently before scientific, operational, or emergency-response use.
