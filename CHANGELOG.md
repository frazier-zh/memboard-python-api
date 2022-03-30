# Changelog

## [Unreleased]

### Feature

- Add global error handling module, unify the error code
- FPGA code stability fix
- FPGA interface upgrade
- DAC check

## [0.2] - 2022-02-26

### Added

- "CHANGELOG.md" for recording changes
- "board" class for board operation

### Changed

- Renamed "operation.py" to "board.py"
- Integrated all board operation to "board.py"
- IntEnum for storing constant
- Functions no longer raise errors, all error and warning are handled through module logger

### Removed

- allow_auto() is no longer used for executing single instruction

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
- Device control are bundled, causing unexpected waiting
- FPGA has no error return or time out
- Complication in ADC control

  