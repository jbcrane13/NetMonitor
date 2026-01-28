<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-28 | Updated: 2026-01-28 -->

# Sources

## Purpose

Container directory for Swift Package module sources following standard SPM (Swift Package Manager) structure.

## Structure

```
Sources/
└── NetMonitorShared/           # Main module target
    ├── Protocol/               # Message protocol definitions
    │   └── CompanionMessage.swift
    └── Common/                 # Shared enumerations
        └── Enums.swift
```

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `NetMonitorShared/` | Shared protocol and enum definitions for companion app communication (see `NetMonitorShared/AGENTS.md`) |

## Module Contents

### NetMonitorShared

The primary Swift module providing shared types between macOS app and iOS companion app.

**Key Files:**
- `Protocol/CompanionMessage.swift` - Message types for companion app protocol
- `Common/Enums.swift` - Shared enumerations (TargetProtocol, DeviceType, ConnectionType)

**Visibility:** Public types exported from module for use by consuming targets

## For AI Agents

### Working In This Directory

- **Do not add files directly here** - files must be added to the `NetMonitorShared/` subdirectory
- Each subdirectory in `Sources/` corresponds to a Swift module target
- Only the `NetMonitorShared/` module is currently defined in Package.swift
- All types added must be marked `public` to be exported from the module

### Common Tasks

1. **Add to protocol definitions**: Place in `NetMonitorShared/Protocol/`
2. **Add shared enums**: Place in `NetMonitorShared/Common/`
3. **Export new types**: Update `public` visibility and ensure imported in consuming targets

### Navigation

- Parent documentation: See `../AGENTS.md`
- Module details: See `NetMonitorShared/AGENTS.md`
- For protocol specifics: See `NetMonitorShared/Protocol/CompanionMessage.swift`

<!-- MANUAL: -->
