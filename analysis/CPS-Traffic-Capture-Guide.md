# CPS Traffic Capture Guide

**Goal:** Capture the communication between official Motorola CPS software and the XPR 3500e radio to understand the initialization sequence required for codeplug access.

---

## What We Need to Discover

The radio returns error `0x03` (reInitXNL) when we try PSDT operations. We need to capture:

1. **XNL Authentication** - What device type does CPS use? (We use 0x0A)
2. **Post-Auth Initialization** - What commands does CPS send after authentication?
3. **PSDT Unlock Sequence** - What enables codeplug access?
4. **Session Management** - How does CPS start a programming session?

---

## Option A: Network Capture (Easiest)

The XPR 3500e appears as a CDC ECM network device at 192.168.10.1. We can capture TCP traffic on port 8002.

### macOS Setup

```bash
# 1. Find the network interface for the radio
ifconfig | grep -A5 "192.168.10"

# Look for interface like en5, en6, etc.
# Example output:
# en6: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST>
#      inet 192.168.10.2 netmask 0xffffff00 broadcast 192.168.10.255
```

### Capture with tcpdump

```bash
# Replace en6 with your actual interface
sudo tcpdump -i en6 -w cps_capture.pcap port 8002

# Or capture all traffic to/from radio
sudo tcpdump -i en6 -w cps_capture.pcap host 192.168.10.1
```

### Capture with Wireshark

1. Open Wireshark
2. Select the CDC ECM interface (en5, en6, etc.)
3. Apply capture filter: `port 8002`
4. Start capture
5. Run CPS and perform operations
6. Stop capture and save

---

## Option B: Windows VM with CPS

Since official CPS runs on Windows:

### Setup

1. **Windows VM** (Parallels, VMware, or VirtualBox)
2. **USB Passthrough** - Pass the radio's USB device to the VM
3. **Wireshark for Windows** - Install in the VM
4. **Motorola CPS** - Install the official software

### Capture Steps

1. Connect radio to Mac
2. Pass USB device to Windows VM
3. In VM, open Wireshark
4. Select the network adapter for the radio (usually shows as "Ethernet" or "Local Area Connection")
5. Start capture with filter: `port 8002`
6. Open CPS and connect to radio
7. Perform: Read codeplug, Write codeplug
8. Stop capture

### Export Capture

Save as `.pcap` and copy to Mac for analysis.

---

## Option C: USB Raw Capture (Most Detailed)

Captures all USB traffic including control transfers.

### macOS with Wireshark

```bash
# 1. Find the radio's USB device
system_profiler SPUSBDataType | grep -A10 "Motorola"

# Note the Location ID (e.g., 0x14200000)

# 2. Load the USB capture interface (requires SIP disabled or special setup)
# This is complex on modern macOS due to security restrictions
```

### Linux (Recommended for USB capture)

```bash
# 1. Load usbmon module
sudo modprobe usbmon

# 2. Find the USB bus
lsusb | grep Motorola
# Example: Bus 002 Device 005: ID 0db9:0012 Motorola

# 3. Capture on that bus (bus 2 = usbmon2)
sudo tcpdump -i usbmon2 -w usb_capture.pcap

# Or use Wireshark with usbmon2 interface
```

---

## Analyzing the Capture

### Wireshark Display Filters

```
# All XNL traffic
tcp.port == 8002

# Filter by packet size (XNL packets are typically small)
tcp.port == 8002 && tcp.len > 0

# Follow TCP stream
Right-click packet → Follow → TCP Stream
```

### What to Look For

#### 1. XNL Authentication Sequence

Look for packets after TCP handshake:

```
Packet 1: [Client] DeviceMasterQuery (opcode 0x03)
Packet 2: [Radio]  MasterStatusBroadcast (opcode 0x02)
Packet 3: [Client] DeviceAuthKeyRequest (opcode 0x04)
Packet 4: [Radio]  DeviceAuthKeyReply (opcode 0x05)
Packet 5: [Client] DeviceConnectionRequest (opcode 0x06)
Packet 6: [Radio]  DeviceConnectionReply (opcode 0x07)
```

**Key fields in DeviceConnectionRequest (packet 5):**
- Byte 14: Device type (we use 0x0A, CPS might use different)
- Byte 15: Auth index (we use 0x00)
- Bytes 16-23: Encrypted challenge response

