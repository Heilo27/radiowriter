# Legal Disclaimer

**Document Version:** 1.1
**Effective Date:** 2026-02-05
**Last Updated:** 2026-02-06

---

## License

This project is licensed under the **MIT License**. See [`LICENSE`](LICENSE) for the full license text.

The MIT License was chosen because:
- It is a permissive, OSI-approved open-source license
- It is compatible with all third-party dependencies (Apache-2.0, MIT)
- No GPL-licensed code is incorporated (see `docs/GPL_COMPLIANCE_AUDIT.md`)
- It aligns with the project's stated goal of being free and open source

**Source file headers:** Per-file license headers are omitted. The MIT License does not require them, and the top-level `LICENSE` file applies to all original source files in this repository. Third-party code in `Moto.Net/` and `codeplug/` retains its own licensing.

---

## Purpose Statement

This project ("RadioWriter" or "MotorolaCPS") is an independent, open-source effort to create a native macOS application for programming Motorola MOTOTRBO two-way radios. The project exists for the following legitimate purposes:

1. **Interoperability** - Enable users to program their legitimately-owned radio equipment from macOS, a platform for which Motorola does not provide official Customer Programming Software (CPS).

2. **Educational Research** - Document the XNL/XCMP communication protocols used by MOTOTRBO radios for academic and research purposes.

3. **Platform Access** - Provide an alternative for users who cannot run the Windows-only Motorola CPS software.

This project does not exist to circumvent licensing, enable unauthorized radio use, or facilitate any illegal activity.

---

## Legal Basis for Reverse Engineering

### United States - DMCA Section 1201(f)

The reverse engineering conducted in this project is protected under the Digital Millennium Copyright Act, specifically Section 1201(f), which states:

> "A person who has lawfully obtained the right to use a copy of a computer program may circumvent a technological measure that effectively controls access to a particular portion of that program for the sole purpose of identifying and analyzing those elements of the program that are necessary to achieve interoperability of an independently created computer program with other programs."

**Key elements satisfied:**

- The protocol analysis targets **interoperability** with legitimately owned radio hardware
- No copy protection mechanisms are circumvented for the purpose of copying protected content
- The work enables an independently created program (this application) to interoperate with existing hardware

### European Union - Directive 2009/24/EC

For users and contributors in the European Union, this work is protected under Article 6 of Directive 2009/24/EC on the legal protection of computer programs:

> "The authorisation of the rightholder shall not be required where reproduction of the code and translation of its form... are indispensable to obtain the information necessary to achieve the interoperability of an independently created computer program with other programs."

**Conditions met:**

- The acts are performed by a person having a right to use a copy of the program (radio owners)
- Information necessary for interoperability has not previously been made readily available
- The acts are confined to the parts necessary for interoperability

### Additional Jurisdictions

Similar interoperability exceptions exist in:

- **Australia** - Copyright Act 1968, Section 47D
- **Canada** - Copyright Act, Section 30.6
- **Japan** - Copyright Act, Article 20
- **United Kingdom** - Copyright, Designs and Patents Act 1988, Section 50B

Users should consult local legal counsel regarding the applicability of interoperability exceptions in their jurisdiction.

---

## Clean-Room Methodology

This project employs clean-room reverse engineering practices to document the MOTOTRBO communication protocols:

### Information Sources

Protocol information was derived exclusively from:

