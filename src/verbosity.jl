"""
    MessageLevel

Abstract base type for all verbosity log levels in SciMLLogging.

Log levels determine the severity/importance of messages. Concrete subtypes include:
- `Silent`: No output
- `InfoLevel`: Informational messages
- `WarnLevel`: Warning messages
- `ErrorLevel`: Error messages
- `CustomLevel(n)`: Custom log level with integer value `n`
"""
abstract type MessageLevel end

"""
    Silent <: MessageLevel

Log level that produces no output. When a message category is set to `Silent()`,
no messages will be emitted for that category.
"""
struct Silent <: MessageLevel end

"""
    InfoLevel <: MessageLevel

Informational log level. Messages at this level provide general information
about the progress or state of the computation.
"""
struct InfoLevel <: MessageLevel end

"""
    WarnLevel <: MessageLevel

Warning log level. Messages at this level indicate potential issues or
situations that may require attention but don't prevent execution.
"""
struct WarnLevel <: MessageLevel end

"""
    ErrorLevel <: MessageLevel

Error log level. Messages at this level indicate serious problems or
failures in the computation.
"""
struct ErrorLevel <: MessageLevel end

"""
    CustomLevel(n::Int) <: MessageLevel

Custom log level with integer value `n`. This allows creating custom
severity levels beyond the standard Info/Warn/Error hierarchy.

Higher integer values typically indicate higher priority/severity.

# Example
```julia
debug_level = CustomLevel(-1000)  # Very low priority debug messages
critical_level = CustomLevel(1000)  # Very high priority critical messages
```
"""
struct CustomLevel <: MessageLevel
    level::Int
end

"""
    VerbosityPreset

Abstract base type for predefined verbosity configurations.

Presets provide convenient ways for users to configure verbosity without
needing to specify individual message categories. Concrete subtypes include:
- `None`: Disable all verbosity
- `All`: Enable all message categories
- `Minimal`: Only essential messages
- `Standard`: Balanced verbosity for typical use
- `Detailed`: Comprehensive verbosity for debugging
"""
abstract type VerbosityPreset end

"""
    None <: VerbosityPreset

Preset that disables all verbosity. When used, typically results in
a verbosity specifier with `T=false`, providing zero runtime overhead.
"""
struct None <: VerbosityPreset end

"""
    Minimal <: VerbosityPreset

Preset that shows only essential messages. Typically includes only warnings,
errors, and critical status information while suppressing routine progress
and debugging messages.
"""
struct Minimal <: VerbosityPreset end

"""
    Standard <: VerbosityPreset

Preset that provides balanced verbosity suitable for typical usage.
Shows important progress and status information without overwhelming
the user with details.
"""
struct Standard <: VerbosityPreset end

"""
    Detailed <: VerbosityPreset

Preset that provides comprehensive verbosity for debugging and detailed
analysis. Shows most or all available message categories to help with
troubleshooting and understanding program behavior.
"""
struct Detailed <: VerbosityPreset end

"""
    All <: VerbosityPreset

Preset that enables maximum verbosity. All message categories are typically
set to show informational messages or their appropriate levels.
"""
struct All <: VerbosityPreset end