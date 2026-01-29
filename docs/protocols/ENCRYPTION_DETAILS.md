# XNL Encryption Implementation Details

**Analysis Date:** 2026-01-29
**Source:** Moto.Net C# implementation

---

## Overview

The XNL protocol uses a TEA (Tiny Encryption Algorithm) variant for challenge-response authentication. There are three different encryption modes, each requiring different constants.

---

## Encryption Modes

### 1. RepeaterIPSC Encryption

**Used for:** Communicating with MOTOTRBO repeaters or radios in repeater mode
**When to use:**
- Device type from MasterStatusBroadcast = 0x01 (repeater)
- Authentication index = 0x01

**Constants required:** `XNLConst1` through `XNLConst6`

### 2. ControlStation/Subscriber Encryption

**Used for:** Communicating with subscriber radios (non-repeater mode)
**When to use:**
- Device type from MasterStatusBroadcast = 0x02 (subscriber)
- Authentication index = 0x01

**Constants required:** `XNLControlConst1` through `XNLControlConst6`

### 3. CPS Encryption

**Used for:** Full CPS functionality including codeplug programming
**When to use:**
- Authentication index = 0x00
- Requires high-privilege access

**Implementation:** Proprietary DLL (`XnlAuthenticationDotNet.dll`)
**Method:** `XnlAuthenticationDotNet.XnlAuthentication.EncryptAuthKey(byte[] data)`

---

## TEA Algorithm Implementation

### Core Algorithm (C# Reference)

```c#
public static byte[] Encrypt(byte[] data)
{
    // Input: 8 bytes
    // Output: 8 bytes

    UInt32 dword1 = ArrayToInt(data, 0);  // Bytes 0-3 → uint32
    UInt32 dword2 = ArrayToInt(data, 4);  // Bytes 4-7 → uint32

    // Load constants (different for RepeaterIPSC vs ControlStation)
    UInt32 num1 = <Const1>;  // Initial accumulator value
    UInt32 num2 = <Const2>;  // Delta (added each round)
    UInt32 num3 = <Const3>;  // Key component for dword1
    UInt32 num4 = <Const4>;  // Key component for dword1
    UInt32 num5 = <Const5>;  // Key component for dword2
    UInt32 num6 = <Const6>;  // Key component for dword2

    // 32 rounds of encryption
    for (int index = 0; index < 32; ++index)
    {
        num1 += num2;  // Accumulate delta

        // Encrypt first word
        dword1 += (uint)(((int)dword2 << 4) + (int)num3 ^
                         (int)dword2 + (int)num1 ^
                         (int)(dword2 >> 5) + (int)num4);

        // Encrypt second word
        dword2 += (uint)(((int)dword1 << 4) + (int)num5 ^
                         (int)dword1 + (int)num1 ^
                         (int)(dword1 >> 5) + (int)num6);
    }

    // Convert back to byte array
    byte[] res = new byte[8];
    IntToArray(dword1, res, 0);
    IntToArray(dword2, res, 4);
    return res;
}
```

### Helper Functions

```c#
// Convert 4 bytes (big-endian) to UInt32
private static UInt32 ArrayToInt(byte[] data, int start)
{
    UInt32 ret = 0;
    for(int i = 0; i < 4; i++)
    {
        ret = ret << 8 | data[i + start];
    }
    return ret;
}

// Convert UInt32 to 4 bytes (big-endian)
private static void IntToArray(UInt32 i, byte[] data, int start)
{
    for(int index = 0; index < 4; ++index)
    {
        data[start + 3 - index] = (byte)(i & 0xFF);
        i >>= 8;
    }
}
```

---

## Swift Implementation Template

