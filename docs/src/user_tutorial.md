# User Tutorial: Configuring Package Verbosity

This tutorial is for end users who want to control the verbosity of packages that use SciMLLogging.jl.
Each package will have it's own implementation of the `AbstractVerbositySpecifier` type, which defines the available verbosity options. This guide is meant to be a general guide to the specifics of SciMLLogging.jl, as well as give some examples of how the system is typically implemented. For details on the specific verbosity settings of a package, refer to the package's documentation.

## Understanding Verbosity Specifiers

Before diving into usage, let's understand what a VerbositySpecifier looks like with a simple example. Typically, the `SolverVerbosity` type, would be implemented in a package like so:

```julia
using SciMLLogging
using ConcreteStructs: @concrete

# Example VerbositySpecifier from a hypothetical solver package
@concrete struct SolverVerbosity <: AbstractVerbositySpecifier
    initialization    # Controls startup messages
    iterations        # Controls per-iteration output
    convergence       # Controls convergence messages
    warnings          # Controls warning messages
end
```

**What this means:**
- **Each field**: Represents a category of messages the package can emit
- **Field values**: Can be `Silent()`, `InfoLevel()`, `WarnLevel()`, `ErrorLevel()`, or `CustomLevel(n)` for custom levels
- **`@concrete`**: Used for better performance by eliminating type instabilities

Each category can be individually controlled by setting the field to the appropriate message level.

## Quick Start

Typically, packages that use SciMLLogging will provide a keyword argument such as `verbose` or `verbosity` to some top-level function. This keyword argument will take an `AbstractVerbositySpecifier` implementation, defined in that package, that will control which messages get passed to the logging system, and at what level these messages will be emitted at. 

### Example of a typical AbstractVerbositySpecifier

Here's an example of how one might use a packages `AbstractVerbositySpecifier` implementation to control the output, using the same `SolverVerbosity` type as above. 

```julia
# Example: Customizing a solver's verbosity
verbose_settings = SolverVerbosity(
    initialization = InfoLevel(),      # Show startup messages
    iterations = Silent(),        # Don't show each iteration
    convergence = InfoLevel(),         # Show when it converges
    error_control = WarnLevel()            # Show warnings
)

result = solve(problem, verbose = verbose_settings)
```

**Explanation of the example above:**
- `SolverVerbosity()` creates a verbosity specifier with the given settings
- `initialization = InfoLevel()` means startup messages will be shown as informational logs
- `iterations = Silent()` means iteration progress won't be shown at all
- `convergence = InfoLevel()` means messages related to convergence will be shown as informational logs
- `error_control = WarnLevel()` means message about controlling solver error will be shown as warning-level logs

### Using Verbosity Presets

SciMLLogging also provides an abstract `VerbosityPreset` type. The ones provided by `SciMLLogging` are:
- `None()`: Log nothing at all 
- `Minimal()`: Preset that shows only essential messages
- `Standard()`: Preset that provides balanced verbosity suitable for typical usage
- `Detailed()`: Preset that provides comprehensive verbosity for debugging and detailed
analysis
- `All()`: Preset that enables maximum verbosity


These types are meant to set each field of an `AbstractVerbositySpecifier` to a predefined `MessageLevel`. 
For example:
```julia
none_verbose = SolverVerbosity(None())
# Would be equivalent to 
SolverVerbosity{false}(
    initialization = Silent(),   
    iterations = Silent(),        
    convergence = Silent(),       
    error_control = Silent())


standard_verbose = SolverVerbosity(Standard())
# Would be equivalent to 
SolverVerbosity{true}(
    initialization = Info(),   
    iterations = Silent(),        
    convergence = Warn(),       
    error_control = Info())
```

```julia
using SciMLLogging  # To access preset types

# Minimal output - only critical messages
result = solve(problem, verbose = SolverVerbosity(Minimal()))

# Maximum output - show everything
result = solve(problem, verbose = SolverVerbosity(All()))

# No output at all
result = solve(problem, verbose = SolverVerbosity(None()))
```
## Working with Different Output Backends

### Standard Julia Logging

By default, messages go through Julia's standard logging system. That means that onces a log message is emitted, it can be filtered, sent to other files, and generally processed using the standard Julia logging system. For more details see the [Logging documentation](https://docs.julialang.org/en/v1/stdlib/Logging/). 

#### Redirecting Output to Files

If using the Logging.jl backend, you can redirect messages to files using Julia's logging system:

```julia
using Logging

# Save all output to a file
open("solver_output.log", "w") do io
    with_logger(SimpleLogger(io)) do
        result = solve_problem(problem, verbose = true)
    end
end

# Or use the built-in SciMLLogger for more control
using SciMLLogging

logger = SciMLLogger(
    info_repl = true,           # Show info in REPL
    warn_repl = true,           # Show warnings in REPL
    error_repl = true,          # Show errors in REPL
    info_file = "info.log",     # Save info messages to file
    warn_file = "warnings.log", # Save warnings to file
    error_file = "errors.log"   # Save errors to file
)

with_logger(logger) do
    result = solve(problem, verbose = SolverVerbosity(Standard()))
end
```

### Simple Console Output

SciMLLogging can also be configured to use `Core.println` to display messages instead of the full logging system. This is done through a [Preferences.jl](https://github.com/JuliaPackaging/Preferences.jl) setting. 

```julia
using SciMLLogging

# Switch to simple Core.println output (if supported by the package)
SciMLLogging.set_logging_backend("core")

# Switch back to standard logging
SciMLLogging.set_logging_backend("logging")
```

Note: You need to restart Julia after changing the backend preference in order to use the chosen backend.


## Common Scenarios

### Running Experiments with Minimal Output

When running many experiments, you might want minimal output:

```julia
results = []
for param in parameter_sweep
    # Only show errors and critical information
    result = solve(param, verbose = SolverVerbosity(Minimal()))
    push!(results, result)
end
```

### Debugging Issues

When troubleshooting problems, enable maximum verbosity:

```julia
# Show everything to understand what's happening
result = solve(problematic_case, verbose = SolverVerbosity(All()))

# Or create custom settings to focus on specific aspects
debug_verbose = SolverVerbosity(
    initialization = InfoLevel(),
    iterations = InfoLevel(),        # Now show iterations for debugging
    convergence = InfoLevel(),
    warnings = WarnLevel()
)

result = solve_problem(problematic_case, verbose = debug_verbose)
```