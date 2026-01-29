# LTE Protocol Analysis

Reverse engineering analysis of Motorola's Packet-Based Broadband (PBB) protocol used for programming LTE-capable radios.

## Overview

Unlike traditional PCR-based Motorola radios that use USB serial communication with binary protocols, LTE/PBB radios use **HTTP REST APIs** for programming and configuration.

## Key Documents

- `LTE_PROTOCOL_ANALYSIS.md` - Comprehensive protocol documentation

## Quick Facts

- **Transport:** HTTP/HTTPS over WiFi or LTE
- **Data Format:** JSON for control messages, binary for codeplug data
- **Authentication:** Password-based via HTTP POST
- **Session Management:** Session ID tracked throughout programming
- **Main DLL:** `Common.Communication.LTESequenceManager.dll`

## API Endpoints Discovered

### Core Operations
- `POST /password` - Authenticate
- `GET /deviceInventory` - Read device info
- `GET /appInventory` - List apps
- `GET /licenseInventory` - List features
- `POST /fileCollection` - Upload codeplug
- `GET /fileCollection` - Download codeplug
- `POST /terminateSession` - Close session
- `POST /factoryReset` - Factory reset

### Provisioning
- `GET/POST /config` - Configuration management
- `GET /version` - Query version
- `GET /serial` - Serial number
- `POST /authKey` - Update auth key
- `POST /secureAuth` - Enable secure mode
- `POST /resetAuth` - Disable secure mode

### Certificate Management
- `POST /certificate/installCACert`
- `DELETE /certificate/uninstallAllCACerts`
- `POST /certificate/enableAllSystemCACerts`
- `POST /certificate/disableAllSystemCACerts`

## Programming Workflow

1. **Authenticate:** `POST /password` with device password
2. **Open Session:** Create session ID and open programming session
3. **Read/Write:**
   - Read: Download file collections, parse PbaObject
   - Write: Build file collection manifest, upload to device
4. **Close Session:** Terminate session, optionally pending deploy

## Data Structures

- **PbaObject** - Hierarchical codeplug structure
  - FileSets (logical groups)
  - FileItems (individual files)
- **DeviceInventory** - Device info, capabilities, versions
- **FileCollection** - Manifest of files to transfer

## Differences from PCR Protocol

| Feature | PCR | PBB/LTE |
|---------|-----|---------|
| Transport | USB Serial | HTTP/Network |
| Format | Binary opcodes | JSON + Binary |
| Connection | Cable | WiFi/LTE |
| Provisioning | No | Yes |
| Remote | No | Yes (over network) |

## Security Notes

- HTTP (not HTTPS) is vulnerable to interception
- Password authentication in cleartext over HTTP
- Certificate management available for secure deployments
- Secure mode can enforce stronger authentication

## Tools Used

- `monodis` - .NET IL disassembler
- `strings` - String extraction
- Manual IL analysis

## Next Steps

1. Capture actual HTTP traffic during programming
2. Document JSON schemas for DeviceInventory
3. Reverse file collection format
4. Implement basic HTTP CPS client
5. Analyze differential write algorithm

---

**Confidence:** High  
**Completeness:** ~75%
