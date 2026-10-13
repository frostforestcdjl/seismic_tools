# Seismic Station and Channel Scanner

A collection of lightweight Python utilities for inspecting seismic waveform and station inventory files using [ObsPy](https://docs.obspy.org/).

The repository provides tools to extract unique seismic stations and their associated channels from MiniSEED waveform files and StationXML inventory files.

## Features

- Extract unique stations from MiniSEED waveform files.
- Extract unique stations from StationXML inventory files.
- List available channels for each station.
- Group stations by network and station code.
- Remove duplicate station and channel entries.
- Report the total number of traces, networks, and unique stations.
- Support command-line execution.
- Efficient metadata-only reading for MiniSEED files.

## Requirements

- Python 3.8+
- ObsPy

## Installation

Install ObsPy using pip:

```bash
pip install obspy
```

Alternatively, install it using Conda:

```bash
conda install -c conda-forge obspy
```

## Repository Structure

```text
seismic-station-scanner/
├── README.md
├── scan_mseed_st_ch.py
└── scan_inventory.py
```

## Usage

### 1. Scan MiniSEED Waveform Files

**Script:** `scan_mseed_st_ch.py`

This script extracts unique stations and their associated channels from a MiniSEED waveform file.

The script reads only waveform metadata using `headonly=True`, avoiding unnecessary loading of waveform samples.

#### Command

```bash
python scan_mseed_st_ch.py <waveform_file>
```

#### Example

```bash
python scan_mseed_st_ch.py waveforms.mseed
```

You can also specify an absolute path:

```bash
python scan_mseed_st_ch.py /path/to/waveforms.mseed
```

#### Example Output

```text
BK.BKS: HHE, HHN, HHZ
BK.BRK: HHE, HHN, HHZ
NC.GDX: HHE, HHN, HHZ
NC.KMPB: HHE, HHN, HHZ
NC.MNRC: BHE, BHN, BHZ
NC.WDC: HNE, HNN, HNZ

Total traces: 338
Total unique stations: 6
```

*Note: The output above is illustrative.*

#### How It Works

The script reads waveform metadata:

```python
st = read(args.waveform_file, headonly=True)
```

Stations are identified by their network and station codes:

```python
station_channels = defaultdict(set)

for tr in st:
    key = (tr.stats.network, tr.stats.station)
    station_channels[key].add(tr.stats.channel)
```

Using a Python `set` ensures that duplicate channels are removed.

### 2. Scan StationXML Inventory Files

**Script:** `scan_inventory.py`

This script extracts unique stations and their associated channels from a StationXML inventory file.

It uses ObsPy's `read_inventory()` function to access station metadata.

#### Command

```bash
python scan_inventory.py <inventory_file>
```

#### Example

```bash
python scan_inventory.py inventory.xml
```

You can also specify an absolute path:

```bash
python scan_inventory.py /path/to/inventory.xml
```

#### Example Output

```text
BK.BKS: HHE, HHN, HHZ
BK.BRK: HHE, HHN, HHZ
NC.GDX: HHE, HHN, HHZ
NC.KMPB: HHE, HHN, HHZ
NC.MNRC: BHE, BHN, BHZ
NC.WDC: HNE, HNN, HNZ

Total networks: 2
Total unique stations: 6
Total unique station-channel combinations: 18
```

*Note: The output above is illustrative.*

#### How It Works

The script reads the inventory:

```python
inv = read_inventory(args.inventory_file)
```

Stations and channels are grouped by network and station:

```python
station_channels = defaultdict(set)

for net in inv:
    for sta in net:
        key = (net.code, sta.code)

        station_channels[key]

        for cha in sta:
            station_channels[key].add(cha.code)
```

The script reports the number of unique networks, stations, and station-channel combinations.

## Channel Naming Convention

Seismic channel codes generally follow the SEED naming convention.

| Channel | Description |
|---------|-------------|
| HHZ | High-sample-rate broadband seismometer, vertical component |
| HHN | High-sample-rate broadband seismometer, north component |
| HHE | High-sample-rate broadband seismometer, east component |
| BHZ | Broadband seismometer, vertical component |
| BHN | Broadband seismometer, north component |
| BHE | Broadband seismometer, east component |
| HNZ | High-sample-rate accelerometer, vertical component |
| HNN | High-sample-rate accelerometer, north component |
| HNE | High-sample-rate accelerometer, east component |

The scripts list channel codes exactly as stored in the input files.

## Notes

### MiniSEED Scanner

- Stations are uniquely identified by `(network, station)`.
- Different channels belonging to the same station are grouped together.
- Duplicate channel codes are removed automatically.
- Location codes are not considered when grouping channels.
- The script does not evaluate waveform quality or data completeness.
- The total number of traces may differ from the number of unique channels.

### Inventory Scanner

- Supports FDSN StationXML inventory files.
- Stations are uniquely identified by `(network, station)`.
- Stations without channels are included in the station count.
- Duplicate station and channel entries are removed.
- Different station epochs with the same network and station codes are counted as one unique station.
- Location codes are not considered when grouping channels.
- SeisComP SC3ML files are not directly supported by ObsPy's `read_inventory()`.

## Applications

These utilities can be used for:

- Inspecting seismic waveform archives.
- Examining station inventory files.
- Verifying station and channel availability.
- Identifying broadband and strong-motion channels.
- Checking station coverage for ShakeMap processing.
- Preparing station inventories for seismic data analysis.
- Supporting seismic waveform processing workflows.

## License

Add a license appropriate for your project, such as the MIT License.
