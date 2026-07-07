# CPS 2.0 Protocol Verification — radiowriter

**Date:** 2026-07-06
**Method:** Decompiled 16 official CPS 2.0 comms assemblies (ILSpy → C#), diffed against radiowriter's Swift implementation.
**Source DLLs:** `CPS 2.0 dll files/` (CPS 2.0, build Jun 2023)
**Decompiled output:** `analysis/cps_decompiled/*.cs` (410K lines total)

This replaces guesswork in `MOTOTRBO_CPS_GAP_ANALYSIS.md` with ground-truth from Motorola's own code.

---

## ✅ VERIFIED CORRECT — XNL Authentication (TEA)

`XnlAuthentication.dll` → `analysis/cps_decompiled/XnlAuthentication.cs`
vs `Packages/RadioHardware/Sources/RadioProgrammer/XNLEncryption.swift`

radiowriter's TEA implementation is **byte-for-byte identical** to Motorola's. The auth was never the bug.

| Element | CPS source (C#) | radiowriter (Swift) | Match |
|---|---|---|---|
| TEA key bytes | `29,48,150,90, 85,170,242,12, 198,108,147,191, 91,205,94,189` (XnlAuthentication.cs:210) | same 16 bytes | ✅ |
| Key as LE UInt32 | `0x5A96301D, 0x0CF2AA55, 0xBF936CC6, 0xBD5ECD5B` | identical | ✅ |
| Delta constant | `2030745457u` = `0x790AB771` (XnlAuthentication.cs:414,505) — NON-standard TEA delta | `0x790AB771` | ✅ |
| Rounds | 32 (`if (num6 >= 32)`) | 32 | ✅ |
| Round function | `((v << 4)+k) ^ (v+sum) ^ ((v >> 5)+k)` (XnlAuthentication.cs:377-378) | identical | ✅ |
| Key load endianness | LE (`BitConverter.ToInt32`, XnlAuthentication.cs:178) | LE | ✅ |
| Block I/O endianness | BE (`Array.Reverse` on output, XnlAuthentication.cs:83-84) | BE | ✅ |

**Conclusion:** If the radio rejected the unlock (log error 0x01), the cause is downstream of auth — in the RcmpUnlockSecurity command construction or the read-radio-key step, NOT the TEA crypto. Verified by the codeplug/XCMP diff passes.

---

## XNL Opcodes (from Common.Communication.XNL.cs)

Raw opcodes observed in send/receive logic (`xnlPacket.opcode`):

| Opcode | Role (from control flow) |
|---|---|
| 0 | (init/reset) |
| 1 | DeviceMaster query (Master Status Broadcast request) |
| 2 | DeviceMaster reply |
| 3 | AuthKey request |
| 4 | AuthKey reply |
| 5 | Connection request |
| 6 | Connection reply |
| 7 | (connection ack/sysmap) |
| 11 | Data message (XCMP payload) |
| 12 | Data message ack |
| 16 | (broadcast / disconnect) |

`XnlProtocol` enum: `XnlControl=0`, `Xcmp=1` — the protocol-type byte.

*(Full session sequence + divergences: see agent diff results appended below.)*

---

## Divergence findings (from parallel diff passes)

### XNL HANDSHAKE — ROOT CAUSE: 2-byte structural offset in packet model

radiowriter models the wire as `[len:2][00][opcode:1][xcmpflag:1][flags:1][dest:2][src:2][txid:2][len:2]`.
Motorola's actual `XnlPacket` is `[opcode:2][proto:1][flags:1][dest:2][src:2][txid:2][len:2]` — a **12-byte header** — with the 2-byte transport length living in a **separate outer frame** (opcodes 0/16). This one offset cascades into nearly every handshake divergence.

**True CPS XnlPacket header (Common.Communication.XNL.cs c() L629-636):**
| Offset | Field | Meaning |
|---|---|---|
| 0-1 | opcode (BE) | opcode |
| 2 | proto (`d`) | XnlProtocol: 0=XnlControl, 1=Xcmp |
| 3 | flags (`e`) | session flag (0x08 = permanent session) |
| 4-5 | dest (`f`, BE) | destination addr |
| 6-7 | src (`g`, BE) | source addr |
| 8-9 | txid (`h`, BE) | transaction ID |
| 10-11 | payloadLength (BE) | |
| 12+ | payload | |

**True CPS connection sequence (receive-side state machine j→h→g→f, L5836-6276):**
1. CPS **sends opcode 3** (DeviceMasterQuery, zero payload, f=g=h=0). ← radiowriter never sends this
2. Radio **sends opcode 5** (SysMapBroadcast): `m = payload[0..1]` (master addr), seed = `payload[2..10]` (8 bytes). ← radiowriter reads seed at raw offset 16, should be payload offset 2 (raw 14)
3. CPS **sends opcode 6** (AuthKey): payload = `[m_hi, m_lo, 0x0A, 0x00, <8-byte TEA-encrypted seed>]`, f=m, e=0x08. ← radiowriter hardcodes payload[0..1]=0x0000, should echo `m`
4. Radio **sends opcode 7** (ConnReply/auth result): payload[0]=result (==1 ok), payload[2..3]=our assigned addr, payload[6..13]=key for validation.

**CRITICAL:**
- **C1** — opcode numbering wrong. radiowriter: masterStatusBroadcast=0x02, deviceMasterQuery=0x04, sysMap=0x05, authKey=0x06, authKeyReply=0x07, connReply=0x09. CPS uses 2/3/4/5/6/7 with different roles. `dataMessage=11 (0x0B)` / `dataMessageAck=12 (0x0C)` happen to align. Handshake opcodes do not.
- **C2** — radiowriter blocks waiting for a 0x02 broadcast FIRST (radio-initiates); CPS initiates by sending opcode 3. If radio doesn't spontaneously send 0x02, radiowriter times out immediately.
- **C3** — auth-seed offset off by 2 (reads raw 16, should be raw 14 / payload 2); treats 2-byte master field as 1-byte prefix.
- **C4** — AuthKey payload[0..1] hardcoded 0x0000; CPS echoes the `m` value from sysmap. Radio may reject.

**MODERATE:**
- **M1** — txID model wrong (global counter vs CPS control-plane h=0); harmless for handshake (both use 0).
- **M2** — Xcmp indicator at wrong offset (radiowriter byte 4; CPS byte 2 = proto field).
- **M3** — `deviceConnReply=0x09` isn't a real CPS opcode; result comes in opcode 7. Wasted 5×5s timeout.

**VERIFIED MATCHING:** big-endian encoding throughout ✅ · 2-byte payload-length field ✅ · AuthKey tail `0x0A 0x00 [key]` ✅ · auth result==1 check ✅ · 8-byte seed ✅ · assigned-addr reuse ✅ · B400 init broadcast shape (`0xB4...0x0A`) ✅.

**⚠️ FIX-PASS CAVEAT (from the agent, important):** radiowriter's existing captures suggested its layout worked on the wire — there's an internal inconsistency. **Confirm the byte-0/1 = opcode hypothesis against ONE live capture before realigning the header.** Do not blind-rewrite against the decompile; a wrong guess risks the write path.

### XCMP COMMANDS — ⛔ COMMAND VOCABULARY SUBSTANTIALLY WRONG (this is why programming never worked)

Framing is correct (2-byte BE opcode, reply=`|0x8000`, broadcast=`|0xB000`). ~20 opcodes + several enums verified matching. **But the codeplug-read and security-unlock command mappings are wrong, and the real unlock handshake is missing entirely.** Ref: `Common.Communication.RcmpWrapper.cs`.

**⛔ THE ROOT CAUSE OF "RADIO REJECTS EVERYTHING": no working security unlock.**
- radiowriter `cpsUnlockRequest = 0x0100` → actually `RcmpReadIshItem` (a read command, not unlock).
- Real unlock is a 2-step handshake radiowriter LACKS:
  1. **`RcmpReadRadioKey = 0x0300`** (RcmpWrapper:11622) — bare opcode; reply returns radio key bytes.
  2. **`RcmpUnlockSecurity = 0x0301`** (RcmpWrapper:14214) — payload = the key from step 1.
- The TEA auth being correct never mattered downstream because the unlock *command* was wrong. Radio returns `SecurityLocked=6` — which radiowriter's error table can't even represent (see below). Both the XNL and XCMP agents converged on this independently.

**⛔ CRITICAL — CloneRead rests on a fabricated opcode.**
- `cloneReadRequest/Reply = 0x010A (266)` — **does not exist in CPS.** The entire `cloneRead*` subsystem (all channel/contact/zone/scanlist reads) uses an opcode CPS never sends.
- Real CPS reads codeplug data as **ISH items (`RcmpReadIshItem 0x0100`) bundled inside `XcmpSuperBundle 0x002E`** (RcmpWrapper:17556) — a completely different mechanism. This must be rebuilt.

**CRITICAL — 8 mismapped opcodes (Swift constant → what that opcode ACTUALLY is in CPS):**
| radiowriter says | opcode | CPS reality | line |
|---|---|---|---|
| securityKeyRequest | 0x0012 | RcmpReadUUID | 12205 |
| cpsUnlockRequest | 0x0100 | RcmpReadIshItem | 11220 |
| codeplugIdRequest | 0x001F | RcmpTanapaNumber | 5582 |
| codeplugAttributeRequest | 0x0025 | RcmpRemoteDisconnect | 8269 |
| statusFlagsRequest | 0x003D | XcmpSecureConnect | 17194 |
| featureSetRequest | 0x0037 | XcmpCodeplugAttribute | 15321 |
| cpsReadRequest | 0x0104 | RcmpReadIshIDSet | 10802 |
| ishSessionStart | 0x0105 | RcmpReadIshTypeSet | 11823 |

**MISSING — the real ISH/codeplug family:** `RcmpWriteIshItem 0x0101` · `RcmpDeleteIshIDs 0x0102` · `XcmpISHDeleteType 0x0103` · `RcmpReadIshIDSet 0x0104` · `RcmpReadIshTypeSet 0x0105` · `RcmpIshReorgControl 0x0107` · `RcmpIshUnlockPartition 0x0108`. Plus the 0x0300/0x0301 unlock pair above.

**LIKELY FABRICATED (defined in Swift, absent from CPS — remove/replace):** `cloneRead 0x010A`, `radioPower 0x040A`, `alarmStatus 0x042E`, `channelSelect 0x040D`, `deviceInitStatusBroadcast 0xB400`.

**MEDIUM — value tables shifted:**
- `XCMPErrorCode`: radiowriter has invalidParameter=2, reInitXNL=3, notSupported=4, busy=5. Real `RcmpReplyResult`: 2=IncorrectMode, 3=OpcodeNotSupported, 4=InvalidParameter, 5=ReplyTooBig, **6=SecurityLocked** (RcmpWrapper:3703). radiowriter can't even represent SecurityLocked — the exact error it hits. Fix the enum.
- `XCMPVersionType`: radiowriter codeplug=0x0F/codeplugCPS=0x41/bootloader=0x50 wrong. Real `VersionInfoType`: 0x41=SecurityVersion, 0x42=CodeplugVersion, 0x50=PsdtVersion (RcmpWrapper:14337). firmware=0x00 ✓.

**✅ VERIFIED MATCHING (~20):** versionInfo 0x000F · modelNumber 0x0010 · serialNumber 0x0011 · radioStatus 0x000E (+0xB00E) · languagePack 0x002C · ishProgramMode 0x0106 · psdtAccess 0x010B (+0xB10B) · radioUpdateControl 0x010C · componentRead 0x010E · componentSession 0x010F · transferData 0x0446 · moduleInfo 0x0461 · enterBootMode 0x0200 · readMemory 0x0201 · eraseFlash 0x0203. Enums PsdtAccessAction, ComponentSessionActions/Result, RadioUpdateControlAction, TransferDataType, most of XCMPStatusType — exact matches.

**FIX PRIORITY:** (1) implement 0x0300→0x0301 unlock, (2) remap the 8 wrong opcodes, (3) replace CloneRead with ISH-item-over-SuperBundle read path, (4) fix XCMPErrorCode + XCMPVersionType tables.

**CORRECTION (during fix pass):** The unlock *handshake* (read 32-byte key via 0x0300 → TEA-encrypt via `encryptRadioKey` → send as 0x0301 payload) was ALREADY implemented in `XNLConnection.initialize()`. What was wrong was the XCMP opcode *table* — `cpsUnlockRequest` pointed at 0x0100 (ReadIshItem). Both layers now share one opcode source of truth. Confirmed from source: 0x0301 sends the TEA-**encrypted** key (RcmpUnlockSecurity is a pass-through, RcmpWrapper:14278; encryption happens above the RCMP layer, and radiowriter's TEA is byte-identical to Motorola's). So the crypto + handshake were right; only the command dispatch table was wrong.

---

## FIX PASS STATUS (2026-07-06)

**✅ Write path HARD-GATED** — `writeCodeplug` throws before connect (finding C1 brick vector).
**✅ Security/opcode layer FIXED** — 8 opcodes remapped, full ISH family added (0x0100–0x0108 + 0x0300/0x0301), `XCMPErrorCode` now includes `SecurityLocked=6`, `XCMPVersionType` corrected, `ProgramModeAction` un-swapped (was a real bug). Build green.
**⏳ Read path IN PROGRESS** — replacing fabricated `cloneRead 0x010A` (26 call sites) with real ISH record walk (ReadIshTypeSet→ReadIshIDSet→ReadIshItem). Where codeplug-field→ISH-tuple mapping isn't derivable from source, building a generic enumerate-all-records dump to map types against the real radio.

**NEXT — requires live radio:** prove READ against the XPR 3500e. Success validates auth+session+unlock+framing+ISH model end-to-end. Then build ISH write path (differential `WriteIshItem`, pre-write backup). Write stays gated until read proven + user authorizes.
### CODEPLUG READ/WRITE — ⛔ WRITE PATH IS A BRICK VECTOR (now hard-gated)

**Codeplug storage is ISH (Item Storage Header) — partitioned RECORD storage, addressed by (partition, type, id, offset). NOT linear blocks.** Ground truth: `CommandHandler.cs` + `RcmpWrapper.cs` (the three transporter/sync files originally named are just DB↔object mappers — no opcodes/sockets; the "dual-session read" note is retired as a misread).

**Real ISH opcodes (RcmpWrapper.cs):** `IshProgramMode 0x106` (action byte) · `IshUnlockPartition 0x108` · `IshReorgControl 0x107` · `ReadIshItem 0x100` · `WriteIshItem 0x101` (partition,type,id,nBytes,offset,itemSize,data,writeToDual) · `ReadIshTypeSet 0x105` · `ReadIshIDSet 0x104` · `DeleteIshIDs 0x102` · `ReadRadioKey 0x300`.
`IshProgramMode.Actions`: **0=Enter, 1=ExitWithReset, 2=EnterClone, 3=ExitNoReset**, 4/5=OTAP, 6=ExitOtapChecksum.
`RcmpReplyResult`: 0=Success, 6=SecurityLocked, 16=Busy, 18=RadioIsLocked, 20=ProgramFailure, 128=FlashWriteFailure, 129=IshItemNotFound, 133=PartitionReadOnly, 134=IshReorgNeeded.

**CPS READ sequence:** auth keys → `OpenConnection(op=2)` (TEA auth + IshProgramMode Enter) → **mandatory** ValidateSerial→ValidateProductFamily→ValidatePassword (abort on fail) → `ReadDevice`: ReadIshTypeSet(261)→ReadIshIDSet(260)→ReadIshItem(256) per record → `CloseConnection` in finally. **Record walk, single session, not an address sweep.**

**CPS WRITE sequence (worker order CH 221243):** BackupReadValidateWorker (**backup + read current BEFORE write**) → MergeDataWorker → PackDataWorker (compress) → CommunicateProgramWorker (`OpenConnection(op=4)` → `WriteDevice` = per-record `WriteIshItem`, differential, dual-bank, erase inside native call) → RefreshUIWorker. **No host-side post-write read-back verify — the pre-write backup is the only recovery.**

**⛔ C1 — WRITE PATH FABRICATED (BRICK RISK). `writeCodeplug` uses opcodes 0x010F/0x010B/0x0446/0x010C that DO NOT EXIST in CPS**, with linear 512-byte-block addressing that's fundamentally wrong (CPS is partition/type/id/offset). Would fail; partial ISH partition modification **could brick the radio**. → **HARD-GATED 2026-07-06** in MOTOTRBOProgrammer.swift (throws before connect). Must be rebuilt on ISH ops before re-enabling.

**⛔ C2 — Path-C `readCodeplug` (block/PSDT read) equally fabricated** (0x010F/0x010B/0x0104 block read). The WORKING read is Path A (`readZonesAndChannels`, opcode 0x002E `XcmpSuperBundle` which IS real, RW 17817). Standardize on Path A; remove Path C read.

**⛔ C3 — `verify()` raw-byte compare is wrong model.** Uses broken Path-C read AND CPS never does host-side byte-compare (codeplug is packed/differential). Verify must be record-level via ReadIshItem, or omitted (CPS omits it).

**MODERATE:**
- **M1 — ProgramMode action byte SWAPPED.** radiowriter: enter=0x01, exit=0x00. CPS: **Enter=0, ExitWithReset=1, ExitNoReset=3.** radiowriter's "enter" (1) is actually CPS *ExitWithReset*; its "exit" (0) is actually *Enter*. Fix enum.
- **M2 — No differential write.** CPS reads→merges→writes only CHANGED records (skip-list `CpsSkippedIshTypes`). Any real write path must read-merge-write-changed, not blast the whole blob.
- **M3 — No pre-write backup.** CPS backs up before writing. Mandatory before any write is re-enabled.

**✅ SOUND, NO CHANGES:** XNL TEA auth (Path B) · record-read (Path A, opcode 0x002E real).

**CORRECTED PRIOR ASSUMPTIONS:** (1) "dual-session read" — unverified/likely misread; CPS reads single-session. (2) The three transporter/sync DLLs are data mappers, not the wire layer — the wire sequence lives in CommandHandler + RcmpWrapper.
### RUDP / TRANSPORT — ✅ FUNDAMENTALLY CORRECT

radiowriter's transport matches CPS: plain **TCP to port 8002** (wired), `TCP_NODELAY=1` (Nagle off, matches CPS `noDelay:true`), no SO_KEEPALIVE (matches CPS), no app-level retransmit (matches `MaxNumberofRetries=0`). Architecturally sound — raw TCP → XNL layering equals CPS's `TcpClientCommPipe` + `NLCommPipe(XNL_TRANSPORT)`.

**Port map (CommunicationManager.cs Constants):** PCR wired TCP = **8002** · PCR WiFi TCP = 8003 · RUDP/OTAP = 4009 · Astro WiFi = 52010.

**⚠️ KEY NEGATIVE FINDING:** RUDP (and all of `RUDPConfigParameters.xml`) is **OTAP-only** (port 4009, UDP). It does NOT wrap the wired XPR transport. **Do NOT port RUDP timeouts into XNLConnection.swift's TCP path.** The XPR wired path is plain TCP — radiowriter has this right.

**Device discovery:** CPS uses mDNS/Bonjour (DNSSDDetector) as a separate phase to find the IP, then opens a fresh TCP to 8002. radiowriter hardcodes 192.168.10.1 — fine for the known static wired IP.

**Only actionable fix — [LOW]:** `connect()` (XNLConnection.swift L156-165) is blocking with OS-default ~75s timeout. CPS clamps to 15000ms. Make connect non-blocking + `select()` bound to 15s so a dead radio fails fast. Cosmetic/UX, not correctness.

*Confirmed matching:* TCP family ✅ · port 8002 ✅ · Nagle off ✅ · no keepalive ✅ · no retransmit ✅. Nothing else to change.
