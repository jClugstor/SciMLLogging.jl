# Verbosity Presets

Presets provide convenient, predefined verbosity configurations that cover common use cases. Instead of manually setting each message category, users can choose from standard presets that automatically configure appropriate message levels. SciMLLogging provides the `AbstractVerbosityPreset` type, along with five subtypes meant to represent different verbosity levels. It is up to the implementer of the `AbstractVerbositySpecifier` to ensure that the verbosity presets are able to be used.  

## Abstract Base Type

```@docs
AbstractVerbosityPreset
```

## Standard Presets

### None Preset
```@docs
SciMLLogging.None
```

The `None` preset is for when you want no output whatsoever.

**What to include:**
- Nothing - all message categories should be set to `Silent()`
- Use this preset when running automated scripts, batch jobs, or when you want complete silence

### Minimal Preset
```@docs
Minimal
```

Use `Minimal` when you want to be informed of important issues but don't need detailed progress information.

**What to include at each level:**
- **WarnLevel or higher**: Warnings about potential issues (e.g., convergence problems, parameter choices that may affect results, deprecated features)
- **ErrorLevel**: Critical failures and errors that stop computation
- **Silent**: Progress updates, routine diagnostics, initialization messages, performance metrics, and detailed state information

**Typical message categories:**
- Errors: `ErrorLevel()`
- Warnings: `WarnLevel()`
- Everything else: `Silent()`

### Standard Preset
```@docs
Standard
```

The `Standard` preset provides a balanced configuration suitable for most interactive use cases.

**What to include at each level:**
- **InfoLevel or higher**: Important initialization messages (e.g., algorithm selection, key parameter values), significant milestones, convergence status, final results, warnings, and errors
- **WarnLevel or higher**: All warnings and errors as in `Minimal`
- **ErrorLevel**: All critical failures
- **Silent**: Detailed progress bars, iteration-by-iteration updates, verbose diagnostics, and low-level performance metrics

**Typical message categories:**
- Errors: `ErrorLevel()`
- Warnings: `WarnLevel()`
- Initialization, convergence, results: `InfoLevel()`
- Progress, detailed diagnostics: `Silent()`

### Detailed Preset
```@docs
Detailed
```

`Detailed` is for development, debugging, or when you need comprehensive information about what your code is doing.

**What to include at each level:**
- **InfoLevel or higher**: Everything from `Standard`, plus progress updates (e.g., iteration counters, intermediate state), performance metrics (e.g., timing information, memory usage), detailed diagnostics, and internal state information
- **WarnLevel or higher**: All warnings and errors
- **ErrorLevel**: All critical failures
- **Silent**: Only truly verbose trace-level information that would clutter output even during debugging

**Typical message categories:**
- Errors: `ErrorLevel()`
- Warnings: `WarnLevel()`
- Initialization, convergence, results, progress, diagnostics, performance: `InfoLevel()`
- Trace-level debugging: `Silent()` or `CustomLevel(-1000)`

### All Preset
```@docs
All
```

The `All` preset enables maximum verbosity, useful for deep debugging or understanding complex behaviors.

**What to include at each level:**
- **CustomLevel(-1000) or higher**: Absolutely everything - trace-level debugging, every function entry/exit, every variable change, memory allocations, internal calculations, and any other information that might be useful for understanding program flow
- **InfoLevel or higher**: All standard messages from `Detailed`
- **WarnLevel or higher**: All warnings and errors
- **ErrorLevel**: All critical failures
- **Silent**: Nothing should be silent in this preset

**Typical message categories:**
- Errors: `ErrorLevel()`
- Warnings: `WarnLevel()`
- Standard messages: `InfoLevel()`
- Verbose debugging and trace: `CustomLevel(-1000)` or similar low-priority custom level
- Nothing should be `Silent()`

## Custom Presets

Packages can define their own preset types for specialized use cases:

```julia
# Package-specific preset
struct DebuggingPreset <: AbstractVerbosityPreset end

function MyPackageVerbosity(::DebuggingPreset)
    MyPackageVerbosity{true}(
        initialization = InfoLevel(),
        progress = CustomLevel(-100),  # Extra detailed progress
        convergence = InfoLevel(),
        warnings = WarnLevel(),
        errors = ErrorLevel()
    )
end
```

## Using Presets

Presets are typically used as constructor arguments for verbosity specifiers:

```julia
using SciMLLogging

# Assuming a package defines MyPackageVerbosity
quiet_config = MyPackageVerbosity(None())      # No output
default_config = MyPackageVerbosity(Standard()) # Balanced output
debug_config = MyPackageVerbosity(All())       # Maximum output
```

## How Presets Work

When you pass a preset to a verbosity specifier constructor, the package implementation maps the preset to appropriate message levels for each category. For example:

```julia
# This preset usage...
verbosity = SolverVerbosity(Standard())

# ...might be equivalent to this manual configuration:
verbosity = SolverVerbosity(
    initialization = InfoLevel(),
    progress = Silent(),
    convergence = InfoLevel(),
    diagnostics = WarnLevel(),
    performance = InfoLevel()
)
```