```swift
import Foundation

enum XNLEncryptionType {
    case repeaterIPSC
    case controlStation
    case cps
}

struct XNLEncryption {
    // MARK: - Constants (need to be obtained/derived)

    // RepeaterIPSC constants
    private static let repeaterConst1: UInt32 = 0x????????
    private static let repeaterConst2: UInt32 = 0x????????
    private static let repeaterConst3: UInt32 = 0x????????
    private static let repeaterConst4: UInt32 = 0x????????
    private static let repeaterConst5: UInt32 = 0x????????
    private static let repeaterConst6: UInt32 = 0x????????

    // ControlStation constants
    private static let controlConst1: UInt32 = 0x????????
    private static let controlConst2: UInt32 = 0x????????
    private static let controlConst3: UInt32 = 0x????????
    private static let controlConst4: UInt32 = 0x????????
    private static let controlConst5: UInt32 = 0x????????
    private static let controlConst6: UInt32 = 0x????????

    // MARK: - Encryption

    static func encrypt(_ data: Data, type: XNLEncryptionType) throws -> Data {
        guard data.count == 8 else {
            throw XNLError.invalidDataLength
        }

        switch type {
        case .repeaterIPSC:
            return encryptTEA(data,
                num1: repeaterConst1, num2: repeaterConst2,
                num3: repeaterConst3, num4: repeaterConst4,
                num5: repeaterConst5, num6: repeaterConst6)
        case .controlStation:
            return encryptTEA(data,
                num1: controlConst1, num2: controlConst2,
                num3: controlConst3, num4: controlConst4,
                num5: controlConst5, num6: controlConst6)
        case .cps:
            throw XNLError.cpsEncryptionNotImplemented
        }
    }

    // MARK: - TEA Implementation

    private static func encryptTEA(_ data: Data,
                                   num1: UInt32, num2: UInt32,
                                   num3: UInt32, num4: UInt32,
                                   num5: UInt32, num6: UInt32) -> Data {
        // Convert bytes to UInt32 (big-endian)
        var dword1 = arrayToInt(data, offset: 0)
        var dword2 = arrayToInt(data, offset: 4)

        var accumulator = num1

        // 32 rounds
        for _ in 0..<32 {
            accumulator = accumulator &+ num2

            // First word transformation
            let temp1 = ((dword2 << 4) &+ num3) ^
                       (dword2 &+ accumulator) ^
                       ((dword2 >> 5) &+ num4)
            dword1 = dword1 &+ temp1

            // Second word transformation
            let temp2 = ((dword1 << 4) &+ num5) ^
                       (dword1 &+ accumulator) ^
                       ((dword1 >> 5) &+ num6)
            dword2 = dword2 &+ temp2
        }

        // Convert back to bytes
        var result = Data(count: 8)
        intToArray(dword1, data: &result, offset: 0)
        intToArray(dword2, data: &result, offset: 4)

        return result
    }

    // MARK: - Helpers

    private static func arrayToInt(_ data: Data, offset: Int) -> UInt32 {
        var result: UInt32 = 0
        for i in 0..<4 {
            result = (result << 8) | UInt32(data[offset + i])
        }
        return result
    }

    private static func intToArray(_ value: UInt32, data: inout Data, offset: Int) {
        var val = value
        for i in (0..<4).reversed() {
            data[offset + i] = UInt8(val & 0xFF)
            val >>= 8
        }
    }
}

enum XNLError: Error {
    case invalidDataLength
    case cpsEncryptionNotImplemented
}
```

---

## Determining Which Encryption to Use

### Decision Tree

```
1. Receive MasterStatusBroadcast (0x02)
   └─> Extract device type from payload[4]

2. Choose authentication index:
   ├─> For full CPS access: authIndex = 0x00
   │   └─> Use CPS encryption (requires XnlAuthenticationDotNet.dll)
   │
   └─> For limited access: authIndex = 0x01
       ├─> If device type == 0x01 (repeater)
       │   └─> Use RepeaterIPSC encryption
       │
       └─> If device type == 0x02 (subscriber)
           └─> Use ControlStation encryption

3. In DeviceConnectionRequest:
   - Set authIndex field to chosen value (byte offset 3)
   - Encrypt the 8-byte challenge using selected algorithm
   - Place encrypted result at byte offset 4
```

---

## Encryption Test Vectors

**[NEEDS VERIFICATION]**

To validate your implementation, you'll need to capture real authentication exchanges and verify that your encryption produces the same output.

### Example Test (hypothetical):

```
Input (8 bytes):  0x12 0x34 0x56 0x78 0x9A 0xBC 0xDE 0xF0
Algorithm:        RepeaterIPSC
Expected output:  [UNKNOWN - capture from real radio]
```

---

## Obtaining the Constants

