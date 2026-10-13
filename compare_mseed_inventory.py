import argparse
from obspy import read, read_inventory


def get_mseed_stations(mseed_file):
    """Extract unique (network, station) pairs from MiniSEED."""
    st = read(mseed_file, headonly=True)

    stations = {
        (tr.stats.network, tr.stats.station)
        for tr in st
    }

    return stations


def get_inventory_stations(inventory_file):
    """Extract unique (network, station) pairs from StationXML."""
    inv = read_inventory(inventory_file)

    stations = {
        (net.code, sta.code)
        for net in inv
        for sta in net
    }

    return stations


def print_stations(title, stations):
    """Print a sorted list of stations."""
    print(f"\n{'=' * 60}")
    print(f"{title} ({len(stations)})")
    print(f"{'=' * 60}")

    if not stations:
        print("None")
        return

    for network, station in sorted(stations):
        print(f"{network}.{station}")


def main():
    parser = argparse.ArgumentParser(
        description="Compare stations between MiniSEED and StationXML files."
    )

    parser.add_argument(
        "mseed_file",
        type=str,
        help="Path to the MiniSEED waveform file"
    )

    parser.add_argument(
        "inventory_file",
        type=str,
        help="Path to the StationXML inventory file"
    )

    args = parser.parse_args()

    # Load station lists
    mseed_stations = get_mseed_stations(args.mseed_file)
    inventory_stations = get_inventory_stations(args.inventory_file)

    # Compare stations
    common_stations = mseed_stations & inventory_stations

    mseed_only = mseed_stations - inventory_stations

    inventory_only = inventory_stations - mseed_stations

    # Print summary
    print("\nStation Comparison Summary")
    print("=" * 60)

    print(f"MiniSEED stations:       {len(mseed_stations)}")
    print(f"Inventory stations:      {len(inventory_stations)}")
    print(f"Common stations:         {len(common_stations)}")
    print(f"MiniSEED only:           {len(mseed_only)}")
    print(f"Inventory only:          {len(inventory_only)}")

    # Print station lists
    print_stations("Common Stations", common_stations)

    print_stations("Stations Only in MiniSEED", mseed_only)

    print_stations("Stations Only in Inventory", inventory_only)


if __name__ == "__main__":
    main()
