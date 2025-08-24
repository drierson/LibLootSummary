# Changelog

## [3.1.5] - 2025-08-24

### Changed
- **MAINTAINER UPDATE**: Updated maintainer from silvereyes to dlrgames
- **Console Compatibility**: Renamed manifest from .txt to .addon extension for console platform support
- **Documentation Restructure**: Moved detailed usage instructions to separate USAGE.md file
- **GitHub Ready**: Created professional README.md suitable for GitHub landing page

### Added
- USAGE.md with complete API documentation and integration examples
- Enhanced README.md with badges, feature highlights, and quick start guide
- LICENSE file included in distribution packages
- Console compatibility confirmed via LibAddonMenu-2.0 automatic conversion

### Fixed
- Build script now supports both .txt and .addon manifest extensions
- Updated Universal-Build.ps1 to include USAGE.md in documentation packages

## [3.1.5] - 2025-08-20

### Changed
- Refactored the code for generating LibAddonMenu options to be data-driven, reducing code duplication and improving maintainability.
- Replaced a magic number with a named constant for better readability.
- Improved input validation by adding `asserts` to public functions.
- Made error handling stricter by using `error()` instead of a debug print.

### Fixed
- Removed duplicate Japanese localization file.
- Corrected the path to the localization files.
- Optimized the addon manifest to prevent double-loading of the English localization file.

### Removed
- Removed unused `CreateStrings.lua` file.
