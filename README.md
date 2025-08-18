# SciMLLogging.jl

[![Build Status](https://github.com/SciML/SciMLLogging.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/SciML/SciMLLogging.jl/actions/workflows/CI.yml?query=branch%3Amain)

A verbosity control system for the SciML ecosystem that provides fine-grained control over logging.

## Installation

```julia
using Pkg
Pkg.add("SciMLLogging")
```

## Basic Usage

SciMLLogging provides a structured approach to controlling verbosity in SciML packages. The system is built around:

1. `Verbosity` - A sum type with different verbosity levels
2. `AbstractVerbositySpecifier{T}` - Base type for custom verbosity types
3. `@SciMLMessage` - Macro for emitting messages based on verbosity settings

### Example

```julia
using SciMLLogging
using Logging

# Define verbosity options
mutable struct MyOptions
    level1::Verbosity.Type
    level2::Verbosity.Type
    
    function MyOptions(;
        level1 = Verbosity.Info(),
        level2 = Verbosity.Warn()
    )
        new(level1, level2)
    end
end

# Create verbosity type
struct MyVerbosity{T} <: AbstractVerbositySpecifier{T}
    options::MyOptions
end

# Use it
verbose = MyVerbosity{true}(MyOptions())

# Emit messages
@SciMLMessage("Info message", verbose, :level1, :options)
@SciMLMessage("Warning message", verbose, :level2, :options)

# Function form for lazy evaluation
x = 10
y = 20
@SciMLMessage(verbose, :level1, :options) do
    z = x + y
    "Sum: $z"
end

# Disabled verbosity (no runtime cost)
silent = MyVerbosity{false}(MyOptions())
@SciMLMessage("This won't show", silent, :level1, :options)
```

## Verbosity Levels

- `Verbosity.None()` - No output
- `Verbosity.Info()` - Info level (maps to `Logging.Info`)
- `Verbosity.Warn()` - Warning level (maps to `Logging.Warn`)
- `Verbosity.Error()` - Error level (maps to `Logging.Error`)
- `Verbosity.Level(n)` - Custom log level with integer n
- `Verbosity.Default()` - Default settings
- `Verbosity.All()` - Maximum verbosity
- `Verbosity.Edge()` - Special edge cases

## Utility Functions

### Converting to Integer

```julia
level = verbosity_to_int(Verbosity.Warn())  # Returns 2
```

### Converting to Boolean

```julia
is_verbose = verbosity_to_bool(Verbosity.Info())  # Returns true
is_verbose = verbosity_to_bool(Verbosity.None())  # Returns false
```

### Custom Logger

```julia
# Create a logger that routes messages to files
logger = SciMLLogger(
    warn_file = "warnings.log",
    error_file = "errors.log"
)

with_logger(logger) do
    # Your code with @SciMLMessage calls
end
```

## License

MIT