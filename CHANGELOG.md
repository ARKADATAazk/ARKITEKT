# Changelog

All notable changes to the ARKITEKT project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- LICENSE file (GPL-3.0)
- CONTRIBUTING.md with project guidelines
- CHANGELOG.md for tracking version history

### Changed
- Project structure audit completed
- Prepared for `arkitekt` → `arkitekt` migration

## [0.2.0] - 2025-01-19

### Added
- Centralized `constants.lua` as single source of truth for framework defaults
- `DOCS_CONFIG_BEST_PRACTICES.md` documenting configuration merge patterns
- Enhanced ItemPicker with virtual list mode for 1000+ items
- Improved ThemeAdjuster functionality
- MCP server integration support and documentation

### Fixed
- Config merge precedence issues (documented in best practices)
- ItemPicker grid virtual mode toggle
- MCP checkbox behavior

### Changed
- Refactored configuration system (see `REFACTORING_SUMMARY.md`)
- Updated framework constants to centralized file
- Improved theme system organization

### Deprecated
- Old ThemeAdjuster implementation (moved to `(old)/` directory)
- Multiple config merge patterns (consolidating to single pattern)

## [0.1.0] - 2024-XX-XX

### Added
- Initial Arkitekt framework implementation
- Core widget library (15+ widget categories)
- Example applications:
  - ColorPalette - Color management tool
  - RegionPlaylist - Region-based playlist manager
  - ItemPicker - Audio/MIDI item browser
  - TemplateBrowser - Template selection tool
  - ThemeAdjuster - REAPER theme customization
- Theme system (dark, light, auto-detect)
- ReaImGui integration layer
- Comprehensive documentation

### Core Components
- `arkitekt/core/` - Core services (colors, config, settings, json, uuid, undo)
- `arkitekt/gui/widgets/` - Reusable widget library
- `arkitekt/gui/fx/` - Animations and effects
- `arkitekt/app/` - Application shell and chrome
- `arkitekt/themes/` - Theme presets

### Infrastructure
- GitHub Actions CI/CD workflows
- VSCode Lua development environment
- ReaPack integration for distribution
- Project structure documentation

---

## Version Guidelines

### Version Format: MAJOR.MINOR.PATCH

- **MAJOR**: Breaking API changes, incompatible with previous versions
- **MINOR**: New features, backward-compatible additions
- **PATCH**: Bug fixes, backward-compatible fixes

### Change Categories

- **Added**: New features or capabilities
- **Changed**: Changes to existing functionality
- **Deprecated**: Features marked for removal in future versions
- **Removed**: Features removed in this version
- **Fixed**: Bug fixes
- **Security**: Security vulnerability fixes

### Breaking Changes

Breaking changes will be clearly marked with `BREAKING:` prefix:

```
### Changed
- BREAKING: Renamed `arkitekt` module to `arkitekt` - all require() paths must update
```

### Upgrade Notes

When upgrading between versions, check for:
1. **Breaking Changes** section - action required
2. **Deprecated** section - update soon to avoid future breaks
3. **Changed** section - verify behavior matches expectations

---

## Links

- [GitHub Repository](https://github.com/ARKADATA/ARKITEKT-Project)
- [Documentation](Documentation/)
- [Release Strategy](README.md#release-philosophy)

---

## Template for Future Releases

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- New feature description

### Changed
- Modification description

### Deprecated
- Feature marked for removal

### Removed
- Deleted feature

### Fixed
- Bug fix description (#issue_number)

### Security
- Security fix description
```
