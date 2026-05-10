#!/usr/bin/env python3
"""
ESP32 Partition Calculator
Helps calculate optimal partition layout for ESP32 flash memory
"""

import argparse
import sys
from typing import List, Tuple


class Partition:
    def __init__(self, name: str, type_: str, subtype: str, offset: int, size: int):
        self.name = name
        self.type = type_
        self.subtype = subtype
        self.offset = offset
        self.size = size

    def __str__(self):
        # Format for partition CSV
        offset_str = f"0x{self.offset:X}" if self.offset > 0 else ""
        size_str = self._format_size(self.size)
        return f"{self.name:12s}, {self.type:8s}, {self.subtype:8s}, {offset_str:8s}, {size_str:8s},"

    @staticmethod
    def _format_size(size: int) -> str:
        """Format size in human-readable format"""
        if size >= 1024 * 1024:
            return f"{size // (1024 * 1024)}M"
        elif size >= 1024:
            return f"{size // 1024}K"
        else:
            return f"0x{size:X}"


def calculate_partitions(flash_size_mb: int, ota_enabled: bool, spiffs_size_mb: int) -> List[Partition]:
    """
    Calculate partition layout based on requirements

    Args:
        flash_size_mb: Total flash size in MB
        ota_enabled: Whether to enable OTA updates
        spiffs_size_mb: SPIFFS partition size in MB

    Returns:
        List of Partition objects
    """
    flash_size = flash_size_mb * 1024 * 1024
    partitions = []

    # Fixed partitions (always at same location)
    partitions.append(Partition("nvs", "data", "nvs", 0x9000, 0x6000))
    partitions.append(Partition("phy_init", "data", "phy", 0xf000, 0x1000))

    current_offset = 0x10000  # Start after nvs and phy_init

    if ota_enabled:
        # OTA requires otadata and two app partitions
        partitions.append(Partition("otadata", "data", "ota", 0xd000, 0x2000))

        # Calculate app partition size
        reserved_size = 0x10000 + spiffs_size_mb * 1024 * 1024  # bootloader + nvs + spiffs
        available_size = flash_size - reserved_size
        app_size = available_size // 2  # Split between two OTA partitions

        # Align to 64KB
        app_size = (app_size // 0x10000) * 0x10000

        partitions.append(Partition("ota_0", "app", "ota_0", current_offset, app_size))
        current_offset += app_size

        partitions.append(Partition("ota_1", "app", "ota_1", current_offset, app_size))
        current_offset += app_size
    else:
        # Single factory partition
        reserved_size = 0x10000 + spiffs_size_mb * 1024 * 1024
        app_size = flash_size - reserved_size

        # Align to 64KB
        app_size = (app_size // 0x10000) * 0x10000

        partitions.append(Partition("factory", "app", "factory", current_offset, app_size))
        current_offset += app_size

    # SPIFFS partition
    if spiffs_size_mb > 0:
        spiffs_size = spiffs_size_mb * 1024 * 1024
        partitions.append(Partition("storage", "data", "spiffs", current_offset, spiffs_size))
        current_offset += spiffs_size

    return partitions


def validate_partitions(partitions: List[Partition], flash_size_mb: int) -> Tuple[bool, str]:
    """Validate partition layout"""
    flash_size = flash_size_mb * 1024 * 1024

    # Check for overlaps
    sorted_parts = sorted(partitions, key=lambda p: p.offset)
    for i in range(len(sorted_parts) - 1):
        end = sorted_parts[i].offset + sorted_parts[i].size
        next_start = sorted_parts[i + 1].offset
        if end > next_start:
            return False, f"Overlap detected: {sorted_parts[i].name} and {sorted_parts[i + 1].name}"

    # Check total size
    total_used = max(p.offset + p.size for p in partitions)
    if total_used > flash_size:
        return False, f"Partitions exceed flash size: {total_used / (1024*1024):.2f}MB > {flash_size_mb}MB"

    # Check alignment
    for p in partitions:
        if p.offset % 0x1000 != 0:
            return False, f"Partition {p.name} not 4KB aligned: 0x{p.offset:X}"

    return True, "Valid"


def print_summary(partitions: List[Partition], flash_size_mb: int):
    """Print partition layout summary"""
    flash_size = flash_size_mb * 1024 * 1024

    print("\n" + "=" * 80)
    print(f"ESP32 Partition Layout ({flash_size_mb}MB Flash)")
    print("=" * 80)

    print("\nPartition Table (CSV Format):")
    print("-" * 80)
    print("# Name,       Type,     SubType,  Offset,   Size,     Flags")

    for p in partitions:
        print(p)

    print("-" * 80)

    # Calculate usage
    total_used = sum(p.size for p in partitions)
    total_free = flash_size - max(p.offset + p.size for p in partitions)

    print(f"\nMemory Usage:")
    print(f"  Total Flash:     {flash_size / (1024*1024):.2f} MB")
    print(f"  Used:            {total_used / (1024*1024):.2f} MB ({total_used * 100 / flash_size:.1f}%)")
    print(f"  Free:            {total_free / (1024*1024):.2f} MB ({total_free * 100 / flash_size:.1f}%)")

    print("\nPartition Details:")
    for p in sorted(partitions, key=lambda x: x.offset):
        print(f"  {p.name:12s}: 0x{p.offset:06X} - 0x{p.offset + p.size:06X}  ({p.size / 1024:6.0f} KB)")


def main():
    parser = argparse.ArgumentParser(
        description="Calculate optimal ESP32 partition layout",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # 4MB flash, no OTA, 1MB SPIFFS
  %(prog)s --flash-size 4 --spiffs-size 1

  # 8MB flash, with OTA, 2MB SPIFFS
  %(prog)s --flash-size 8 --ota --spiffs-size 2

  # 16MB flash, with OTA, 4MB SPIFFS, save to file
  %(prog)s --flash-size 16 --ota --spiffs-size 4 --output partitions.csv
        """
    )

    parser.add_argument(
        "--flash-size",
        type=int,
        required=True,
        choices=[2, 4, 8, 16],
        help="Flash size in MB (2, 4, 8, or 16)",
    )

    parser.add_argument(
        "--ota",
        action="store_true",
        help="Enable OTA updates (requires two app partitions)",
    )

    parser.add_argument(
        "--spiffs-size",
        type=int,
        default=1,
        help="SPIFFS partition size in MB (default: 1)",
    )

    parser.add_argument(
        "--output",
        type=str,
        help="Output file for partition CSV (default: print to console)",
    )

    args = parser.parse_args()

    # Validate SPIFFS size
    max_spiffs = args.flash_size - 2  # Reserve 2MB for app + system
    if args.spiffs_size > max_spiffs:
        print(f"Error: SPIFFS size too large (max {max_spiffs}MB for {args.flash_size}MB flash)")
        sys.exit(1)

    # Calculate partitions
    partitions = calculate_partitions(args.flash_size, args.ota, args.spiffs_size)

    # Validate
    valid, message = validate_partitions(partitions, args.flash_size)
    if not valid:
        print(f"Error: {message}")
        sys.exit(1)

    # Print summary
    print_summary(partitions, args.flash_size)

    # Write to file if requested
    if args.output:
        with open(args.output, "w") as f:
            f.write("# ESP32 Partition Table\n")
            f.write(f"# Flash size: {args.flash_size}MB\n")
            f.write(f"# OTA: {'Enabled' if args.ota else 'Disabled'}\n")
            f.write(f"# SPIFFS: {args.spiffs_size}MB\n")
            f.write("#\n")
            f.write("# Name,       Type,     SubType,  Offset,   Size,     Flags\n")
            for p in partitions:
                f.write(str(p) + "\n")

        print(f"\n✓ Partition table saved to: {args.output}")
        print(f"\nTo use this partition table:")
        print(f"  1. Copy {args.output} to your project root")
        print(f"  2. Add to CMakeLists.txt:")
        print(f"     set(PARTITION_CSV_FILE \"{args.output}\")")
        print(f"  3. Or configure in menuconfig:")
        print(f"     Partition Table -> Custom partition CSV file")


if __name__ == "__main__":
    main()
