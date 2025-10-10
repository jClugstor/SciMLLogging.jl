"""
    AbstractMessageLevel

Abstract base type for all verbosity log levels in SciMLLogging.

Log levels determine the severity/importance of messages. Concrete subtypes include:
- `Silent`: No output
- `InfoLevel`: Informational messages
- `WarnLevel`: Warning messages
- `ErrorLevel`: Error messages
- `CustomLevel(n)`: Custom log level with integer value `n`
"""
abstract type AbstractMessageLevel end

"""
    Silent <: AbstractMessageLevel

Log level that produces no output. When a message category is set to `Silent()`,
no messages will be emitted for that category.
"""
struct Silent <: AbstractMessageLevel end

"""
    InfoLevel <: AbstractMessageLevel

Informational log level. Messages at this level provide general information
about the progress or state of the computation.
"""
struct InfoLevel <: AbstractMessageLevel end

"""
    WarnLevel <: AbstractMessageLevel

Warning log level. Messages at this level indicate potential issues or
situations that may require attention but don't prevent execution.
"""
struct WarnLevel <: AbstractMessageLevel end

"""
    ErrorLevel <: AbstractMessageLevel

Error log level. Messages at this level indicate serious problems or
failures in the computation.
"""
struct ErrorLevel <: AbstractMessageLevel end

"""
    CustomLevel(n::Int) <: AbstractMessageLevel

Custom log level with integer value `n`. This allows creating custom
severity levels beyond the standard Info/Warn/Error hierarchy.

Higher integer values typically indicate higher priority/severity.

# Example
```julia
debug_level = CustomLevel(-1000)  # Very low priority debug messages
critical_level = CustomLevel(1000)  # Very high priority critical messages
```
"""
struct CustomLevel <: AbstractMessageLevel
    level::Int
end

"""
    AbstractVerbosityPreset

Abstract base type for predefined verbosity configurations.

Presets provide convenient ways for users to configure verbosity without
needing to specify individual message categories. Concrete subtypes include:
- `None`: Disable all verbosity
- `Minimal`: Only essential messages
- `Standard`: Balanced verbosity for typical use
- `Detailed`: Comprehensive verbosity for debugging
- `All`: Enable all message categories
"""
abstract type AbstractVerbosityPreset end

"""
    None <: AbstractVerbosityPreset

Preset that disables all verbosity. All message categories should be set to to `Silent()`.
"""
struct None <: AbstractVerbosityPreset end

"""
    Minimal <: AbstractVerbosityPreset

Preset that shows only essential messages. Typically includes only warnings,
errors, and critical status information while suppressing routine progress
and debugging messages. 

This verbosity preset should set messages related to critical failures and 
errors that stop computation to `ErrorLevel`. Messages related to potential issues 
(e.g., convergence problems, parameter choices that may affect results, deprecated features)
should be set to `WarnLevel()`. All other messages should be set to `Silent()`.
"""
struct Minimal <: AbstractVerbosityPreset end

"""
    Standard <: AbstractVerbosityPreset

Preset that provides balanced verbosity suitable for typical usage.
Shows important progress and status information without overwhelming
the user with details.

This verbosity preset should include the settings from `Minimal`, while also setting 
messages such as important initialization messages (e.g., algorithm selection, key parameter values), 
significant milestones, convergence status, final results to `InfoLevel()` or higher.
"""
struct Standard <: AbstractVerbosityPreset end

"""
    Detailed <: AbstractVerbosityPreset

Preset that provides comprehensive verbosity for debugging and detailed
analysis. Shows most or all available message categories to help with
troubleshooting and understanding program behavior.

This verbosity preset should include the settings from `Standard`, plus progress updates 
(e.g., iteration counters, intermediate state), performance metrics 
(e.g., timing information, memory usage), detailed diagnostics, and internal state information.
The only messages that should be `Silent()` at this preset are very small details that would 
clutter output even during debugging. 
"""
struct Detailed <: AbstractVerbosityPreset end

"""
    All <: AbstractVerbosityPreset

Preset that enables maximum verbosity. All message categories are typically
set to show informational messages or their appropriate levels.

This verbosity preset should include the settings from `Detailed`, plus even more details.
At this preset, no messages should be `Silent()`. 
"""
struct All <: AbstractVerbosityPreset end