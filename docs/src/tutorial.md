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

```@example tutorial1
using SciMLLogging
using Logging

mutable struct MyOptions
    startup::Verbosity.Type
    progress::Verbosity.Type
    warnings::Verbosity.Type
    
    function MyOptions(;
        startup = Verbosity.Info(),
        progress = Verbosity.Silent(),
        warnings = Verbosity.Warn()
    )
        new(startup, progress, warnings)
    end
end
nothing # hide
```

### Step 2: Create Your Verbosity Type

Define a type that inherits from `AbstractVerbositySpecifier{T}`:

```@example tutorial1
struct MyVerbosity{T} <: AbstractVerbositySpecifier{T}
    options::MyOptions
end
nothing # hide
```

The type parameter `T` determines whether verbosity is enabled:
- `T = true`: Messages will be processed
- `T = false`: No runtime overhead (compiled away)

### Step 3: Use the Verbosity System

```@example tutorial1
# Create an enabled verbosity instance
verbose = MyVerbosity{true}(MyOptions())

# Emit messages at different levels
@SciMLMessage("Application starting...", verbose, :startup)
@SciMLMessage("Processing item 1/100", verbose, :progress)
@SciMLMessage("Memory usage high", verbose, :warnings)
nothing # hide
```

## Verbosity Levels

SciMLLogging provides several built-in verbosity levels:

```@example tutorial2
using SciMLLogging

Verbosity.Silent()  # No output
Verbosity.Info()    # Informational messages
Verbosity.Warn()    # Warning messages
Verbosity.Error()   # Error messages
Verbosity.Level(-1000)  # Custom log level with integer n
```

## Dynamic Messages

Use functions for lazy evaluation of expensive message generation:

```@example tutorial3
using SciMLLogging
using Logging

# Define the verbosity system (same as before)
mutable struct MyOptions2
    progress::Verbosity.Type
    MyOptions2() = new(Verbosity.Info())
end

struct MyVerbosity2{T} <: AbstractVerbositySpecifier{T}
    options::MyOptions2
end

verbose = MyVerbosity2{true}(MyOptions2())

# Variables from surrounding scope
iter = 5
total = 100

@SciMLMessage(verbose, :progress) do
    percentage = iter / total * 100
    "Progress: $iter/$total ($(round(percentage, digits=1))%)"
end
nothing # hide
```

The function is only evaluated if the message will actually be emitted.

## Disabling Verbosity

For zero runtime cost when disabled:

```@example tutorial4
using SciMLLogging
using Logging

mutable struct MyOptions3
    startup::Verbosity.Type
    MyOptions3() = new(Verbosity.Info())
end

struct MyVerbosity3{T} <: AbstractVerbositySpecifier{T}
    options::MyOptions3
end

# Disabled verbosity
silent = MyVerbosity3{false}(MyOptions3())

# This compiles to nothing - no runtime overhead
@SciMLMessage("This won't be shown", silent, :startup)
println("Message was not shown because verbosity is disabled")
```

## Utility Functions

### Converting to Integer

For compatibility with packages using integer verbosity levels:

```@example tutorial5
using SciMLLogging

level = verbosity_to_int(Verbosity.Warn())  # Returns 2
```

### Converting to Boolean

For packages using boolean verbosity flags:

```@example tutorial6
using SciMLLogging

is_verbose = verbosity_to_bool(Verbosity.Info())  # Returns true
println("Verbosity.Info() converts to: $is_verbose")

is_verbose = verbosity_to_bool(Verbosity.Silent())  # Returns false
println("Verbosity.Silent() converts to: $is_verbose")
```

## Custom Logger

Route messages to different destinations:

```@example tutorial7
using SciMLLogging
using Logging

# Create a logger that sends warnings and errors to files
logger = SciMLLogger(
    info_repl = true,
    warn_repl = true,
    error_repl = true,
    warn_file = "warnings.log",
    error_file = "errors.log"
)

# Define a simple verbosity system for testing
mutable struct LoggerTestOptions
    test::Verbosity.Type
    LoggerTestOptions() = new(Verbosity.Warn())
end

struct LoggerTestVerbosity{T} <: AbstractVerbositySpecifier{T}
    options::LoggerTestOptions
end

verbose = LoggerTestVerbosity{true}(LoggerTestOptions())

# Use the logger
with_logger(logger) do
    @SciMLMessage("This warning is logged", verbose, :test)
end

# Clean up
isfile("warnings.log") && rm("warnings.log")
isfile("errors.log") && rm("errors.log")
nothing # hide
```

## Complete Example

Here's a complete example showing a solver with verbosity:

```@example tutorial8
using SciMLLogging
using Logging
using Random
Random.seed!(123) # For reproducibility

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
    @SciMLMessage("Initializing solver...", verbose, :initialization)
    
    for i in 1:100
        # Do iteration work...
        
        @SciMLMessage(verbose, :iterations) do
            "Iteration $i: residual = $(round(rand(), digits=4))"
        end
        
        if rand() < 0.05  # Converged (5% chance per iteration for demo)
            @SciMLMessage("Converged at iteration $i", verbose, :convergence)
            return i
        end
    end
    @SciMLMessage("Failed to converge", verbose, :convergence)
    return nothing
end

# Use the solver with verbosity
println("Running solver with verbosity enabled:")
verbose = SolverVerbosity{true}(SolverOptions())
result = my_solver("problem", verbose)
println("Solver returned: $result")

println("\nRunning solver in silent mode:")
# Or with silent mode
silent = SolverVerbosity{false}(SolverOptions())
result = my_solver("problem", silent)  # No output
println("Solver returned: $result (no messages shown)")
```

## Testing with Verbosity

When testing code that uses SciMLLogging:

```@example tutorial9
using SciMLLogging
using Logging
using Test

# Define a simple verbosity system for testing
mutable struct TestOptions
    level::Verbosity.Type
    TestOptions() = new(Verbosity.Info())
end

struct TestVerbosity{T} <: AbstractVerbositySpecifier{T}
    options::TestOptions
end

@testset "Verbosity Tests" begin
    verbose = TestVerbosity{true}(TestOptions())
    
    # Test that message is logged at correct level
    @test_logs (:info, "Test message") begin
        @SciMLMessage("Test message", verbose, :level)
    end

    # Test that disabled verbosity produces no output
    silent = TestVerbosity{false}(TestOptions())
    @test_logs min_level=Logging.Debug begin
        @SciMLMessage("Should not appear", silent, :level)
    end
end
```