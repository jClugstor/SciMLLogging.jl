# Release Notes

## Version 1.0.1

### New Features

- Added configurable logging backend system using Preferences.jl
- Users can now switch between Julia's standard Logging system and Core.println output
- Added `set_logging_backend(backend)` function to configure logging output method
- Added `get_logging_backend()` function to query current logging backend
- Preference settings persist across Julia sessions via LocalPreferences.toml

### Internal Changes

- Modified `emit_message` functions to support conditional backend selection
- Added compile-time evaluation using `@static if` for performance optimization
- Backend preference is evaluated at compile time, requiring Julia restart for changes to take effect

### Dependencies

- Added Preferences.jl dependency (version 1.5.0)

### Documentation

- Added API documentation for new preference functions
- Updated function exports to include `set_logging_backend` and `get_logging_backend`

### Usage

```julia
# Switch to Core.println backend
set_logging_backend("core")

# Switch to Julia Logging backend (default)
set_logging_backend("logging")

# Check current backend
get_logging_backend()
```

Note: Julia restart required after changing logging backend preference.