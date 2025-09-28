# Developer Tutorial: Adding SciMLLogging to Your Package

This tutorial is for Julia package developers who want to integrate SciMLLogging.jl into their packages to provide users with fine-grained verbosity control.

## Overview

SciMLLogging.jl provides four main components for package developers:

1. `AbstractVerbositySpecifier{T}` - Base type for creating custom verbosity types
2. `@SciMLMessage` - Macro for emitting conditional log messages
3.  Log levels - Predefined log levels (`Silent`, `InfoLevel`, `WarnLevel`, `ErrorLevel`, `CustomLevel(n)`)
4.  Verbosity preset levels - `None`, `Minimal`, `Standard`, `Detailed`, `All`

### AbstractVerbositySpecifier
    `AbstractVerbositySpecifier{T}` is the base type that package developers implement a subtype of to create custom verbosity type for their packages.
      
- Type parameter T: Controls whether logging is enabled (T=true) or disabled (T=false). When `T = false`, any use of the `SciMLLogging.emit_message` function points to any empty function. When the the type parameter is known at compile time, this allows for the compiler to make certain optimizations that can lead to this system having zero runtime overhead when not in use. 
- Message levels: Fields of the `AbstractVerbositySpecifier` represent messages or groups of messages. These fields should be of the type `SciMLLogging.MessageLevel`. Each message level subtype represents a different level at which the message will be logged at. 
### @SciMLMessage 
```@docs
@SciMLMessage
```    
In order to use the the `@SciMLMessage` macro, simply choose which of the fields of your `AbstractVerbositySpecifier` should control that particular message. Then when the macro is called, the field of the verbosity object corresponding with the `option` argument to the macro is used to control the logging of the message. 

### Log Levels
Possible types for these are:
- `Silent()` : no message is emitted
- `InfoLevel()` : message is emitted as an `Info` log
- `WarnLevel()` : message is emitted as a `Warn` log
- `ErrorLevel()` : message is emitted as an `Error` log
- `CustomLevel(n)` : message is emitted at `LogLevel(n)`

### Verbosity Presets
SciMLLogging also provides an abstract `VerbosityPreset` type. The ones provided by `SciMLLogging` are:
- `None()`: Log nothing at all 
- `Minimal()`: Preset that shows only essential messages
- `Standard()`: Preset that provides balanced verbosity suitable for typical usage
- `Detailed()`: Preset that provides comprehensive verbosity for debugging and detailed
analysis
- `All()`: Preset that enables maximum verbosity

## Step 1: Design Your Verbosity Interface

First, decide what aspects of your package should be controllable by users. For example, a solver might have:
- Initialization messages
- Iteration progress
- Convergence information
- Error control information

## Step 2: Create Your Verbosity Type

Define a struct that subtypes `AbstractVerbositySpecifier{T}`:

```julia
using SciMLLogging

struct MySolverVerbosity{T} <: AbstractVerbositySpecifier{T}
    initialization::AbstractMessageLevel
    iterations::AbstractMessageLevel
    convergence::AbstractMessageLevel
    warnings::AbstractMessageLevel

    function MySolverVerbosity{T}(;
        initialization = InfoLevel(),
        iterations = Silent(),
        convergence = InfoLevel(),
        warnings = WarnLevel()
    ) where T
        new{T}(initialization, iterations, convergence, warnings)
    end
end
```
## Step 3: Add Convenience Constructors

Make it easy for users to create verbosity instances. Perhaps include a constructor that can take a VerbosityPreset, and use it to set the rest of the fields, and a constructor that takes all keyword arguments:

```julia
# Default enabled verbosity
MySolverVerbosity() = MySolverVerbosity{true}()

# Boolean constructor
MySolverVerbosity(enabled::Bool) = enabled ? MySolverVerbosity{true}() : MySolverVerbosity{false}()

function MySolverVerbosity{T}(;
        initialization = InfoLevel(),
        iterations = Silent(),
        convergence = InfoLevel(),
        error_control = WarnLevel()
    ) where T
        MySolverVerbosity{T}(initialization, iterations, convergence, error_control)
    end
end 
# Preset-based constructor (optional)
function MySolverVerbosity(preset::AbstractVerbosityPreset)
    if preset isa None
        MySolverVerbosity{false}()
    elseif preset isa All
        MySolverVerbosity{true}(
            initialization = InfoLevel(),
            iterations = InfoLevel(),
            convergence = InfoLevel(),
            error_control = WarnLevel()
        )
    elseif preset isa Minimal
        MySolverVerbosity{true}(
            initialization = Silent(),
            iterations = Silent(),
            convergence = ErrorLevel(),
            error_control = ErrorLevel()
        )
    else
        MySolverVerbosity{true}()  # Default
    end
end
```

## Step 4: Integrate Messages Into Your Code

Use `@SciMLMessage` throughout your package code:

```julia
function my_solve(problem, verbose::MySolverVerbosity)
    @SciMLMessage("Initializing solver for $(typeof(problem))", verbose, :initialization)

    # Setup code here...

    for iteration in 1:maxiters
        # Solver iteration...

        @SciMLMessage(verbose, :iterations) do
            "Iteration $iteration: residual = $(compute_residual())"
        end

        if converged
            @SciMLMessage("Converged after $iteration iterations", verbose, :convergence)
            return solution
        end

        if should_warn_about_something()
            @SciMLMessage("Convergence is slow, consider adjusting parameters", verbose, :error_control)
        end
    end

    @SciMLMessage("Failed to converge after $maxiters iterations", verbose, :convergence)
    return nothing
end
```
## Step 5: Document for Users

Provide clear documentation for your users:

```julia
"""
    MySolverVerbosity{T}(; kwargs...)

Controls verbosity output from MySolver functions.

# Keyword Arguments
- `initialization = InfoLevel()`: Messages about solver setup
- `iterations = Silent()`: Per-iteration progress messages
- `convergence = InfoLevel()`: Convergence/failure notifications
- `error_control = WarnLevel()`: Messages about solver error control

# Constructors
- `MySolverVerbosity()`: Default enabled verbosity
- `MySolverVerbosity(false)`: Disabled (zero overhead)
- `MySolverVerbosity(All())`: Enable all message categories
- `MySolverVerbosity(Minimal())`: Only errors and convergence
"""
```

## Step 6: Add Tests

Test your verbosity implementation:

```julia
using Test
using MySolver
using Logging

@testset "Verbosity Tests" begin
    # Test message emission
    verbose = MySolverVerbosity()

    @test_logs (:info, r"Initializing solver") match_mode=:any begin
        my_solve(test_problem, verbose)
    end

    # Test silent mode produces no output
    silent = MySolverVerbosity(false)
    @test_logs min_level=Logging.Debug begin
        my_solve(test_problem, silent)
    end
end
```

## Best Practices

### User Experience
- Provide sensible defaults that work for most users
- Use descriptive category names (`:initialization` not `:init`)
- Group related messages into logical categories
- Document what each category controls

### Integration
- Accept verbosity parameters in your main API functions
- Consider making verbosity optional with sensible defaults
- Thread verbosity through your call stack as needed

## Advanced: Custom Log Levels

For specialized needs, you can create custom log levels:

```julia
struct MySolverVerbosity{T} <: AbstractVerbositySpecifier{T}
    debug::AbstractMessageLevel
    # ... other fields

    function MySolverVerbosity{T}(;
        debug = CustomLevel(-1000),  # Custom level below Info
        # ... other defaults
    ) where T
        new{T}(debug, ...)
    end
end
```

## Complete Example

Here's a complete minimal example:

```julia
module ExampleSolver

using SciMLLogging
import SciMLLogging: AbstractVerbositySpecifier

struct ExampleVerbosity{T} <: AbstractVerbositySpecifier{T}
    progress::AbstractMessageLevel

    ExampleVerbosity{T}(progress = InfoLevel()) where T = new{T}(progress)
end

ExampleVerbosity() = ExampleVerbosity{true}()
ExampleVerbosity(enabled::Bool) = enabled ? ExampleVerbosity{true}() : ExampleVerbosity{false}()

function solve_example(n::Int, verbose::ExampleVerbosity)
    result = 0
    for i in 1:n
        result += i
        @SciMLMessage("Step $i: sum = $result", verbose, :progress)
    end
    return result
end

export ExampleVerbosity, solve_example

end
```

This example shows the minimal structure needed to integrate SciMLLogging into a package.

## Utility Functions for Integration

SciMLLogging provides utility functions to help integrate with packages that use different verbosity systems. For example, perhaps the package you're developing depends on a package that has verbosity settings that are set using a Bool or an integer, but you still want to be able to control all of the verbosity through the SciMLLogging interface. 

### `verbosity_to_int()`

Converts a `MessageLevel` to an integer value. This is useful when interfacing with packages that use integer-based verbosity levels:

```julia
using SciMLLogging

# Convert message levels to integers
verbosity_to_int(Silent())      # Returns 0
verbosity_to_int(InfoLevel())   # Returns 1
verbosity_to_int(WarnLevel())   # Returns 2
verbosity_to_int(ErrorLevel())  # Returns 3
verbosity_to_int(CustomLevel(5)) # Returns 5

# Example usage with a package that expects integer verbosity
solver_verbosity = SolverVerbosity(Standard())
int_level = verbosity_to_int(solver_verbosity.convergence)
external_solve(problem, verbosity = int_level)
```

### `verbosity_to_bool()`

Converts a `MessageLevel` to a boolean value. This is useful for packages that use simple on/off verbosity:

```julia
# Convert message levels to booleans
verbosity_to_bool(Silent())     # Returns false
verbosity_to_bool(InfoLevel())  # Returns true
verbosity_to_bool(WarnLevel())  # Returns true
verbosity_to_bool(ErrorLevel()) # Returns true

# Example usage with a package that expects boolean verbosity
solver_verbosity = SolverVerbosity(Minimal())
should_log = verbosity_to_bool(solver_verbosity.iterations)
external_solve(problem, verbose = should_log)
```

These functions make it easier to integrate SciMLLogging with existing packages that have their own verbosity conventions.