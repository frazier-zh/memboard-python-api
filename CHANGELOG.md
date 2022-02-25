# Changelog

## [Unreleased]

## [0.1.1] - 2022-02-23

### Added

- "CHANGELOG.md" for recording changes
- "code" class for code generation
- "board" class for board operation

### Changed

- Renamed "operation.py" to "board.py"
- Integrated all board operation to "board.py"

### Removed

- allow_auto() is no longer used for execute single instruction

### Fixed

## [0.1] - 2022-02-23

### Added

- The first release of memboard python API
- The first release of corrsponding FPGA hardware code

### Known Issues

- Complication in staring an interactive session and an automated execution
- Complication in result conversion
- ADC BUSY signal is occasionally stuck in high after conversion
- Inaccurate operation runtime
