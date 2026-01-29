# LTE Sequence Manager Protocol Analysis

**Target:** `Common.Communication.LTESequenceManager.dll`  
**Type:** .NET Assembly (obfuscated with Dotfuscator)  
**Version:** 3.0.131.0  
**Analysis Date:** 2026-01-29

---

## Executive Summary

The LTE Sequence Manager implements Motorola's **Packet-Based Broadband (PBB)** protocol for programming LTE-capable radios. Unlike PCR-based radios that use serial/USB binary protocols, PBB radios use **HTTP/REST APIs over WiFi or LTE** for codeplug management, device inventory, and feature provisioning.

### Key Findings

1. **Transport:** HTTP/HTTPS (not USB serial)
2. **Architecture:** RESTful API with JSON payloads
3. **Authentication:** Password-based with session management
4. **Operations:** Session-based read/write with file collection transfers
5. **Content Types:** JSON for control, octet-stream for binary data

---

## Protocol Architecture

### Transport Layer

| Aspect | Details |
|--------|---------|
| **Protocol** | HTTP/1.1 over TCP |
| **Port** | Standard HTTP/HTTPS ports |
| **Content Types** | `application/json`, `application/octet-stream`, `application/zip` |
| **Authentication** | Password-based authentication via HTTP POST |
| **Sessions** | Session ID managed throughout connection lifecycle |

### Communication Pattern

```
Client (CPS)                    Radio (LTE/PBB Device)
     |                                  |
     |----POST /password-------------->| Authenticate
     |<---200 OK + DeviceInventory-----|
     |                                  |
     |----GET /deviceInventory--------->| Read device info
     |<---200 OK + JSON Response--------|
     |                                  |
     |----POST /fileCollection--------->| Upload codeplug files
     |<---200 OK---------------------|
     |                                  |
     |----POST /terminateSession------->| Close session
     |<---200 OK---------------------|
```

---

## API Endpoints

### Core Operations

| Endpoint | Method | Purpose | Content Type |
|----------|--------|---------|--------------|
| `password` | POST | Authenticate with device password | JSON |
| `deviceInventory` | GET | Read device information and capabilities | JSON |
| `appInventory` | GET | List installed applications | JSON |
| `licenseInventory` | GET | List active licenses and features | JSON |
| `fileCollection` | POST | Upload file manifest (codeplug, etc.) | Multipart |
| `fileCollection` | GET | Download file collection from device | Octet-stream |
| `terminateSession` | POST | Close programming session | JSON |
| `factoryReset` | POST | Reset device to factory defaults | JSON |
| `job` | POST/GET | Submit and query background jobs | JSON |

### Certificate Management

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `certificate/installCACert` | POST | Install CA certificate |
| `certificate/uninstallAllCACerts` | DELETE | Remove all CA certificates |
| `certificate/enableAllSystemCACerts` | POST | Enable system CA trust |
| `certificate/disableAllSystemCACerts` | POST | Disable system CA trust |

### Application Management

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `deviceFirmware` | POST | Update device firmware |
| `packageFile` | POST | Install provisioning package |
| `deleteAppInventory` | DELETE | Remove installed application |

### Provisioning Operations

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `config` | GET/POST | Read/write configuration |
| `version` | GET | Query provisioning version |
| `serial` | GET | Read device serial number |
| `get_alias_id` | GET | Query alias identifier |
| `get_mode` | GET | Check security mode |
| `authKey` | POST | Update authentication key |
| `updateuser` | POST | Modify user credentials |
| `cfs_hardware_id` | GET | Read CFS hardware ID |
| `secureAuth` | POST | Enable secure authentication mode |
| `resetAuth` | POST | Disable secure authentication |

### LMR-Specific

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `lmrCodeplug` | POST/GET | Upload/download LMR codeplug data |

---

## Message Classes

### PBBSequenceManager Methods

The `PBBSequenceManager` class provides high-level operations:

