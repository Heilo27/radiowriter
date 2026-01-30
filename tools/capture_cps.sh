#!/bin/bash
#
# CPS Traffic Capture Script
# Captures XNL/XCMP traffic between CPS and MOTOTRBO radio
#

set -e

echo "========================================"
echo "  CPS Traffic Capture Tool"
echo "========================================"
echo ""

# Find the radio interface
IFACE=$(ifconfig 2>/dev/null | grep -B5 "192.168.10" | grep "^en" | cut -d: -f1 | head -1)

if [ -z "$IFACE" ]; then
    echo "ERROR: Radio not found on network."
    echo ""
    echo "Troubleshooting:"
    echo "  1. Connect the radio via USB"
    echo "  2. Wait for it to appear as a network device"
    echo "  3. Check: ifconfig | grep 192.168.10"
    echo ""
    exit 1
fi

# Verify we can reach the radio
if ! ping -c1 -t1 192.168.10.1 >/dev/null 2>&1; then
    echo "WARNING: Radio at 192.168.10.1 not responding to ping"
    echo "         (This might be normal, continuing anyway)"
    echo ""
fi

echo "Found radio on interface: $IFACE"
echo ""

# Create output filename
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILENAME="cps_capture_${TIMESTAMP}.pcap"
OUTDIR="$(dirname "$0")/../analysis/captures"

# Create captures directory if needed
mkdir -p "$OUTDIR"
FILEPATH="${OUTDIR}/${FILENAME}"

echo "Output file: $FILEPATH"
echo ""
echo "========================================"
echo "  INSTRUCTIONS"
echo "========================================"
echo ""
echo "1. Keep this terminal open"
echo "2. In Windows (VM or separate machine):"
echo "   - Open Motorola CPS"
echo "   - Connect to the radio"
echo "   - Read the codeplug"
echo "   - (Optionally) Write a test codeplug"
echo "3. Come back here and press Ctrl+C to stop"
echo ""
echo "========================================"
echo ""
echo "Starting capture on $IFACE port 8002..."
echo "Press Ctrl+C when done."
echo ""

# Run tcpdump
sudo tcpdump -i "$IFACE" -w "$FILEPATH" port 8002

echo ""
echo "========================================"
echo "  CAPTURE COMPLETE"
echo "========================================"
echo ""
echo "File saved: $FILEPATH"
echo "File size:  $(ls -lh "$FILEPATH" | awk '{print $5}')"
echo ""
echo "To analyze:"
echo "  wireshark \"$FILEPATH\""
echo ""
echo "Or share the file for analysis."
echo ""
