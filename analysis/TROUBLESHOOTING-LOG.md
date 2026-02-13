# Radio Detection Troubleshooting Log

**Radio:** XPR 3500e (MOTOTRBO)
**Model Number:** H02RDH9VA1AN
**Serial:** 867TXM0273
**Firmware:** R02.21.01.1001
**Started:** 2026-01-31
**Status:** INVESTIGATING

---

## The Problem

Radio was working yesterday (2026-01-30) but today doesn't appear on USB bus at all.

---

## Historical Context (What Worked 2026-01-29 to 2026-01-30)

### Session 1: Initial Protocol Discovery (2026-01-29)
- Connected radio via USB
- CDC-ECM interface appeared as `en17`
- Radio IP: 192.168.10.1, Host IP: 192.168.10.2
- XNL authentication SUCCEEDED with TEA key and custom delta
- Read model number: H02RDH9VA1AN
- Read firmware: R02.21.01.1001
- Read serial: 867TXM0273
- Multi-command sessions had caching issue (fixed with msg ID increment)

### Session 2: Continued Testing (2026-01-30)
- Radio connected reliably
- Added auto-detection to WelcomeView
- Implemented ProgrammingView progress sheet
- Radio was detected within seconds of plugging in
- All XNL/XCMP communication worked

### Session 3: Today (2026-01-31)
- Radio doesn't appear on USB at all
- No VID 0x0CAD in ioreg
- No en17 interface
- macOS remembers the network service but interface doesn't exist

---

## Things We've Tried

### 1. USB Device Detection via IOKit
**Date:** 2026-01-31
**Result:** FAILED - No device with VID 0x0CAD found

**What we checked:**
- `ioreg -p IOUSB -l` - No Motorola devices
- `system_profiler SPUSBDataType` - No Motorola devices
- IOKit enumeration with `IOServiceMatching(kIOUSBDeviceClassName)` - No VID 0x0CAD
- Looked for VID 3245 (decimal for 0x0CAD)
- Looked for PIDs 0x1020-0x102D
- Checked vendor strings for "Motorola", "MOTO", "XPR", "radio"

**Raw ioreg output showed these USB devices (but no Motorola):**
- USB2.0 Hub (VID 8457)
- USB3.0 Hub (VID 8457)
- USB 2.0 BILLBOARD (VID 8457)
- USB Device (VID 3141)
- Mass Storage (VID 1423)

**Conclusion:** Radio is NOT appearing on USB bus. This is a hardware-level issue.

---

### 2. Network Interface Detection
**Date:** 2026-01-31
**Result:** FAILED - No en17 interface exists

**What we checked:**
- `ifconfig -a` - No en17 interface
- macOS remembers "Motorola Solutions LTD Device" service for en17 but interface doesn't exist
- Network service configured with 192.168.10.2 but interface is absent

**Conclusion:** CDC-ECM interface can't be created because USB device isn't enumerating.

---

### 3. System Log Analysis
**Date:** 2026-01-31
**Result:** NO EVENTS FOUND

**What we checked:**
- `log show --predicate 'eventMessage CONTAINS[c] "usb"'` - No USB events
- `log show --predicate 'subsystem == "com.apple.iokit"'` - No relevant events

**Conclusion:** No USB enumeration is happening at all.

---

### 4. IP Range Scanning
**Date:** 2026-01-31
**Result:** FAILED - 192.168.10.1 not reachable

**What we scanned:**
- 192.168.10.1-20 (standard MOTOTRBO range)
- 192.168.1.1-20, 192.168.2.1-20, 192.168.0.1-20
- 172.16.0.1-10, 172.16.1.1-10
- 10.0.0.1, 10.0.0.10, etc.
- 169.254.x.x (link-local)

**Conclusion:** Radio network interface doesn't exist, so IP is unreachable.

---

### 5. mDNS Discovery (_otap._tcp.local)
**Date:** 2026-01-31
**Result:** NOT YET TESTED (radio not connected)

**What we analyzed:**
- CPS 2.0 uses mDNS via `DNSConfig.xml`:
  - GroupIP: 224.0.0.251
  - Port: 5353
  - Service: _otap._tcp.local
- DeviceDiscovery.dll contains: RNDISDetector, DNSSDDetector, VCOMDetector, LDTDetector
- RNDISDetector uses Windows PnP events with NetworkAdapterInfo class

**What we added to RadioDetector.swift:**
- NWBrowser for mDNS service discovery
- Service type: `_otap._tcp`
- Domain: `local`

