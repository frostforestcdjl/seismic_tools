MiniSEED Station and Channel List

A lightweight Python utility to list unique seismic stations and their associated channels from a MiniSEED (.mseed) waveform file using ObsPy.

The script reads only waveform metadata, making it efficient for inspecting large MiniSEED files without loading waveform samples into memory.

Features

* Extract unique seismic stations from MiniSEED files.
* List available channels for each station.
* Group stations by network and station code.
* Remove duplicate channel entries.
* Report the total number of traces and unique stations.
* Support command-line execution.
* Efficient metadata-only reading using ObsPy.

Requirements

* Python 3.8+
* ObsPy

Installation

Install ObsPy using pip:

pip install obspy

Alternatively, install it using Conda:

conda install -c conda-forge obspy

No additional dependencies are required beyond ObsPy and the Python standard library.

Usage

Run the script from the command line:

python list_mseed_stations.py <waveform_file>

Example

python list_mseed_stations.py waveforms.mseed

You can also specify an absolute path:

python list_mseed_stations.py /path/to/waveforms.mseed

Example Output

BK.BKS: HHE, HHN, HHZ
BK.BRK: HHE, HHN, HHZ
NC.GDX: HHE, HHN, HHZ
NC.KMPB: HHE, HHN, HHZ
NC.MNRC: BHE, BHN, BHZ
NC.WDC: HNE, HNN, HNZ
Total traces: 338
Total unique stations: 6

Note: The output above is illustrative.

How It Works

1. Read MiniSEED Metadata

The script uses ObsPy to read waveform metadata:

st = read(args.waveform_file, headonly=True)

Setting headonly=True avoids loading waveform sample data, reducing memory usage when processing large files.

2. Group Channels by Station

Stations are identified using their network and station codes:

station_channels = defaultdict(set)
for tr in st:
    key = (tr.stats.network, tr.stats.station)
    station_channels[key].add(tr.stats.channel)

A Python set ensures that duplicate channels are counted only once per station.

3. Print Results

Stations and channels are sorted alphabetically:

for (network, station), channels in sorted(station_channels.items()):
    print(f"{network}.{station}: {', '.join(sorted(channels))}")

The script also reports:

* Total traces: Number of waveform traces returned by ObsPy.
* Total unique stations: Number of distinct network-station combinations.

Channel Naming Convention

Seismic channel codes generally follow the SEED naming convention.

Channel	Description
HHZ	High-sample-rate broadband seismometer, vertical component
HHN	High-sample-rate broadband seismometer, north component
HHE	High-sample-rate broadband seismometer, east component
BHZ	Broadband seismometer, vertical component
BHN	Broadband seismometer, north component
BHE	Broadband seismometer, east component
HNZ	High-sample-rate accelerometer, vertical component
HNN	High-sample-rate accelerometer, north component
HNE	High-sample-rate accelerometer, east component

The script lists channel codes exactly as stored in the MiniSEED file.

Notes

* Stations are uniquely identified by (network, station).
* Different channels belonging to the same station are grouped together.
* Duplicate channel codes are removed automatically.
* Location codes are not considered when grouping channels.
* The script does not evaluate waveform quality, instrument response, or data completeness.
* The reported trace count may differ from the number of physical waveform records or continuous waveform segments.

Applications

This utility can be used for:

* Inspecting seismic waveform archives.
* Verifying station availability before waveform processing.
* Identifying broadband and strong-motion channels.
* Checking station coverage for ShakeMap processing.
* Preparing station inventories for seismic data analysis.

License

Add a license appropriate for your project, such as the MIT License.