| Method | Purpose | Parameters |
|--------|---------|------------|
| `OpenSession` | Initiate programming session | `sessionID`, `operation` |
| `CloseSession` | Terminate programming session | `sessionID`, `operation`, `pendingDeploy` |
| `ReadDevice` | Read codeplug and device data | `referencePba`, `sessionID` |
| `WriteDevice` | Write codeplug to device | `pbaObject`, `sessionID`, `pcrNewPassword`, `hostedDepotOperation` |
| `ReadDeviceInfo` | Query basic device information | None |
| `ReadExtendedDeviceInfo` | Query detailed device information | `password` (optional) |
| `UpdateProgrammingStatus` | Report programming progress | `status`, `sessionID` |
| `DifferentialWriteSupported` | Check if device supports differential write | `sessionID`, `operation` |
| `ReadBlocks<T>` | Read specific data blocks | `blockList` |
| `ReadLanguagePacksInfo` | Query installed language packs | None |
| `WriteLanguagePacks` | Install language packs | `langPackData` |
| `DeleteLanguagePacks` | Remove language packs | `langPackData` |
| `ReadTTSLanguagePacksInfo` | Query TTS language packs | None |
| `WriteTTSLanguagePacks` | Install TTS language packs | `langPackData` |
| `DeleteTTSLanguagePacks` | Remove TTS language packs | `langPackData` |
| `SwitchRadioMode` | Change radio operating mode | `mode` |
| `SendFPGAErase` | Erase FPGA firmware | `fileType` |
| `SendFPGAReset` | Reset FPGA | `fileType` |
| `EnableFeature` | Activate licensed feature | `fwVersion`, `serialNumber`, `xmlHashInput`, `featureCodeIDs` |
| `EnableFeatures` | Activate features via capability file | `capabilityFile` |
| `ReadHashInputAndValidate` | Validate codeplug integrity | `validatePba`, `blockList` |
| `TerminateSession` | Forcefully end session | `code`, `reason` |
| `UpdateMACAddress` | Update device MAC address | `macAddress` |
| `SetFWDLConfig` | Configure firmware download | `tg`, `version` |
| `ValidateLocalPassword` | Verify device password | `password` |
| `QueryRadioUpdateStatus` | Check firmware update status | None |
| `ReadRadioParameters` | Read radio parameter pairs | `paramPairs` |

---

## Data Structures

### DeviceInventory (Response from /deviceInventory)

Contains:
- Device model and serial number
- Firmware version
- Codeplug version
- Installed applications
- Active licenses
- Hardware capabilities

### FileCollection

Manifest structure for file uploads/downloads:
- File names and sizes
- File types (codeplug, language pack, firmware, etc.)
- Checksums/hashes
- File metadata

### PbaObject (Programming Binary Architecture)

Hierarchical structure representing:
- **FileSets**: Logical groups of files
  - Codeplug data
  - Language packs
  - TTS data
  - Applications
  - Licenses
- **FileItems**: Individual binary blobs
  - File content (byte arrays)
  - File metadata
  - Version information

### Session Management

- **SessionID**: Unique 16-bit identifier
- **Operation**: Read, Write, or Update
- **Status**: Programming progress indicator
- **PendingDeploy**: Flag for deferred activation

---

## Authentication Sequence

### Password Authentication

1. **Client → Device:** `POST /password`
   ```json
   {
     "password": "device_password"
   }
   ```

2. **Device → Client:** `200 OK`
   ```json
   {
     "deviceInventory": {
       "model": "...",
       "serial": "...",
       "firmware": "...",
       // ... additional fields
     }
   }
   ```

3. **Authentication Status:** Success returns DeviceInventory, failure returns 4xx error

---

## Codeplug Read/Write Operations

### Reading Device (Download)

1. `OpenSession(sessionID, ReadOperation)`
2. `ReadDevice(referencePba, sessionID)` → Returns `PbaObject`
   - Internally calls `HttpReadDeviceInventory`
   - Calls `HttpListApp` for applications
   - Calls `HttpListLicense` for licenses
   - Downloads file collections via `HttpDownloadFileCollection`