**Conclusion:** Pending - requires radio to be connected first.

---

### 6. CPS 2.0 DLL Analysis
**Date:** 2026-01-31
**Result:** INFORMATIVE

**What we learned from monodis disassembly:**

**From Common.Communication.DeviceDiscovery.dll:**
- Uses PnPDeviceDetectorBase class for USB Plug-and-Play events
- RNDISDetector extends PnPDeviceDetectorBase
- NetworkAdapterInfo class stores: Name, MacAddress, IPAddress, IsDhcpEnabled
- Uses Windows device GUIDs for matching

**From mototrbo.inf driver file:**
- Official Motorola USB VID: 0x0CAD (3245)
- Official PIDs: 0x1020-0x102D
- These are CDC-ECM devices on macOS (RNDIS on Windows)

**From DNSConfig.xml:**
- mDNS multicast IP: 224.0.0.251
- mDNS port: 5353
- Service: _otap._tcp.local

**Conclusion:** CPS relies on Windows PnP events which translate to USB enumeration on macOS. If USB doesn't enumerate, neither CPS nor our app can find the radio.

---

### 7. Athena Knowledge Base Consultation
**Date:** 2026-01-31
**Result:** INFORMATIVE

**What Athena confirmed:**
- Radio must be physically connected and in correct mode
- USB CDC-ECM devices can have intermittent enumeration issues
- Interface names (en17, en18, etc.) are not fixed
- Power cycle often fixes USB enumeration issues

**What wasn't documented:**
- Specific USB CDC-ECM enumeration failure patterns
- Radio modes that prevent USB enumeration
- This is a gap to fill once solved

---

## Things That WORKED Yesterday (2026-01-30)

1. Radio appeared as CDC-ECM device on USB
2. macOS created en17 interface automatically
3. Radio DHCP assigned host IP 192.168.10.2
4. Radio reachable at 192.168.10.1
5. XNL port 8002 was open
6. Full XNL authentication worked
7. XCMP commands succeeded (model, firmware, serial read)

---

## Key Learnings

### Interface Name Is NOT Fixed
- The radio doesn't always appear as `en17`
- macOS assigns interface names dynamically based on order of connection
- Previous radios/adapters may have "used up" lower interface numbers
- **NEVER hardcode interface name** - always scan all interfaces

### Detection Methods (Ordered by Reliability)

1. **USB VID/PID** - Most reliable when radio is connected
   - VID: 0x0CAD (Motorola Solutions)
   - PIDs: 0x1020-0x102D
   - If no device with this VID, radio is NOT connected

2. **Network Interface + XNL Port** - Good for finding the IP
   - Look for private IP interfaces (192.168.x.x, etc.)
   - Try XNL port 8002 on gateway IP
   - Faster than ping for detection

3. **mDNS (_otap._tcp.local)** - CPS method
   - Radios may advertise via Bonjour
   - Not all radios support this

4. **IP Range Scan** - Fallback
   - Slow but catches edge cases
   - Use parallel scanning for speed

### Radio States

| State | USB Appears | Network Works |
|-------|-------------|---------------|
| Powered OFF | NO | NO |
| Charging only | NO | NO |
| Powered ON, no cable | NO | NO |
| Powered ON, charge-only cable | NO | NO |
| Powered ON, data cable | YES | YES |

### Known Gotchas

1. **Charge-only cables** look identical to data cables but don't work
2. **Radio must be fully powered ON** - not just charging
3. **Some USB hubs** don't provide enough power
4. **VM capture** - Parallels/VMware may claim the USB device
5. **Sleep/wake** may require USB replug
6. **Radio firmware hang** may require power cycle

---

## Current Hypothesis

The radio is either:
1. Not powered on (just charging)
2. Connected via charge-only cable
3. In a bad firmware state requiring power cycle
4. Connected to a USB port that's not providing proper power
5. Being captured by a VM

---

## Code Changes Made (2026-01-31)

### RadioDetector.swift Improvements

1. **Added mDNS discovery** - Like CPS 2.0
   - Uses NWBrowser for `_otap._tcp.local` service discovery
   - Resolves discovered services to IP addresses
   - Verifies XNL port 8002 before adding device

2. **Improved troubleshooting output**
   - Different guidance for USB-level vs network-level issues
   - Actionable checklist format
   - Diagnostic commands included in output

