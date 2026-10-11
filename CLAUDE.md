# radiowriter
Native macOS app to read/write Motorola MOTOTRBO codeplugs without the Windows-only CPS.
Stack: Swift, Xcode, USB serial
Rules:
- A bad codeplug can brick a radio; protocol handling must be exact.
- Protocol is reverse-engineered; no official Motorola libraries.
- Test on a non-operational radio first.
- Overlaps MotorolaCPS; check which is active before starting.
Docs: docs/PROTOCOL_REFERENCE.md, docs/protocols/, LEGAL.md.
