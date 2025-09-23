"""
Verbosity levels and presets for SciMLLogging.

## Log Levels
- `Silent`: No output
- `Info`: Informational messages
- `Warn`: Warning messages
- `Error`: Error messages
- `Level(n)`: Custom log level with integer value `n`

## Verbosity Presets
- `None`: Minimal verbosity preset
- `All`: Maximum verbosity preset
- `Minimal`: Basic verbosity preset
- `Standard`: Standard verbosity preset
- `Detailed`: Detailed verbosity preset
"""

abstract type LogLevel end
struct Silent <: LogLevel end
struct Info <: LogLevel end
struct Warn <: LogLevel end
struct Error <: LogLevel end
struct Level <: LogLevel
    level::Int
end

abstract type VerbosityPreset end
struct None <: VerbosityPreset end
struct All <: VerbosityPreset end
struct Minimal <: VerbosityPreset end
struct Standard <: VerbosityPreset end
struct Detailed <: VerbosityPreset end