# radiowriter — Friday Context

## What This Is
Native macOS app for programming Motorola MOTOTRBO radios. Read/write codeplug configurations without Motorola's Windows-only CPS software.

## Stack
Swift · Xcode · macOS · USB serial

## Critical Rules
- Incorrect codeplugs can brick radios — protocol handling must be exact
- All protocol handling is reverse-engineered; no official Motorola libraries
- Test on non-operational radio before production use
- Related to MotorolaCPS — check which is active before starting work

## Ticketmaster ID
`radiowriter`
