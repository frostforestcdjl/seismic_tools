import argparse
from obspy import read
from collections import defaultdict

def main():
    parser = argparse.ArgumentParser(
        description="List unique stations and their channels in a MiniSEED file."
    )
    parser.add_argument(
        "waveform_file",
        type=str,
        help="Path to the MiniSEED waveform file"
    )
    args = parser.parse_args()

    # Read waveform metadata only
    st = read(args.waveform_file, headonly=True)

    # Group channels by network and station
    station_channels = defaultdict(set)

    for tr in st:
        key = (tr.stats.network, tr.stats.station)
        station_channels[key].add(tr.stats.channel)

    # Print stations and channels
    for (network, station), channels in sorted(station_channels.items()):
        print(f"{network}.{station}: {', '.join(sorted(channels))}")

    print(f"\nTotal traces: {len(st)}")
    print(f"Total unique stations: {len(station_channels)}")


if __name__ == "__main__":
    main()