1. **Open-Source Projects** - Existing open-source implementations published under permissive licenses:
   - [Moto.Net](https://github.com/pboyd04/Moto.Net) (MIT License) - C# implementation
   - [xcmp-xnl-dissector](https://github.com/george-hopkins/xcmp-xnl-dissector) - Wireshark dissector
   - [codeplug](https://github.com/george-hopkins/codeplug) - Python codeplug tools

2. **Network Traffic Analysis** - Observation of protocol behavior using standard network analysis tools (Wireshark) on traffic between legitimately-owned radios and software.

3. **Published Documentation** - Publicly available technical references and amateur radio community documentation.

### What Is NOT Included

This project explicitly does NOT:

- Redistribute any Motorola binaries, libraries, or object code
- Include any decompiled Motorola source code
- Contain proprietary encryption constants or keys
- Distribute the `XnlAuthenticationDotNet.dll` or any Motorola DLLs
- Copy or adapt code from Motorola CPS software

### Implementation Approach

All code in this project is:

- Written from scratch in Swift based on protocol documentation
- Developed without access to Motorola CPS source code
- Created using only publicly available protocol specifications
- Licensed under open-source terms

---

## Trademark Disclaimers

The following trademarks are the property of their respective owners:

- **MOTOROLA** is a registered trademark of Motorola Trademark Holdings, LLC
- **MOTOTRBO** is a trademark of Motorola Solutions, Inc.
- **XPR**, **SL**, **DP**, and other radio model designations are trademarks of Motorola Solutions, Inc.
- **Apple**, **macOS**, **Swift**, and **Xcode** are trademarks of Apple Inc.

Use of these trademarks in this project is for identification and reference purposes only and does not imply any affiliation with or endorsement by the trademark holders.

---

## Non-Affiliation Statement

**This project is NOT affiliated with, endorsed by, sponsored by, or approved by Motorola Solutions, Inc. or any of its subsidiaries.**

This is an independent, community-driven project. The developers have no relationship with Motorola Solutions other than as users of Motorola radio equipment.

Motorola Solutions is not responsible for this software, does not provide support for it, and has not reviewed or approved its functionality or safety.

---

## Regulatory Compliance

**Programming two-way radios carries significant regulatory obligations. Users of this software are solely responsible for compliance with all applicable radio regulations.**

### United States — FCC Regulations

- **Part 90** — Private Land Mobile Radio Services. Commercial MOTOTRBO radios typically operate under Part 90 licenses. Programming frequencies, power levels, or identifiers outside your license authority is a federal violation.
- **Part 95** — Personal Radio Services (GMRS, FRS). Certain MOTOTRBO models may operate on Part 95 frequencies. FRS radios have strict power and antenna limits that must not be exceeded.
- **Part 97** — Amateur Radio Service. Amateur licensees may use modified radios on amateur frequencies but must comply with identification, power, and band plan requirements.
- **Part 80** — Maritime Radio Services. Some MOTOTRBO radios support marine channels. Maritime use requires appropriate station licensing and adherence to distress/safety channel protections.

### International Regulations

Users outside the United States must comply with their national radio authority's regulations. Radio frequency allocations, power limits, and licensing requirements vary by country. It is the user's responsibility to determine and comply with applicable regulations before transmitting.

### Specific Warnings

1. **Never transmit on frequencies you are not authorized to use.** Unauthorized transmission can interfere with public safety communications and is a criminal offense in most jurisdictions.
2. **Do not exceed authorized power levels.** Over-power operation causes harmful interference and violates license conditions.
3. **Do not disable or modify emergency signaling features** unless you fully understand the consequences and have appropriate authorization.
4. **Maintain proper radio identification** as required by your license type (callsigns, radio IDs, color codes).
5. **Encryption usage** may be restricted or prohibited depending on your license class and jurisdiction. Amateur radio operators in the US are generally prohibited from using encryption (47 CFR § 97.113).

### User Acknowledgment

By using this software, you acknowledge that:

- You hold appropriate radio licenses for the frequencies and services you intend to use
- You are solely responsible for ensuring all radio configurations comply with applicable regulations
- The developers of this software cannot verify your licensing status or the legality of your configurations
- Improper radio programming can result in regulatory penalties, equipment seizure, or criminal prosecution

---

## No Proprietary Code

This project contains no proprietary Motorola software, including:

- No Motorola Customer Programming Software (CPS) code
- No Motorola TUNER application code
- No Motorola firmware
- No Motorola libraries or DLLs
- No Motorola encryption keys or constants
- No content extracted from Motorola installers

All protocol implementations are original works based on observation and documentation of publicly-known protocol behaviors.

### Encryption and Authentication Information

This project documents the structure of the XNL authentication protocol **solely for interoperability purposes** as permitted under DMCA Section 1201(f) and EU Directive 2009/24/EC. Any cryptographic protocol documentation exists exclusively to enable an independently created program to communicate with legitimately owned radio hardware.

This project does NOT include the proprietary encryption constants required for full CPS-level authentication. Users who require CPS-level radio access must obtain appropriate licensing from Motorola Solutions.

No encryption keys, constants, or secrets extracted from Motorola software are distributed with this project. Protocol documentation describes message structure and authentication flows without exposing proprietary key material.

---

## Warranty Disclaimer

**THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT.**

**IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.**

### Specific Warnings

1. **Radio Equipment** - Improper radio programming can render equipment inoperable, violate FCC regulations, or cause interference with emergency communications. Use at your own risk.

2. **Regulatory Compliance** - Users are solely responsible for ensuring their radio configurations comply with all applicable FCC, Industry Canada, or other regulatory requirements.

3. **No Support** - This project is provided without support. The developers are not responsible for assisting with radio configuration or recovery.

4. **Data Loss** - Always backup codeplug data before modifying radio configurations. The developers are not responsible for lost configurations.

5. **Equipment Damage** - While this software is designed to follow proper protocol specifications, the developers cannot guarantee it will not damage radio equipment.

---

## Permitted Uses

This software is intended for:

- Programming radios you legally own or are authorized to program
- Educational research into radio communication protocols
- Amateur radio experimentation within applicable regulations
- Emergency preparedness and CERT/ARES operations
- Business operations with properly licensed radio equipment

---

## Prohibited Uses

This software must NOT be used for:

- Unauthorized access to radio systems you do not own or have permission to access
- Interference with public safety or emergency communications
- Circumventing radio licensing requirements
- Programming radios for illegal transmission activities
- Any activity prohibited by the Communications Act of 1934 or equivalent laws

---

## Responsible Disclosure

If you discover security vulnerabilities in MOTOTRBO radio systems during the course of using or contributing to this project, please follow responsible disclosure practices:

1. Do not publicly disclose vulnerabilities that could endanger public safety communications
2. Report serious security issues to Motorola Solutions through their official security channels
3. Allow reasonable time for remediation before any public disclosure
4. Consider the safety implications of radio communication vulnerabilities

---

## Contributing — Clean-Room Requirements

Contributors to this project must follow clean-room practices to maintain the legal integrity of this work.

### Contributor Agreement

By submitting contributions, you represent and warrant that:

1. Your contributions are **original work** or derived from properly licensed open-source code
2. You have **not** viewed, decompiled, or reverse-engineered Motorola CPS source code for the purpose of writing your contribution
3. You will **not** submit any proprietary Motorola code, data, encryption keys, or constants
4. You understand and accept this legal disclaimer in its entirety
5. You agree to license your contributions under the same terms as this project (MIT License)

### Clean-Room Practices

To maintain clean-room integrity, contributors must:

- **Use only approved information sources:** Open-source implementations (with compatible licenses), published protocol documentation, network traffic captures from legitimately owned equipment, and publicly available technical references
- **Never copy code** from decompiled Motorola binaries. If you have previously viewed decompiled CPS code, do not contribute to areas where that knowledge could influence your implementation
- **Document your sources.** When implementing protocol behavior, note where the information came from (e.g., "Observed via Wireshark capture" or "Derived from Moto.Net MIT-licensed implementation")
- **Separate analysis from implementation.** If you are conducting binary analysis, do not simultaneously write implementation code for the same component. Findings should be documented first, then a separate implementation effort should follow
- **Flag uncertainty.** If you are unsure whether information is publicly available or proprietary, ask before including it

### What NOT to Contribute

Do not submit:

- Code extracted or adapted from Motorola CPS, TUNER, or firmware binaries
- Proprietary encryption keys, authentication constants, or seed values
- Motorola firmware images, DLL files, or binary assets
- Screenshots or excerpts from Motorola's proprietary documentation
- Information obtained under NDA with Motorola Solutions

---

## Contact

For legal inquiries related to this project, please submit an issue through the project repository.

---

## Acknowledgments

This project builds upon the work of the open-source community, including:

- The Moto.Net project contributors (MIT License)
- The xcmp-xnl-dissector project contributors
- The codeplug project contributors
- The amateur radio community's protocol documentation efforts

---

## Summary

**RadioWriter is an independent, clean-room implementation for MOTOTRBO radio interoperability. It is not affiliated with Motorola Solutions. It contains no proprietary code. Use at your own risk.**

See also: [Terms of Service](docs/TERMS_OF_SERVICE.md) | [Privacy Policy](docs/PRIVACY_POLICY.md)

---

*This document does not constitute legal advice. Users should consult qualified legal counsel regarding their specific situation and jurisdiction.*