3. `UpdateProgrammingStatus(status, sessionID)` (periodic progress updates)
4. `CloseSession(sessionID, ReadOperation, false)`

### Writing Device (Upload)

1. `OpenSession(sessionID, WriteOperation)`
2. `ValidateLocalPassword(password)` (if required)
3. `WriteDevice(pbaObject, sessionID, newPassword, false)`
   - Builds file manifest
   - Uploads via `HttpUploadFileCollection`
   - Monitors job status
4. `UpdateProgrammingStatus(status, sessionID)`
5. `CloseSession(sessionID, WriteOperation, pendingDeploy)`

### Differential Write

- **Capability Check:** `DifferentialWriteSupported(sessionID, operation)`
- **Mechanism:** Only changed data blocks are transmitted
- **Advantage:** Faster programming for minor changes

---

## File Transfer Protocol

### Upload (Client → Device)

**Endpoint:** `POST /fileCollection`  
**Content-Type:** `multipart/form-data` or `application/octet-stream`

**Process:**
1. Generate file manifest (JSON listing files to transfer)
2. Package files into collection
3. POST to `/fileCollection` endpoint
4. Receive response with transfer status

**Response:**
```json
{
  "fileCollection": {
    "fileName": "uploaded_manifest.json",
    "files": [
      {"name": "codeplug.bin", "size": 12345, "status": "success"},
      // ...
    ]
  }
}
```

### Download (Device → Client)

**Endpoint:** `GET /fileCollection?fileName=manifest.json`  
**Content-Type:** `application/octet-stream`

**Process:**
1. Request specific file collection by name
2. Receive binary data stream
3. Parse file collection structure
4. Extract individual files

---

## Feature Licensing

### Enable Feature

**Method:** `EnableFeature(fwVersion, serialNumber, xmlHashInput, featureCodeIDs)`

**Process:**
1. Compute hash from device info and codeplug
2. Submit feature code IDs (license keys)
3. Device validates and activates features

### Capability File

**Method:** `EnableFeatures(capabilityFile)`

**Process:**
1. Upload pre-generated capability file (.cap)
2. Device parses and applies all licenses in file

---

## Error Handling

### HTTP Status Codes

| Code | Meaning | Typical Cause |
|------|---------|---------------|
| 200 | OK | Successful operation |
| 400 | Bad Request | Malformed JSON or invalid parameters |
| 401 | Unauthorized | Password authentication failed |
| 404 | Not Found | Endpoint or file not available |
| 500 | Internal Server Error | Device-side processing error |
| 503 | Service Unavailable | Device busy or not ready |

### Retry Logic

- **Send Attempts:** Configurable (typically 3 retries)
- **Retry Delay:** Configurable delay between attempts
- **Timeout:** Message-specific timeouts

---

## Differences from PCR Protocol

| Aspect | PCR Protocol | PBB/LTE Protocol |
|--------|--------------|------------------|
| **Transport** | USB Serial / Binary | HTTP/REST / JSON |
| **Connection** | Physical USB cable | Network (WiFi/LTE) |
| **Messages** | Binary opcodes | HTTP methods + JSON |
| **Authentication** | Serial handshake | HTTP password POST |
| **Codeplug Transfer** | Block-by-block binary | File collection upload |
| **Progress Updates** | Binary status messages | HTTP status endpoints |
| **Session Management** | USB connection lifecycle | HTTP session ID |
| **Provisioning** | Not supported | Full provisioning API |

---

## LTE-Specific Features

### Provisioning

LTE radios support **over-the-air provisioning** via the provisioning API:

- **Configuration Management:** Read/write device config files
- **User Management:** Update passwords and authentication
- **Security Modes:** Toggle between secure and insecure modes
- **Certificate Management:** Install/remove trusted CAs
- **Version Management:** Query provisioning agent version

### Package Deployment

**Endpoint:** `POST /packageFile`