#### 2. Post-Auth Commands

After authentication succeeds, look for DataMessage (0x0B) packets:

```
[Client] DataMessage with XCMP payload
         Look at bytes 14+ for XCMP opcode
```

**Common XCMP init commands:**
- `0x0100` - CPS Unlock
- `0x010F` - Component Session
- `0x010B` - PSDT Access
- `0x000E` - Radio Status

#### 3. PSDT Access Sequence

When CPS reads the codeplug:

```
1. Session start (0x010F)
2. PSDT get start address (0x010B, action 0x01)
3. PSDT get end address (0x010B, action 0x02)
4. PSDT unlock (0x010B, action 0x04)
5. CPS read blocks (0x0104)
6. Session end (0x010F)
```

---

## Decoding XNL Packets

### XNL Packet Structure

```
Offset  Size  Field
------  ----  -----
0       2     Total length (big-endian)
2       1     Reserved (0x00)
3       1     Opcode
4       1     XCMP flag (0x00 or 0x01)
5       1     Flags
6       2     Destination address
8       2     Source address
10      2     Transaction ID
12      2     Payload length
14+     var   Payload (XCMP data if flag=1)
```

### XNL Opcodes

| Opcode | Name | Direction |
|--------|------|-----------|
| 0x02 | MasterStatusBroadcast | Radio → CPS |
| 0x03 | DeviceMasterQuery | CPS → Radio |
| 0x04 | DeviceAuthKeyRequest | CPS → Radio |
| 0x05 | DeviceAuthKeyReply | Radio → CPS |
| 0x06 | DeviceConnectionRequest | CPS → Radio |
| 0x07 | DeviceConnectionReply | Radio → CPS |
| 0x09 | DevSysMapBroadcast | Radio → CPS |
| 0x0B | DataMessage | Both |
| 0x0C | DataMessageAck | Both |

### XCMP Opcodes (in DataMessage payload)

| Opcode | Name |
|--------|------|
| 0x000E | RadioStatusRequest |
| 0x800E | RadioStatusReply |
| 0x000F | VersionInfoRequest |
| 0x800F | VersionInfoReply |
| 0x0100 | CPSUnlockRequest |
| 0x8100 | CPSUnlockReply |
| 0x0104 | CPSReadRequest |
| 0x8104 | CPSReadReply |
| 0x010B | PSDTAccessRequest |
| 0x810B | PSDTAccessReply |
| 0x010F | ComponentSessionRequest |
| 0x810F | ComponentSessionReply |

---

## Quick Capture Script

Save this as `capture_cps.sh`:

```bash
#!/bin/bash

# Find the radio interface
IFACE=$(ifconfig | grep -B5 "192.168.10" | grep "^en" | cut -d: -f1 | head -1)

if [ -z "$IFACE" ]; then
    echo "Radio not found. Connect the radio and try again."
    exit 1
fi

echo "Found radio on interface: $IFACE"
echo "Starting capture... Press Ctrl+C to stop."
echo ""
echo "Now run CPS and perform operations."
echo ""

FILENAME="cps_capture_$(date +%Y%m%d_%H%M%S).pcap"
sudo tcpdump -i "$IFACE" -w "$FILENAME" port 8002

echo ""
echo "Capture saved to: $FILENAME"
echo "Open with: wireshark $FILENAME"
```

---

## After Capture

Once you have a capture file:

1. **Share the .pcap file** - I can analyze the packet structure
2. **Export as hex** - In Wireshark: File → Export Packet Dissections → As Plain Text
3. **Note the sequence** - Which commands happen in what order

### Key Questions to Answer

1. What device type does CPS use in DeviceConnectionRequest?
2. What's the first XCMP command after authentication?
3. Is there a password/unlock command before PSDT access?
4. What's the exact PSDT command sequence for reading codeplug?

---

## References

- XNL Protocol: `/analysis/protocols/XNL-Protocol-Analysis.md`
- XCMP Protocol: `/analysis/protocols/XCMP-Protocol-Analysis.md`
- Current implementation: `Sources/RadioProgrammer/XNLConnection.swift`

---

**Created:** 2025-01-29
**Radio:** XPR 3500e (H02RDH9VA1AN)
**Status:** Awaiting CPS traffic capture