3. **Detection flow now:**
   - Method 1: USB VID/PID (0x0CAD)
   - Method 2: USB device -> network interface
   - Method 3: mDNS discovery (_otap._tcp.local)
   - Method 4: IP range scanning (parallel)
   - Method 5: Serial ports

---

## Next Steps to Try

1. [ ] Verify radio is fully powered ON (not just charging light)
2. [ ] Try a known-good USB data cable
3. [ ] Try different USB port (USB-A vs USB-C hub)
4. [ ] Power cycle the radio completely
5. [ ] Check if VM software has USB passthrough enabled
6. [ ] Monitor USB connection in real-time: `log stream --predicate 'eventMessage CONTAINS "USB"' --level debug`
7. [ ] Check radio is not in a special mode (repeater mode, etc.)

---

## Verification Commands

```bash
# Check for Motorola USB device
ioreg -p IOUSB -l | grep -i motorola
ioreg -p IOUSB -l | grep "idVendor.*3245"

# Check for CDC-ECM network interface
ifconfig | grep -A 5 "192.168.10"

# Check XNL port
nc -z -v -G 1 192.168.10.1 8002

# Monitor USB events
log stream --predicate 'eventMessage CONTAINS "USB"' --level debug

# System profiler
system_profiler SPUSBDataType | grep -A 10 Motorola
```

---

## When Radio IS Connected (Expected Output)

```
$ ioreg -p IOUSB -l | grep -A 5 "Motorola"
    "idVendor" = 3245   # 0x0CAD
    "idProduct" = 4130  # 0x1022 (example)
    "USB Product Name" = "MOTOTRBO"

$ ifconfig en17  # (or whatever interface number)
    inet 192.168.10.2 netmask 0xffffff00

$ nc -z -v -G 1 192.168.10.1 8002
Connection to 192.168.10.1 port 8002 [tcp/*] succeeded!
```

---

## Update Log

| Date | What Changed | Result |
|------|--------------|--------|
| 2026-01-31 | Created troubleshooting log | - |
| 2026-01-31 | Added mDNS discovery to RadioDetector | Pending test |
| 2026-01-31 | Improved troubleshooting guidance in scan output | Done |
| 2026-01-31 | Analyzed CPS 2.0 discovery DLLs | Informative |
| 2026-01-31 | **Radio reconnected after power cycle** | **WORKING** |
| 2026-01-31 | USB VID 3245, en17, 192.168.10.2, XNL port open | Verified |
| 2026-01-31 | Fixed mDNS discovery build errors (inout closure capture) | Done |
| 2026-01-31 | **App detection test** | **SUCCESS** - detected XPR3500e-UHF |
| 2026-01-31 | **Channel data not showing** - identified root cause | Missing programming mode entry |
| 2026-01-31 | Added `connection.initialize()` call to `readZonesAndChannels()` | Pending test |
| 2026-01-31 | Added `exitProgramMode` call at end of read | Done |
| 2026-01-31 | **CRASH: SIGPIPE during read** | Fixed - added SO_NOSIGPIPE |
| 2026-01-31 | Added SO_NOSIGPIPE socket option | Done |
| 2026-01-31 | Improved EPIPE error handling in send() | Done |
| 2026-01-31 | **Security unlock fails (0x01)** - wrong encryption algorithm | LFSR → TEA |
| 2026-01-31 | Fixed `encryptRadioKey()` to use TEA instead of LFSR | Pending test |

---

## Issue 2: Channel Data Not Showing (2026-01-31)

**Symptom:** Radio is detected, app reads model/serial/firmware, but zones and channels are empty.

**Root Cause:** The `readZonesAndChannels()` function was NOT entering programming mode before attempting to read zone/channel data. The radio requires the initialization sequence:

1. Enter programming mode (0x0106 with action 0x01)
2. Read radio key (0x0300)
3. Encrypt radio key
4. Unlock security (0x0301) with encrypted key
5. Unlock partition (0x0108)

Without this sequence, CloneRead commands return no data.

**Fix Applied:**
- Added call to `xnlConnection.initialize(partition: .application)` after getting device info
- Added call to exit programming mode (0x0106 with action 0x00) at end of read

**File Modified:** `Packages/RadioHardware/Sources/RadioProgrammer/MOTOTRBOProgrammer.swift`

**Verification Needed:** Test reading from radio with debug=true to confirm:
1. Programming mode enters successfully
2. CloneRead commands return channel data
3. Zones and channels populate in the UI

