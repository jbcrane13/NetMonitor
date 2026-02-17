# NetMonitor 2.0 Plan — Review Consensus

**Date:** February 16, 2026
**Reviewers:** Gemini 2.5 Pro, GPT-5.2 Pro, Daneel (synthesis)
**Document reviewed:** `docs/NETMONITOR-2.0-SHARED-CODEBASE-PLAN.md`

---

## Verdict: Plan is directionally correct, needs 6 adjustments before execution

Both reviewers agree the core idea — expand `NetMonitorShared` with shared models, protocols, and cross-platform services — is sound. The division of what to share vs. keep separate is largely correct. Both found the same set of issues.

---

## Consensus Changes (all three agree)

### 1. Split `NetMonitorShared` into multiple SPM targets ✅
**Both reviewers flagged this.** A single target will become a god module.

**Action:** Structure the package as:
```
NetMonitorShared/
├── NetMonitorCore        # Foundation-only models, enums, utilities, IPv4Helpers
├── NetMonitorMessaging   # CompanionMessage + codec + framing + golden tests
├── NetMonitorScanCore    # ConnectionBudget, ScanAccumulator (no UI strings)
├── NetMonitorServices    # PortScan, SpeedTest, WOL, NetworkMonitor (imports Network)
└── NetMonitorTestSupport # Contract test helpers for protocol conformance
```
Layering rules: Core can't import Network. Services can't import SwiftUI.

### 2. Fix `PingResult` semantic mismatch before sharing ✅
**Both reviewers caught this independently.** macOS `PingResult` = aggregate statistics. iOS `PingResult` = per-sequence sample. They're different types wearing the same name.

**Action:** Define in shared:
- `PingSample` — per-attempt result (sequence, latency, success, method)
- `PingStatistics` — aggregate (min/avg/max/stddev, packet loss)
- `PingMethod` enum — `.icmp` | `.tcpHandshake` (so UI can label accuracy)
- Move `calculateStatistics()` into shared as pure function

### 3. CompanionMessage needs codec + framing + golden tests ✅
**GPT-5.2 was emphatic, Gemini mentioned it under "error handling."** The shared file only has the Codable enum. The framing layer (length prefix, endian, max size, streaming decode) is where the 1.0 bugs were.

**Action (Phase 0 / early Phase 1):**
- Add `CompanionMessageCodec` to shared: JSON encoder/decoder config, frame format, streaming decode
- Add tolerance for unknown message types (`.unknown(type:String)` instead of throwing)
- Add protocol version negotiation (real versioned handshake, not hardcoded `"1.0"`)
- Write golden byte-sequence tests capturing the wire format

### 4. Move `ConnectionBudget` / ScanCore BEFORE shared services ✅
**Both reviewers flagged the ordering.** Services like PortScan and SpeedTest use many concurrent connections. Without shared throttling in place first, you'll get thermal regressions or connection storms.

**Action:** Reorder phases:
- Phase 1: Models + Protocols + CompanionMessage codec
- Phase 2: ScanCore promotion (ConnectionBudget, throttling, IPv4Helpers)
- Phase 3: Direct-share services (now with throttling available)
- Phase 4: Protocol-based platform-divergent services
- Phase 5: Cleanup + testing

Phases 2 and 3 should **not** run in parallel (contra original plan).

### 5. Remove `@MainActor` from shared service protocols ✅
**Gemini was explicit.** The iOS service protocols are littered with `@MainActor` because they were designed as view-model bindings. That's wrong for a shared service layer.

**Action:** Shared protocols should be operation-focused (async functions, AsyncStreams). Platform apps build thin `@MainActor` adapters/view-models on top. This also fixes testability.

### 6. Upgrade risk ratings ✅
**Both reviewers agreed these were understated:**

| Risk | Original | Revised |
|------|----------|---------|
| Model unification breaks serialization | Medium | **High** |
| Performance regression on iOS scan | Low | **Medium** |

**New risks to add:**
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Wire protocol version incompatibility | Medium | High | Unknown message tolerance, version negotiation, golden frame tests |
| Privacy/permission prompt regressions | Low | High | Explicit Info.plist checklist, first-launch behavior tests |
| SPM/Xcode integration friction | Medium | Medium | Decide repo strategy first, set up CI before refactors |
| Shared module becomes dumping ground | Medium | Medium | Multi-target layering rules, code review gates |
| `ProcessPingService` streaming refactor underestimated | High | Medium | Prototype early in Phase 4 |

---

## Disagreements (reviewers differed)

