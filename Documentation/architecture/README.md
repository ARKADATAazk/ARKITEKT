# ARKITEKT Script Architecture Documentation

> **Version:** 1.0
> **Last Updated:** 2025-01-25
> **Status:** Proposal (Pre-Implementation)

This folder contains the architectural guidelines, conventions, and migration plans for ARKITEKT scripts.

## Documents

| Document | Description |
|----------|-------------|
| [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md) | **Start here.** Canonical project structure and layer definitions |
| [MIGRATION_PLANS.md](./MIGRATION_PLANS.md) | Per-script migration plans with file mappings |
| [CONVENTIONS.md](./CONVENTIONS.md) | Naming conventions, file organization rules, and patterns |

## Quick Reference

### Canonical Folder Structure

```
[ScriptName]/
├── app/              # Application bootstrap and state container
├── domain/           # Business logic (pure, no I/O)
├── infra/            # External integrations (persistence, REAPER API)
├── ui/               # Presentation layer
├── defs/             # Static definitions (constants, defaults, strings)
└── tests/            # Test files mirroring source structure
```

### Key Principles

1. **Dependency Direction**: UI → App → Domain ← Infra
2. **No `core/` folder**: Distribute to proper layers
3. **No `utils/` folder**: Use arkitekt utilities or place in appropriate layer
4. **Domain is pure**: No I/O, no UI dependencies
5. **UI state separate**: Preferences, animation go in `ui/state/`

## Terminology

| Term | Definition |
|------|------------|
| **Scaffold** | The folder/file structure template for new scripts |
| **Layer** | A logical grouping with specific responsibilities (app, domain, infra, ui) |
| **Aggregate** | A cluster of related domain objects (e.g., `playlist/` contains model, repository, service) |
| **Repository** | Abstraction for data access (CRUD operations) |
| **Service** | Business logic orchestration (use cases) |
| **Infrastructure** | External dependencies (file I/O, REAPER API, caching) |

## Migration Status

| Script | Current State | Target State | Status |
|--------|---------------|--------------|--------|
| RegionPlaylist | Mixed `core/`, `domains/` | Clean layers | Planned |
| ThemeAdjuster | Mixed `core/`, `packages/` | Clean layers | Planned |
| TemplateBrowser | Has `domain/` (closest!) | Clean layers | Planned |
| ItemPicker | Fragmented (`data/`, `services/`) | Clean layers | Planned |

---

*This documentation follows the principle: "Good architecture makes the system easy to understand, easy to develop, easy to maintain, and easy to deploy."*
