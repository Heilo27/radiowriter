# Terms of Service

**Document Version:** 1.0
**Effective Date:** 2026-02-09
**Last Updated:** 2026-02-09

---

## 1. Acceptance of Terms

By downloading, installing, copying, or otherwise using RadioWriter (the "Software"), you agree to be bound by these Terms of Service (the "Terms"). If you do not agree to these Terms, do not use the Software.

These Terms constitute a legally binding agreement between you ("User," "you," or "your") and the RadioWriter project contributors ("we," "us," or "our").

Your continued use of the Software after any modifications to these Terms constitutes acceptance of the revised Terms. It is your responsibility to review these Terms periodically.

---

## 2. Description of Service

RadioWriter is a free, open-source macOS application for programming Motorola MOTOTRBO two-way radios. The Software provides:

- **Codeplug reading and writing** — Read radio configurations (codeplugs) from connected radios, edit parameters, and write configurations back to radios
- **Codeplug editing** — Modify channel frequencies, power levels, signaling, contact lists, zone assignments, scan lists, and other radio parameters
- **Import and export** — Import and export codeplug data in CSV and other formats for backup and migration
- **Radio communication** — Connect to MOTOTRBO radios over USB using the XNL/XCMP protocol

The Software communicates only with locally connected radio hardware. It does not require or use internet connectivity. See our [Privacy Policy](PRIVACY_POLICY.md) for details on data handling.

RadioWriter is an independent project. It is **not** affiliated with, endorsed by, or supported by Motorola Solutions, Inc. See [LEGAL.md](../LEGAL.md) for the full non-affiliation statement.

---

## 3. User Responsibilities

### 3.1 Regulatory Compliance

**You are solely responsible for ensuring that all radio configurations you create, modify, or apply comply with applicable laws and regulations.**

This includes, but is not limited to:

- **FCC Part 90** — Private Land Mobile Radio Services. Commercial MOTOTRBO radios typically operate under Part 90 licenses. You must hold a valid license for the frequencies and power levels you program.
- **FCC Part 95** — Personal Radio Services (GMRS, FRS). If programming radios for Part 95 use, you must comply with power, antenna, and frequency limitations specific to the service.
- **FCC Part 97** — Amateur Radio Service. Amateur operators must comply with identification, power, band plan, and emission requirements.
- **FCC Part 80** — Maritime Radio Services. Marine channel use requires appropriate station licensing and adherence to distress and safety channel protections.
- **International regulations** — Users outside the United States must comply with their national radio authority's regulations. Frequency allocations, power limits, and licensing requirements vary by country.

### 3.2 Radio Licensing

You represent and warrant that:

- You hold all licenses and authorizations required to operate on the frequencies you program
- You understand the regulatory requirements applicable to your radio service and license class
- You will not rely on this Software to validate or enforce regulatory compliance on your behalf

### 3.3 Codeplug Responsibility

You are responsible for the contents of every codeplug you create or modify using this Software. This includes:

- Verifying that frequencies, power levels, and signaling parameters are correct and authorized
- Ensuring that emergency and safety features are configured appropriately
- Reviewing all changes before writing a codeplug to a radio

### 3.4 Backup Responsibility

You are responsible for maintaining backups of your codeplug data. Before making any changes to a radio's configuration:

- **Read and save the existing codeplug** before writing new configurations
- **Store backups** in a safe location under your control
- **Test configurations** when possible before deploying to critical-use radios

We are not responsible for lost, corrupted, or overwritten codeplug data.

---

## 4. Restrictions on Use

### 4.1 Prohibited Activities

You must NOT use this Software for:

- **Illegal radio operations** — Transmitting on frequencies you are not authorized to use, or operating without required licenses
- **Interference** — Intentionally or negligently causing harmful interference with any licensed radio service, including public safety and emergency communications
- **Exceeding authorized parameters** — Programming power levels, frequencies, or emission types beyond what your license permits
- **Circumventing licensing** — Using this Software to bypass or avoid radio licensing requirements
- **Malicious use of radio security features** — Circumventing radio authentication, encryption, or access controls for unauthorized purposes (e.g., gaining access to radio systems you do not own or have permission to configure)
- **Impersonation** — Programming radio IDs, callsigns, or other identifiers belonging to another party without authorization
- **Any activity prohibited by the Communications Act of 1934** (as amended), equivalent laws in your jurisdiction, or any applicable radio regulations

### 4.2 Hardware Limitations

This Software is designed for use with Motorola MOTOTRBO radios. You acknowledge that:

- Not all MOTOTRBO models may be supported
- Firmware versions may affect compatibility
- Using the Software with unsupported hardware is at your own risk

---

## 5. Disclaimers

### 5.1 No Guarantee of Compatibility

We do not guarantee that the Software will work with every MOTOTRBO radio model, firmware version, or configuration. Radio hardware varies, and protocol behavior may differ between models or firmware revisions.

