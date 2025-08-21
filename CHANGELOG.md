# Changelog

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
