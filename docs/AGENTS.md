<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-01-28 -->

# docs

## Purpose

The `docs/` directory contains project-level documentation for NetMonitor, including API specifications, product requirements, phase completion records, design guidelines, and implementation plans. This is the single source of truth for understanding the project scope, architecture decisions, and technical specifications.

**Key Audience**: Developers implementing features, designers reviewing UI/UX decisions, new team members onboarding to the project.

---

## Key Files

| File | Description |
|------|-------------|
| **Companion-Protocol-API.md** | Complete TCP/Bonjour protocol specification for iOS/iPadOS companion app integration. Covers service discovery, message format, JSON payloads, command types, and implementation examples. |
| **NetMonitor for macOS - Product Requirements Document.md** | Product vision, user requirements, technical stack decisions, feature matrix, and acceptance criteria for v1.0. Authoritative source for product scope. |
| **PHASE1-COMPLETE.md** | Completion report for Phase 1 Foundation (2026-01-11). Documents 8 completed tasks, code review scores (9.35/10), critical issues found/fixed, and approval for Phase 2. |
| **SwiftUI Best Practices.md** | Standards for modern iOS 18+ / macOS 15+ development. Covers @Observable patterns (not Combine), SwiftData best practices, Swift 6 strict concurrency, and state management. Training document for team. |

---

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| **plans/** | Implementation plans for 4 development phases (Phase 1-4). Each phase document contains requirements, task breakdown, architecture decisions, and acceptance criteria. Used for sprint planning and architectural guidance. |
| **screenshots/** | Visual documentation of completed UI features. Phase 1 screenshots demonstrate navigation structure, dark theme, and visual polish. |

---

## For AI Agents

### Working In This Directory

**READ-ONLY OPERATIONS** (Safe):
- Read any `.md` file to understand requirements, architecture, or decisions
- Extract information for architecture docs, README files, or implementation guidance
- Reference phase plans when understanding what has been completed
- Cross-reference with root CLAUDE.md for project conventions

**WRITE OPERATIONS** (Allowed with guidance):
- Update `PHASE*-COMPLETE.md` files with completion reports after major phase milestones
- Add new phase plan documents (follow naming: `YYYY-MM-DD-phase{N}-{title}.md`)
- Add screenshots to `screenshots/` directory with accompanying README updates
- Update this file to reflect new documentation added

**DO NOT**:
- Delete phase plans (they are historical record of architecture decisions)
- Modify existing API specifications without architect review
- Overwrite PRD without stakeholder approval

### Common Patterns

#### Reading Architecture Context
When implementing features, check in this order:
1. **PRD** (`NetMonitor for macOS - Product Requirements Document.md`) — what are we building?
2. **Active Phase Plan** (`plans/2026-01-XX-phase*.md`) — what's the implementation strategy?
3. **Phase Completion Reports** (`PHASE*-COMPLETE.md`) — what was actually delivered and why?
4. **Companion Protocol** (`Companion-Protocol-API.md`) — if implementing companion app features

#### Documenting Decisions
- Phase completion → Create `PHASEX-COMPLETE.md` with scores, issues found, and approval status
- New API endpoint → Update `Companion-Protocol-API.md` with examples and breaking changes
- New development standard → Update `SwiftUI Best Practices.md` with examples and context
- Architecture change → Add summary to active phase plan's "Architecture Decisions" section

#### Phase Plan Structure
Phase plans follow this template:
- **Overview**: Goal and success criteria
- **Prerequisites**: Phase dependencies
- **Architecture**: Technical approach and design patterns
- **Phase Tasks**: Numbered with subtasks and acceptance criteria
- **Testing Strategy**: How to verify completion
- **Deployment Notes**: Special considerations for release

---

## Dependencies

### Internal References
- **Root CLAUDE.md** — Project conventions, file naming, code style, git workflow
- **Root AGENTS.md** — Codebase architecture and agent navigation hierarchy
- **NetMonitor/ folder** — Source code corresponding to documented features
- **NetMonitorTests/ folder** — Test implementations validating phase requirements

### External References
- **Network.framework** — Foundation for companion protocol and network monitoring
- **SwiftData** — Persistence layer for all models documented in PRD
- **Swift 6 Concurrency** — Actor-based architecture referenced in phase plans
- **macOS 15.0+ APIs** — Platform capabilities assumed in requirements

### Documentation Synchronization
When source code changes, these docs must be updated:
1. **New service added** → Phase plan's "Architecture" section
2. **API endpoint changed** → Companion-Protocol-API.md with migration notes
3. **Model structure changed** → PRD's "Data Model" section
4. **UI pattern established** → SwiftUI Best Practices.md with example
5. **Phase completed** → Create PHASE*-COMPLETE.md report

---

## Phase Overview

| Phase | Status | Completion | Key Deliverables |
|-------|--------|------------|------------------|
| **Phase 1: Foundation** | ✅ COMPLETE | 2026-01-11 | SwiftData models, UI shell, accessibility IDs |
| **Phase 2: Monitoring Engine** | ✅ COMPLETE | 2026-01-13 | HTTPMonitorService, TCPMonitorService, MonitoringSession |
| **Phase 3: Discovery & Companion** | ✅ COMPLETE | 2026-01-17 | ARPScannerService, BonjourDiscoveryService, CompanionService |
| **Phase 4: Tools & Settings** | ✅ COMPLETE | 2026-01-24 | 7 network tools, 7 settings views, ShellCommandRunner |

---

## Quick Navigation

**For implementation questions:**
→ See active phase plan in `plans/` directory

**For API integration (companion app):**
→ Read `Companion-Protocol-API.md`

**For understanding product scope:**
→ Read PRD: `NetMonitor for macOS - Product Requirements Document.md`

**For code style and architecture patterns:**
→ Read `SwiftUI Best Practices.md`

**For phase status and issues resolved:**
→ Read latest `PHASE*-COMPLETE.md`

---

<!-- MANUAL: Update this section when adding new documentation -->

**Last Updated**: 2026-01-28
**Maintained By**: Development Team
**Sync Status**: ✅ In sync with source code (Phase 4 complete)
