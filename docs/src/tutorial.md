# Tutorial

This tutorial demonstrates how to use SciMLLogging.jl to add verbosity control to your Julia packages.

## Basic Concepts

SciMLLogging.jl provides three main components:

1. `Verbosity` - A sum type representing different verbosity levels
2. `AbstractVerbositySpecifier{T}` - Base type for custom verbosity types
3. `@SciMLMessage` - Macro for emitting messages based on verbosity settings

## Creating a Verbosity System

### Step 1: Define Your Options

First, create a structure to hold your verbosity options:

```julia
using SciMLLogging
using Logging

mutable struct MyOptions
    startup::Verbosity.Type
    progress::Verbosity.Type
    warnings::Verbosity.Type
    
    function MyOptions(;
        startup = Verbosity.Info(),
        progress = Verbosity.None(),
        warnings = Verbosity.Warn()
    )
        new(startup, progress, warnings)
    end
end
```

### Step 2: Create Your Verbosity Type

Define a type that inherits from `AbstractVerbositySpecifier{T}`:

```julia
struct MyVerbosity{T} <: AbstractVerbositySpecifier{T}
    options::MyOptions
end
```

The type parameter `T` determines whether verbosity is enabled:
- `T = true`: Messages will be processed
- `T = false`: No runtime overhead (compiled away)

### Step 3: Use the Verbosity System

```julia
# Create an enabled verbosity instance
verbose = MyVerbosity{true}(MyOptions())

# Emit messages at different levels
@SciMLMessage("Application starting...", verbose, :startup, :options)
@SciMLMessage("Processing item 1/100", verbose, :progress, :options)
@SciMLMessage("Memory usage high", verbose, :warnings, :options)
```

## Verbosity Levels

SciMLLogging provides several built-in verbosity levels:

```julia
Verbosity.None()    # No output
Verbosity.Info()    # Informational messages
Verbosity.Warn()    # Warning messages
Verbosity.Error()   # Error messages
Verbosity.Level(n)  # Custom log level with integer n
```

## Dynamic Messages

Use functions for lazy evaluation of expensive message generation:

```julia
# Variables from surrounding scope
iter = 5
total = 100

@SciMLMessage(verbose, :progress, :options) do
    percentage = iter / total * 100
    "Progress: $iter/$total ($(round(percentage, digits=1))%)"
end
```

The function is only evaluated if the message will actually be emitted.

## Disabling Verbosity

For zero runtime cost when disabled:

```julia
# Disabled verbosity
silent = MyVerbosity{false}(MyOptions())

# This compiles to nothing - no runtime overhead
@SciMLMessage("This won't be shown", silent, :startup, :options)
```

## Utility Functions

### Converting to Integer

For compatibility with packages using integer verbosity levels:

```julia
level = verbosity_to_int(Verbosity.Warn())  # Returns 2
```

### Converting to Boolean

For packages using boolean verbosity flags:

```julia
is_verbose = verbosity_to_bool(Verbosity.Info())  # Returns true
is_verbose = verbosity_to_bool(Verbosity.None())  # Returns false
```

## Custom Logger

Route messages to different destinations:

```julia
# Create a logger that sends warnings and errors to files
logger = SciMLLogger(
    info_repl = true,
    warn_repl = true,
    error_repl = true,
    warn_file = "warnings.log",
    error_file = "errors.log"
)

# Use the logger
with_logger(logger) do
    @SciMLMessage("This is logged", verbose, :startup, :options)
end
```

## Complete Example

Here's a complete example showing a solver with verbosity:

```julia
using SciMLLogging
using Logging

# Define verbosity options
mutable struct SolverOptions
    initialization::Verbosity.Type
    iterations::Verbosity.Type
    convergence::Verbosity.Type
    
    function SolverOptions(;
        initialization = Verbosity.Info(),
        iterations = Verbosity.None(),
        convergence = Verbosity.Info()
    )
        new(initialization, iterations, convergence)
    end
end

# Create verbosity type
struct SolverVerbosity{T} <: AbstractVerbositySpecifier{T}
    options::SolverOptions
end

# Solver function
function my_solver(problem, verbose::SolverVerbosity)
    @SciMLMessage("Initializing solver...", verbose, :initialization, :options)
    
    for i in 1:100
        # Do iteration work...
        
        @SciMLMessage(verbose, :iterations, :options) do
            "Iteration $i: residual = $(rand())"
        end
        
        if rand() < 0.01  # Converged
            @SciMLMessage("Converged at iteration $i", verbose, :convergence, :options)
            break
        end
    end
end

# Use the solver
verbose = SolverVerbosity{true}(SolverOptions())
my_solver("problem", verbose)

# Or with silent mode
silent = SolverVerbosity{false}(SolverOptions())
my_solver("problem", silent)  # No output
```

## Testing with Verbosity

When testing code that uses SciMLLogging:

```julia
using Test

@testset "Verbosity Tests" begin
    verbose = MyVerbosity{true}(MyOptions(startup = Verbosity.Info()))
    
    # Test that message is logged at correct level
    @test_logs (:info, "Test message") begin
        @SciMLMessage("Test message", verbose, :startup, :options)
    end
    
    # Test that disabled verbosity produces no output
    silent = MyVerbosity{false}(MyOptions())
    @test_logs min_level=Logging.Debug begin
        @SciMLMessage("Should not appear", silent, :startup, :options)
    end
end
```