# Developer Tutorial: Adding SciMLLogging to Your Package

This tutorial is for Julia package developers who want to integrate SciMLLogging.jl into their packages to provide users with fine-grained verbosity control.

## Overview

SciMLLogging.jl provides three main components for package developers:

1. `AbstractVerbositySpecifier` - Base type for creating custom verbosity types
2. `@SciMLMessage` - Macro for emitting conditional log messages
3. Verbosity levels - Predefined log levels (`Silent`, `InfoLevel`, `WarnLevel`, `ErrorLevel`, `CustomLevel(n)`)

## Step 1: Design Your Verbosity Interface

First, decide what aspects of your package should be controllable by users. For example, a solver might have:
- Initialization messages
- Iteration progress
- Convergence information
- Warning messages

## Step 2: Create Your Verbosity Type

Define a struct that inherits from `AbstractVerbositySpecifier`:

```julia
using SciMLLogging
using ConcreteStructs: @concrete

@concrete struct MySolverVerbosity <: AbstractVerbositySpecifier
    initialization
    iterations
    convergence
    warnings
end

# Constructor with defaults
function MySolverVerbosity(;
        initialization = InfoLevel(),
        iterations = Silent(),
        convergence = InfoLevel(),
        warnings = WarnLevel()
)
    MySolverVerbosity(initialization, iterations, convergence, warnings)
end
```

**Key Design Principles:**
- Use `@concrete` from ConcreteStructs.jl for better performance (eliminates type instabilities)
- Each field represents a category of messages your package can emit
- Provide sensible defaults that work for most users
- Use keyword arguments for flexibility

## Step 3: Add Convenience Constructors

Make it easy for users to create verbosity instances:

```julia
# Preset-based constructor (optional)
function MySolverVerbosity(preset::VerbosityPreset)
    if preset isa None
        MySolverVerbosity(
            initialization = Silent(),
            iterations = Silent(),
            convergence = Silent(),
            warnings = Silent()
        )
    elseif preset isa All
        MySolverVerbosity(
            initialization = InfoLevel(),
            iterations = InfoLevel(),
            convergence = InfoLevel(),
            warnings = WarnLevel()
        )
    elseif preset isa Minimal
        MySolverVerbosity(
            initialization = Silent(),
            iterations = Silent(),
            convergence = ErrorLevel(),
            warnings = ErrorLevel()
        )
    else
        MySolverVerbosity()  # Default
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
            @SciMLMessage("Convergence is slow, consider adjusting parameters", verbose, :warnings)
        end
    end

    @SciMLMessage("Failed to converge after $maxiters iterations", verbose, :convergence)
    return nothing
end
```

**Message Types:**
- **String messages**: `@SciMLMessage("Fixed message", verbose, :category)`
- **Function messages**: `@SciMLMessage(verbose, :category) do; "Dynamic message"; end`

Use function messages when:
- Message generation is expensive
- Message includes computed values
- You want lazy evaluation

## Step 5: Export Your Verbosity Type

In your main module file:

```julia
module MySolver

using SciMLLogging
import SciMLLogging: AbstractVerbositySpecifier

# Your verbosity type definition...
include("verbosity.jl")

# Your solver code...
include("solver.jl")

# Export the verbosity type
export MySolverVerbosity

end
```

## Step 6: Document for Users

Provide clear documentation for your users:

```julia
"""
    MySolverVerbosity{T}(; kwargs...)

Controls verbosity output from MySolver functions.

# Keyword Arguments
- `initialization = InfoLevel()`: Messages about solver setup
- `iterations = Silent()`: Per-iteration progress messages
- `convergence = InfoLevel()`: Convergence/failure notifications
- `warnings = WarnLevel()`: Warning messages during solving

# Constructors
- `MySolverVerbosity()`: Default enabled verbosity
- `MySolverVerbosity(false)`: Disabled (zero overhead)
- `MySolverVerbosity(All())`: Enable all message categories
- `MySolverVerbosity(Minimal())`: Only errors and convergence

# Example
```julia
# Default verbosity
verbose = MySolverVerbosity()

# Custom verbosity - show everything except iterations
verbose = MySolverVerbosity(iterations = Silent())

# Silent mode
verbose = MySolverVerbosity(
    initialization = Silent(),
    iterations = Silent(),
    convergence = Silent(),
    warnings = Silent()
)
```
"""
```

## Step 7: Add Tests

Test your verbosity implementation:

```julia
using Test
using MySolver
using Logging

@testset "Verbosity Tests" begin
    # Test message emission
    verbose = MySolverVerbosity()

    @test_logs (:info, r"Initializing solver") begin
        my_solve(test_problem, verbose)
    end

    # Test silent mode produces no output
    silent = MySolverVerbosity(
        initialization = Silent(),
        iterations = Silent(),
        convergence = Silent(),
        warnings = Silent()
    )
    @test_logs min_level=Logging.Debug begin
        my_solve(test_problem, silent)
    end
end
```

## Best Practices

### Performance
- Use `@concrete` from ConcreteStructs.jl for better performance
- Use function-based messages for expensive computations
- Set fields to `Silent()` to disable specific message categories with zero overhead
- Consider message frequency - don't spam users with too many messages

### User Experience
- Provide sensible defaults that work for most users
- Use descriptive category names (`:initialization` not `:init`)
- Group related messages into logical categories
- Document what each category controls

### Message Content
- Include relevant context (iteration numbers, values, etc.)
- Use consistent formatting across your package
- Make messages actionable when possible
- Avoid overly technical jargon in user-facing messages

### Integration
- Accept verbosity parameters in your main API functions
- Consider making verbosity optional with sensible defaults
- Thread verbosity through your call stack as needed

## Advanced: Custom Log Levels

For specialized needs, you can create custom log levels:

```julia
using ConcreteStructs: @concrete

@concrete struct MySolverVerbosity <: AbstractVerbositySpecifier
    debug
    # ... other fields
end

function MySolverVerbosity(;
    debug = CustomLevel(-1000),  # Custom level below Info
    # ... other defaults
)
    MySolverVerbosity(debug, ...)
end
```

## Complete Example

Here's a complete minimal example:

```julia
module ExampleSolver

using SciMLLogging
using ConcreteStructs: @concrete
import SciMLLogging: AbstractVerbositySpecifier

@concrete struct ExampleVerbosity <: AbstractVerbositySpecifier
    progress
end

# Constructor with default
ExampleVerbosity(; progress = InfoLevel()) = ExampleVerbosity(progress)

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