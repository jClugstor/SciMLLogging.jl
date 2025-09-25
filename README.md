# SciMLLogging
[![Global Docs](https://img.shields.io/badge/docs-SciML-blue.svg)]([https://docs.sciml.ai/OrdinaryDiffEq/stable/](https://docs.sciml.ai/SciMLLogging/dev/))
[![Build Status](https://github.com/SciML/SciMLVerbosity.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/SciML/SciMLVerbosity.jl/actions/workflows/CI.yml?query=branch%3Amain)

A flexible verbosity control system for the SciML ecosystem that allows fine-grained control over logging, warnings.

Installation

```julia
using Pkg
Pkg.add("SciMLLogging")
```

SciMLLogging.jl provides a structured approach to controlling verbosity in scientific computing workflows. It enables:

Fine-grained control over which messages are displayed and at what levels
Hierarchical organization of verbosity settings by component and message type

Consistent logging patterns across the SciML ecosystem

# Basic Usage

```julia
using SciMLLogging: AbstractVerbositySpecifier, MessageLevel, WarnLevel, InfoLevel, Silent, ErrorLevel
using Logging

# Create a simple verbosity structure
struct MyVerbosity{T} <: AbstractVerbositySpecifier{T}
    algorithm_choice::MessageLevel
    iteration_progress::MessageLevel

    function MyVerbosity{T}(;
            algorithm_choice = WarnLevel(),
            iteration_progress = InfoLevel()
    ) where {T}
        new{T}(algorithm_choice, iteration_progress)
    end
end

# Create enabled verbosity
verbose = MyVerbosity{true}()

# Log messages at different levels
@SciMLMessage("Selected algorithm: GMRES", verbose, :algorithm_choice)
@SciMLMessage("Iteration 5/100 complete", verbose, :iteration_progress)

# Use a function to create the message
@SciMLMessage(verbose, :iteration_progress) do
    iter = 10
    total = 100
    progress = iter/total * 100
    "Iteration $iter/$total complete ($(round(progress, digits=1))%)"
end
```

# Verbosity Levels

SciMLLogging supports several verbosity levels:

  - `Silent()`: No output
  - `InfoLevel()`: Informational messages
  - `WarnLevel()`: Warning messages
  - `ErrorLevel()`: Error messages
  - `CustomLevel(n)`: Custom logging level with integer value `n`

# Creating Custom Verbosity Types

 1. Define a structure for each group of verbosity options
 2. Create a main verbosity struct that inherits from AbstractVerbositySpecifier{T}
 3. Define constructors for easy creation and default values
    Example:

```julia
# Main verbosity struct with direct LogLevel fields
struct MyAppVerbosity{T} <: AbstractVerbositySpecifier{T}
    solver_iterations::MessageLevel
    solver_convergence::MessageLevel
    performance_timing::MessageLevel
    performance_memory::MessageLevel

    function MyAppVerbosity{T}(;
            solver_iterations = InfoLevel(),
            solver_convergence = WarnLevel(),
            performance_timing = Silent(),
            performance_memory = Silent()
    ) where {T}
        new{T}(solver_iterations, solver_convergence, performance_timing, performance_memory)
    end
end

# Constructor with enable/disable parameter
MyAppVerbosity(; enable = true, kwargs...) = MyAppVerbosity{enable}(; kwargs...)
```

Integration with Julia's Logging System
SciMLVerbosity integrates with Julia's built-in logging system. You can customize how logs are handled with the SciMLLogger,
which allows you to direct logs to different outputs. Or you can use your own logger based on the Julia logging system or LoggingExtras.jl.

```julia
# Create a logger that sends warnings to a file
log_file = "warnings.log"
logger = SciMLLogger(
    info_repl = true,     # Show info in REPL
    warn_repl = true,     # Show warnings in REPL
    error_repl = true,    # Show errors in REPL
    warn_file = log_file  # Also log warnings to file
)

# Use the logger
with_logger(logger) do
    # Your code with @SciMLMessage calls
end
```

Disabling Verbosity
To completely disable verbosity without changing your code:

```julia
# Create disabled verbosity
silent = MyVerbosity{false}()

# This won't produce any output
@SciMLMessage("This message won't be shown", silent, :algorithm_choice)
```

# License

SciMLLogging.jl is licensed under the MIT License.