---

## Issue 3: SIGPIPE Crash During Read (2026-01-31)

**Symptom:** App crashes with "Terminated due to signal 13" when reading radio.

**Debug Output Before Crash:**
```
nw_connection_copy_protocol_metadata_internal on unconnected nw_connection
[XNL TX] 00 12 00 0B 01 0C ... 01 0A 00 00 00 04 (CloneRead command)
[SEND] Attempting to send 20 bytes...
Message from debugger: Terminated due to signal 13
```

**Root Cause:**
1. Signal 13 is SIGPIPE - occurs when writing to a broken socket
2. The BSD socket was not configured with `SO_NOSIGPIPE`
3. When the radio closed the connection (possibly during programming mode entry), writing to the socket sent SIGPIPE which killed the process

**Fix Applied:**

1. Added `SO_NOSIGPIPE` socket option when creating the connection:
   ```swift
   var nosigpipe: Int32 = 1
   setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &nosigpipe, socklen_t(MemoryLayout<Int32>.size))
   ```

2. Improved error handling in `send()` to detect EPIPE/ECONNRESET:
   ```swift
   if err == EPIPE || err == ECONNRESET || err == ENOTCONN {
       close(socketFD)
       socketFD = -1
       throw NSError(..., "Connection closed by radio")
   }
   ```

**File Modified:** `Packages/RadioHardware/Sources/RadioProgrammer/XNLConnection.swift`

**Note:** The `nw_connection_copy_protocol_metadata_internal` warnings are from RadioDetector's parallel port scanning using NWConnection - these are benign warnings, not the cause of the crash.

---

## Resolution (Detection)

**Status:** RESOLVED (2026-01-31)

**Root Cause:** Radio was not fully powered on or in correct state

**What Fixed It:** User turned off radio, unplugged, replugged, and powered on properly

**Observed After Fix:**
```
USB Device: VID 3245 (0x0CAD), "Motorola Solutions LTD Device"
Interface: en17
Host IP: 192.168.10.2
Radio IP: 192.168.10.1
XNL Port 8002: OPEN
```

**Key Lesson:** The same cable, same port, same radio can work or not work depending on:
1. Whether radio is fully powered on (not just plugged in)
2. Boot sequence timing
3. Radio firmware state

**Prevention:**
- Always power cycle radio if detection fails
- Don't assume "worked yesterday" means hardware is OK
- Radio needs to complete full boot before USB CDC-ECM activates

---

## Issue 4: Security Unlock Fails with Error 0x01 (2026-01-31)

**Symptom:** `[INIT] Unlock security failed with error: 0x01` during programming mode initialization, followed by commands timing out.

**Debug Output:**
```
[INIT] Unlock security failed with error: 0x01
[READ] Unlock security failed: 0x01
[READ] Reading radio settings...
[XNL TX] ... CloneRead command
[XNL RX] Timeout (attempt 1)
... 20 timeout attempts ...
```

**Root Cause:** The `encryptRadioKey()` function in `XNLEncryption.swift` was using an LFSR-based algorithm, but the whitepaper clearly states: *"Radio key encryption uses the same TEA algorithm as XNL authentication"*

The 32-byte radio key needs to be encrypted using TEA (in 8-byte ECB blocks), NOT the LFSR algorithm that was implemented.

**Error Code 0x01:** Indicates the encrypted key validation failed - the radio rejected our encrypted key because it was wrong.

**Fix Applied:**
- Replaced LFSR-based `encryptRadioKey()` with TEA-based encryption
- The 32-byte key is now encrypted in four 8-byte blocks using the same TEA algorithm/key/delta as XNL authentication

**File Modified:** `Packages/RadioHardware/Sources/RadioProgrammer/XNLEncryption.swift`

**Before:**
```swift
// LFSR-based algorithm (WRONG)
var state: UInt32 = lfsrInitialState
for i in 0..<32 {
    // ... complex bit manipulation
}
```

**After:**
```swift
// TEA-based algorithm (per whitepaper)
for blockIndex in 0..<4 {
    let block = radioKey[blockIndex*8..<(blockIndex+1)*8]
    guard let encryptedBlock = encrypt(Data(block)) else { return nil }
    result.append(encryptedBlock)
}
```

**Verification Needed:** Test reading from radio to confirm security unlock succeeds.

**Reference:** `/docs/XNL-XCMP-Protocol-Whitepaper.md` - Section 9: Programming Mode Initialization