### 5.2 No Warranty for Radio Operation

We make no warranties or representations regarding the operation of any radio programmed using this Software. Specifically:

- We do not guarantee that programmed configurations will work as expected
- We do not guarantee that the Software will not cause unintended changes to radio settings
- We do not guarantee that radios will function correctly after programming

### 5.3 Not Responsible for Regulatory Violations

We do not monitor, validate, or enforce regulatory compliance. We are not responsible for any FCC violations, fines, equipment seizures, or legal consequences resulting from your use of this Software.

### 5.4 No Professional Advice

This Software is a tool. It does not provide legal, regulatory, or technical advice. You should consult qualified professionals regarding radio licensing, regulatory compliance, and proper radio configuration for your specific use case.

### 5.5 Open-Source Software

RadioWriter is provided as free, open-source software under the [MIT License](../LICENSE). You may inspect, modify, and redistribute the source code subject to the license terms.

---

## 6. Limitation of Liability

**THIS SOFTWARE IS PROVIDED "AS IS," WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT.**

**IN NO EVENT SHALL THE AUTHORS, CONTRIBUTORS, OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.**

Without limiting the foregoing, we shall not be liable for:

- **Equipment damage** — Any damage to radio hardware, programming cables, computers, or other equipment resulting from the use of this Software
- **Data loss** — Loss or corruption of codeplug data, radio configurations, or any other data
- **Regulatory penalties** — Fines, penalties, equipment seizures, license revocations, or criminal prosecution resulting from improper radio programming
- **Interference** — Harmful interference with any radio service caused by configurations created with this Software
- **Operational failures** — Radio malfunction, communication failures, or inability to transmit or receive during critical operations
- **Third-party claims** — Any claims by third parties arising from your use of this Software

**You use this Software entirely at your own risk.**

---

## 7. Intellectual Property

### 7.1 RadioWriter

RadioWriter is free, open-source software licensed under the [MIT License](../LICENSE). The source code is the original work of the project contributors, developed using clean-room reverse engineering methodology. See [LEGAL.md](../LEGAL.md) for details on clean-room practices and information sources.

### 7.2 Motorola Trademarks

MOTOROLA, MOTOTRBO, XPR, and other Motorola product names and designations are registered trademarks or trademarks of Motorola Solutions, Inc. or Motorola Trademark Holdings, LLC. Use of these marks in this Software and its documentation is for identification and reference purposes only and does not imply affiliation with or endorsement by Motorola Solutions.

### 7.3 Third-Party Code

This project references or incorporates code from the following open-source projects:

| Component | License |
|-----------|---------|
| [Moto.Net](https://github.com/pboyd04/Moto.Net) | Apache-2.0 |
| [codeplug](https://github.com/george-hopkins/codeplug) | MIT |

See [LEGAL.md](../LEGAL.md) for full third-party license information and clean-room methodology.

### 7.4 Your Content

You retain ownership of all codeplug data, configurations, and other content you create using this Software. We claim no rights to your data.

---

## 8. Modifications to Terms

We reserve the right to modify these Terms at any time. Changes will be reflected by an updated "Last Updated" date at the top of this document.

Material changes will be communicated through:

- Updated documentation in the project repository
- Release notes accompanying the version that includes the change

Your continued use of the Software after changes to these Terms constitutes acceptance of the revised Terms. If you do not agree to the revised Terms, you must stop using the Software.

We encourage you to review these Terms periodically.

---

## 9. Governing Law and Disputes

### 9.1 Governing Law

These Terms shall be governed by and construed in accordance with the laws of the State of Delaware, United States, without regard to its conflict of law provisions.

### 9.2 Dispute Resolution

Any dispute arising from or relating to these Terms or the use of this Software shall be resolved as follows:

1. **Informal resolution** — The parties shall first attempt to resolve the dispute through good-faith communication via the project's issue tracker
2. **Binding arbitration** — If informal resolution fails, disputes shall be resolved by binding arbitration administered by the American Arbitration Association under its Consumer Arbitration Rules
3. **Individual basis** — All disputes shall be resolved on an individual basis. You waive any right to participate in a class action or class-wide arbitration

### 9.3 Limitation Period

Any claim arising from these Terms or your use of the Software must be brought within one (1) year of the date the cause of action arises.

---

## Related Documents

- [Privacy Policy](PRIVACY_POLICY.md) — How the Software handles your data
- [LEGAL.md](../LEGAL.md) — Legal disclaimers, reverse engineering compliance, regulatory details, and clean-room methodology
- [LICENSE](../LICENSE) — MIT License (full text)

---

## Contact

For questions about these Terms:

- Submit an issue through the project repository
- Review the source code and documentation

---

## Summary

**RadioWriter is free, open-source software provided AS IS. You are solely responsible for regulatory compliance and proper radio configuration. Use at your own risk.**

---

*This document does not constitute legal advice. Consult qualified legal counsel regarding your specific situation and jurisdiction.*
