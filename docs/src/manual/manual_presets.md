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

### Minimal Preset
```@docs
Minimal
```

Use `Minimal` when you want to be informed of important issues but don't need detailed progress information.

### Standard Preset
```@docs
Standard
```

The `Standard` preset provides a balanced configuration suitable for most interactive use cases.

### Detailed Preset
```@docs
Detailed
```

`Detailed` is for development, debugging, or when you need comprehensive information about what your code is doing.

### All Preset
```@docs
All
```

The `All` preset enables maximum verbosity, useful for deep debugging or understanding complex behaviors.

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

