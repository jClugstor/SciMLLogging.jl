# The @SciMLMessage Macro

The `@SciMLMessage` macro is the primary interface for emitting log messages in the SciMLLogging system. It allows you to emit messages that are controlled by verbosity specifiers.

## Basic Usage

```@docs
@SciMLMessage
```

## Simple String Messages

The most basic usage emits a string message:

```julia
@SciMLMessage("Starting computation", verbosity, :initialization)
@SciMLMessage("Iteration complete", verbosity, :progress)
@SciMLMessage("Convergence achieved", verbosity, :convergence)
```

## Function-Based Messages

For expensive-to-compute messages, use a function to enable lazy evaluation:

```julia
x = 10
y = 20

@SciMLMessage(verbosity, :debug) do
    z = expensive_calculation(x, y)
    "Result: $z"
end
```

The function is only called if the message category is not `Silent()`, avoiding unnecessary computation.

## Integration with Verbosity Specifiers

The macro works with any `AbstractVerbositySpecifier` implementation:

```julia
# Package defines verbosity specifier
@concrete struct SolverVerbosity <: AbstractVerbositySpecifier
    initialization
    progress
    convergence
    diagnostics
    performance
end

# Usage in package code
function solve_problem(problem; verbose = SolverVerbosity(Standard()))
    @SciMLMessage("Initializing solver", verbose, :initialization)

    # ... solver setup ...

    for iteration in 1:max_iterations
        @SciMLMessage("Iteration $iteration", verbose, :progress)

        # ... iteration work ...

        if converged
            @SciMLMessage("Converged after $iteration iterations", verbose, :convergence)
            break
        end
    end

    return result
end
```