import argparse
from collections import defaultdict
from obspy import read_inventory

def main():
    parser = argparse.ArgumentParser(
        description="List unique stations and channels in a StationXML inventory."
    )
    parser.add_argument(
        "inventory_file",
        type=str,
        help="Path to the StationXML inventory file"
    )
    args = parser.parse_args()

    inv = read_inventory(args.inventory_file)

    # Group channels by network and station
    station_channels = defaultdict(set)

    for net in inv:
        for sta in net:
            key = (net.code, sta.code)

            # Include stations even if they have no channels
            station_channels[key]

            for cha in sta:
                station_channels[key].add(cha.code)

    # Print stations and channels
    for (network, station), channels in sorted(station_channels.items()):
        print(f"{network}.{station}: {', '.join(sorted(channels))}")

    print(f"\nTotal networks: {len(set(net.code for net in inv))}")
    print(f"Total unique stations: {len(station_channels)}")
    print(f"Total unique station-channel combinations: "
          f"{sum(len(channels) for channels in station_channels.values())}")


if __name__ == "__main__":
    main()