### Method 1: From TRBOnet.Server.exe

If you have a licensed copy of TRBOnet:

```c#
// Repeater encryption
Assembly trbonet = Assembly.LoadFrom("TRBOnet.Server.exe");
Type crypter = trbonet.GetType("NS.Enginee.Mototrbo.Utils.XNLRepeaterCrypter");
MethodInfo mi = crypter.GetMethod("Encrypt", BindingFlags.Public | BindingFlags.Static);
mi.Invoke(null, new object[] { data });  // Modifies data in-place

// Control station encryption
Type crypter2 = trbonet.GetType("NS.Enginee.Mototrbo.Utils.XNLMasterCrypter");
MethodInfo mi2 = crypter2.GetMethod("Encrypt", BindingFlags.Public | BindingFlags.Static);
mi2.Invoke(null, new object[] { data });  // Modifies data in-place
```

### Method 2: Reverse Engineering

Per Moto.Net README:
> "This took a lot of cycles on my GPU to reverse engineer."

The constants can be derived by:
1. Capturing authentication packets
2. Knowing the plaintext (8-byte challenge)
3. Knowing the ciphertext (encrypted challenge in DeviceConnectionRequest)
4. Brute-forcing the 6 constants (computationally intensive)

### Method 3: Disassembly

Constants may be embedded in:
- Motorola CPS binaries
- RDAC (Radio Device Application Client)
- Other Motorola management tools

**Legal note:** Extracting constants from proprietary software may violate licenses.

---

## CPS Encryption (authIndex 0x00)

### Why It's Different

CPS encryption provides higher privilege levels, allowing:
- Full codeplug read/write
- Secure parameter access
- Advanced radio configuration

### Implementation

The `XnlAuthenticationDotNet.dll` is a Motorola proprietary library that implements the CPS encryption algorithm.

**Interface:**
```c#
namespace XnlAuthenticationDotNet
{
    public class XnlAuthentication
    {
        public static byte[] EncryptAuthKey(byte[] data);
    }
}
```

**Usage:**
```c#
byte[] encrypted = XnlAuthenticationDotNet.XnlAuthentication.EncryptAuthKey(challengeKey);
```

### Alternatives for macOS

Since `XnlAuthenticationDotNet.dll` is a Windows .NET library:

**Option 1:** Use Wine/CrossOver to run the DLL
**Option 2:** Reverse engineer the algorithm
**Option 3:** Use ControlStation encryption (authIndex 0x01) for limited functionality
**Option 4:** Interop with Windows machine running the encryption

---

## Security Considerations

### Cryptographic Strength

The TEA variant used is **not** modern cryptography:
- TEA is known to have weaknesses
- The 6 constants act as a shared secret (symmetric key)
- No perfect forward secrecy
- Challenge-response prevents replay attacks

### For Implementation

- Constants should be stored securely (not in plain text source)
- Consider obfuscation/encryption for deployed app
- Respect Motorola's intellectual property
- Only use for authorized/licensed purposes

---

## Debugging Tips

### Verify Big-Endian Conversion

```swift
// Test: 0x12345678 should convert to [0x12, 0x34, 0x56, 0x78]
let value: UInt32 = 0x12345678
var data = Data(count: 4)
intToArray(value, data: &data, offset: 0)
// data should be: 12 34 56 78
```

### Verify TEA Round Count

- The algorithm uses exactly 32 rounds
- Each round modifies both dword1 and dword2
- Accumulator increments by const2 each round

### Capture and Compare

1. Use Wireshark with xcmp-xnl-dissector to capture real auth
2. Extract the 8-byte challenge from DeviceAuthKeyReply
3. Extract the 8-byte encrypted challenge from DeviceConnectionRequest
4. Verify your encryption produces the same output

---

## References

- Moto.Net Encrypter.cs: `/Moto.Net/Moto.Net/Mototrbo/XNL/Encrypter.cs`
- TEA (Tiny Encryption Algorithm): Wikipedia
- XTEA (Extended TEA): More secure variant, not used here

---

## Next Steps

1. Decide on encryption approach (limited vs full CPS)
2. Obtain/derive necessary constants
3. Implement Swift version of TEA algorithm
4. Test against real radio authentication
5. Handle encryption errors gracefully