Allows bulk updates via provisioning packages:
- Multiple config files
- Firmware updates
- Application installations
- Certificate bundles

### Remote Management

Because PBB uses HTTP, radios can be programmed:
- **Over WiFi** (local network or AP mode)
- **Over LTE** (if device has SIM and connectivity)
- **Through VPN** (for remote fleet management)

---

## Security Considerations

### Authentication

- Password-based authentication (cleartext over HTTP unless HTTPS)
- Session management prevents unauthorized access
- Secure mode can enforce stronger authentication

### Encryption

- **HTTP:** No encryption (vulnerable to interception)
- **HTTPS:** TLS encryption (requires valid certificates)
- **Codeplug Encryption:** Separate layer (not transport-level)

### Certificate Pinning

LTE CPS supports CA certificate management:
- Install trusted CAs
- Enable/disable system CA trust
- Uninstall untrusted certificates

---

## Obfuscation Analysis

**Tool:** Dotfuscator 4.39.0.8792  
**Obfuscation Level:** Medium

- **Method Names:** Many obfuscated to single letters (a, b, c, etc.)
- **Class Names:** Public API classes retain names, internals obfuscated
- **String Encryption:** Some strings obfuscated with decryption routine
- **Control Flow:** Not significantly altered
- **Constants:** Public constants remain readable

**Reversibility:** Moderate. High-level protocol structure is clear, but low-level implementation details require deeper analysis.

---

## Implementation Notes

### Building an LTE CPS Client

To implement a compatible client:

1. **HTTP Client:** Use standard HTTP library with JSON support
2. **Authentication:** POST password to `/password` endpoint
3. **Session Management:** Track sessionID throughout operation
4. **File Collections:** Package files into manifest + binary blobs
5. **Error Handling:** Implement retry logic for network failures
6. **Progress Reporting:** Call `UpdateProgrammingStatus` periodically

### Example Workflow (Pseudocode)

```python
# Authenticate
response = http.post(f"{radio_url}/password", json={"password": pwd})
device_info = response.json()["deviceInventory"]

# Read codeplug
session_id = generate_session_id()
open_session(session_id, RadioOperation.Read)

inventory = http.get(f"{radio_url}/deviceInventory").json()
apps = http.get(f"{radio_url}/appInventory").json()
licenses = http.get(f"{radio_url}/licenseInventory").json()

# Download file collection
file_collection = http.get(f"{radio_url}/fileCollection?fileName=codeplug.manifest").content
pba_object = parse_file_collection(file_collection)

close_session(session_id, RadioOperation.Read, pending_deploy=False)

# Write codeplug (modify pba_object, then)
open_session(session_id, RadioOperation.Write)
manifest = build_file_collection(pba_object)
http.post(f"{radio_url}/fileCollection", data=manifest)
close_session(session_id, RadioOperation.Write, pending_deploy=True)
```

---

## Next Steps

### Further Analysis

1. **Packet Capture:** Monitor actual HTTP traffic during CPS programming
2. **File Collection Format:** Reverse engineer manifest and file structure
3. **DeviceInventory Schema:** Document JSON structure for device info
4. **Error Codes:** Map HTTP errors and device-specific error messages
5. **Authentication Details:** Analyze password hashing/encoding
6. **Differential Write Algorithm:** Understand block comparison logic

### Tool Development

1. **LTE Codeplug Parser:** Extract/modify PbaObject structures
2. **HTTP CPS Client:** Implement basic read/write operations
3. **Provisioning Tool:** Automate device configuration
4. **License Manager:** Tool for feature activation

---

## References

- `Common.Communication.LTESequenceManager.dll` (v3.0.131.0)
- `Common.Communication.HttpWrapper.dll` (v3.0.131.0)
- `Pba.dll` (v3.1.12.0)
- `Common.Communication.CommonInterface.dll` (v3.0.131.0)

---

**Analysis Confidence:** High  
**Completeness:** ~75% (protocol structure understood, implementation details require runtime analysis)