### Repo Strategy
- **Gemini:** Agrees with plan — Option B (local refs) → Option A (submodule). Avoid monorepo.
- **GPT-5.2:** Strongly recommends **Option C (monorepo)** during migration for atomic cross-platform PRs. Calls submodules "the sharpest tool — they cut teams."

**Daneel's take:** GPT-5.2 has the stronger argument here. During active migration, you want atomic commits that touch shared + both apps. Monorepo makes that trivial; multi-repo makes it painful. **Recommend monorepo for the migration phase.** Can always split later if needed (splitting is easier than merging). If Blake vetoes monorepo, use GPT-5.2's "Option D": separate repo with SPM URL dependency + local overrides for dev.

### ScanKit Promotion Scope
- **Gemini:** Promote wholesale into shared. Major strategic win.
- **GPT-5.2:** Only promote `ConnectionBudget`, accumulation logic, and IP math. Don't promote iOS-specific pipeline/phases/heuristics — macOS won't adopt them cleanly.

**Daneel's take:** GPT-5.2 is right that the full `ScanPipeline` has iOS-specific assumptions. But Gemini is right that the *concept* of shared scan orchestration is valuable. **Compromise: promote the primitives (`ConnectionBudget`, `ScanAccumulator`, `IPv4Helpers`, `ThermalThrottleMonitor`) into `NetMonitorScanCore`. Define a shared `DeviceProbe` protocol. Keep platform-specific pipelines in each app.**

### MACVendorLookupService DB bundling
- **GPT-5.2:** Split into shared interface + separate optional `MACVendorLookupDB` target to avoid bloating iOS binary.
- **Gemini:** Just merge and share.

**Daneel's take:** GPT-5.2's split is cleaner. The OUI database is ~3MB and iOS currently uses a 66-line network-only lookup. No reason to force the embedded DB on iOS.

---

## Additional Recommendations (from individual reviews)

### From Gemini (not covered above):
- **Unified error handling:** Define `NetMonitorError` enum in shared. All services throw/return this type.
- **Logging protocol:** Define `LoggerProtocol` in shared, implementations provide `os.Logger` wiring.
- **Localization:** Shared package needs its own `en.lproj` bundle for any displayable strings.
- **Move iOS-only tool protocols to shared:** Even if macOS doesn't implement DNS/WHOIS yet, having the protocols in shared prepares the architecture.
- **DI mechanism:** Define a `PlatformServices` container initialized at launch.

### From GPT-5.2 (not covered above):
- **Units consistency:** Decide once — store as `TimeInterval` (seconds) in models, convert for display in UI. Both codebases currently mix ms and seconds.
- **Per-run cancellation handles:** `func startPing(...) -> PingRun` with scoped cancel, not global `stop()`.
- **`AsyncThrowingStream` over `AsyncStream`:** Allows expressing failures (macOS shell errors, permission denials).
- **Don't paper over method differences:** iOS "ping" is TCP, macOS is ICMP. UI should label this honestly.

---

## Revised Phase Plan

| Phase | What | Duration | Exit Criteria |
|-------|------|----------|---------------|
| **0** | CompanionMessage codec + golden tests + unknown-type tolerance | 1 day | Wire format tests pass, both apps import shared CompanionMessage |
| **1** | Shared models (`PingSample`/`PingStatistics`/`TracerouteHop`/`PortScanResult`/etc) + service protocols (operation-focused, no `@MainActor`) | 2 days | Both apps compile against shared models via typealias bridge |
| **2** | ScanCore promotion (`ConnectionBudget`, `ScanAccumulator`, `IPv4Helpers`, `ThermalThrottleMonitor`) | 1 day | iOS scan produces same results using shared ScanCore |
| **3** | Direct-share services (PortScan, SpeedTest, WOL, NetworkMonitor, MACVendor) | 2 days | Both apps use shared implementations, tool-by-tool QA passes |
| **4** | Protocol-based services (Ping, Traceroute, Bonjour, DeviceDiscovery) + DI wiring | 3 days | All tools work on both platforms via protocol injection |
| **5** | Cleanup, testing (>60% coverage on shared), docs, ADR | 2 days | Clean builds, test suite green, architecture docs updated |
| **Total** | | **~11 days** | |

---

## Open Decisions for Blake

1. **Monorepo or multi-repo?** — Both reviewers lean monorepo for the migration. Your call.
2. **Is 11 days the right scope?** — Could do Phase 0-1 first as a "proof of concept" week, then continue.
3. **Start on `2.0-refactor` branch (macOS already has one) or fresh branches?**
4. **iOS deployment target stays `.iOS(.v18)` for 2.0?**

---

*Reviews stored at `/tmp/gemini-review.txt` and `/tmp/oracle-review.txt` for reference.*
