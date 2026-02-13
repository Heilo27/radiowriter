# Privacy Policy

**Effective Date:** 2026-02-02
**Last Updated:** 2026-02-02

---

## Overview

RadioWriter (the "Application") is a macOS application for programming Motorola two-way radios. This privacy policy explains how the Application handles user data.

---

## Data Collection

### What We Don't Collect

The Application does **NOT** collect, store, or transmit:

- Personal information (name, email, address, etc.)
- Usage analytics or telemetry
- Crash reports to external servers
- Location data
- Device identifiers
- Any data to third-party services

### What Stays on Your Device

All data remains entirely on your local device:

- **Codeplug files:** Radio configuration files are stored only where you choose to save them
- **Radio data:** Data read from radios stays on your computer
- **Preferences:** Application settings are stored locally using macOS standard preferences

---

## Network Connectivity

### Internet Access

The Application does **NOT** require or use internet connectivity. It operates entirely offline.

### Local Network Access

The Application communicates only with Motorola radios connected via:

- **USB:** Direct connection to radio programming cable
- **USB-Ethernet (CDC ECM):** Local connection at 192.168.10.1 for newer radios

This network traffic is local-only and does not traverse the internet.

---

## Third-Party Services

The Application uses **NO** third-party services, including:

- No analytics (Google Analytics, Mixpanel, etc.)
- No crash reporting (Crashlytics, Sentry, etc.)
- No cloud storage (iCloud, Dropbox, etc.)
- No advertising networks
- No social media integrations

---

## Data Security

### Local Data

Since all data remains on your device, security depends on your local security practices:

- Use FileVault disk encryption
- Secure codeplug files if they contain sensitive frequency/encryption information
- Control physical access to your programming computer

### Radio Communication

Communication with radios uses the Motorola XNL/XCMP protocol, which includes:

- Challenge-response authentication
- Session-based connections
- Local-only network paths (USB or direct Ethernet)

See `docs/SECURITY.md` for detailed security documentation.

---

## Children's Privacy

The Application is intended for professional and amateur radio users. It does not knowingly collect information from children under 13.

---

## Changes to This Policy

We may update this privacy policy to reflect changes in the Application. Updates will be noted with a new "Last Updated" date. Continued use of the Application constitutes acceptance of the updated policy.

---

## Open Source

RadioWriter is free and open source software, licensed under the [MIT License](../LICENSE). You can review the source code to verify these privacy claims. See [LEGAL.md](../LEGAL.md) for full legal disclaimers and [Terms of Service](TERMS_OF_SERVICE.md) for usage terms.

---

## Contact

For questions about this privacy policy or the Application:

- Review the source code
- Submit issues via the project repository

---

## Summary

**RadioWriter collects no data. Everything stays on your device. No internet required.**
