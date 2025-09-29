# User Tutorial: Configuring Package Verbosity

This tutorial is for end users who want to control the verbosity of packages that use SciMLLogging.jl. If you're using packages from the SciML ecosystem or other packages that support SciMLLogging. 

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

Most packages that use SciMLLogging provide simple ways to control their verbosity:

```julia
using SomePackage  # A package that uses SciMLLogging

# Default verbosity (usually shows important messages)
result = solve_problem(problem)

# Silent mode (no output)
result = solve_problem(problem, verbose = None())

# Verbose mode (show more details)
result = solve_problem(problem, verbose = Detailed())
```

## Understanding Verbosity Levels

SciMLLogging packages typically categorize their messages into different types:

- **Silent**: No output at all
- **InfoLevel**: General informational messages
- **WarnLevel**: Warning messages about potential issues
- **ErrorLevel**: Error messages (usually still shown even in quiet modes)

## Common Usage Patterns

### Using Verbosity Presets

Many packages provide preset verbosity levels:

```julia
using SciMLLogging  # To access preset types

# Minimal output - only critical messages
result = solve(problem, verbose = Minimal())

# Maximum output - show everything
result = solve(problem, verbose = All())

# No output at all
result = solve(problem, verbose = None())
```

### Example of a typical AbstractVerbositySpecifier

Here's an example of how one might use a packages `AbstractVerbositySpecifier` implementation to control the output.


```julia
# Example: Customizing a solver's verbosity
verbose_settings = SolverVerbosity(
    initialization = InfoLevel(),      # Show startup messages
    iterations = Silent(),        # Don't show each iteration
    convergence = InfoLevel(),         # Show when it converges
    warnings = WarnLevel()            # Show warnings
)

result = solve(problem, verbose = verbose_settings)
```

**Explanation of the example above:**
- `SolverVerbosity()` creates a verbosity specifier with the given settings
- `initialization = InfoLevel()` means startup messages will be shown as informational logs
- `iterations = Silent()` means iteration progress won't be shown at all
- `convergence = InfoLevel()` means convergence messages will be shown as informational logs
- `warnings = WarnLevel()` means warnings will be shown as warning-level logs

## Working with Different Output Backends

### Standard Julia Logging

By default, messages go through Julia's standard logging system. You can control this with the logging level:

```julia
using Logging

# Only show warnings and errors
with_logger(ConsoleLogger(stderr, Logging.Warn)) do
    result = solve_problem(problem, verbose = true)
end

# Show everything including debug messages
with_logger(ConsoleLogger(stderr, Logging.Debug)) do
    result = solve_problem(problem, verbose = true)
end
```

### Simple Console Output

Some packages may be configured to use simple console output instead of the logging system:

```julia
using SciMLLogging

# Switch to simple Core.println output (if supported by the package)
SciMLLogging.set_logging_backend("core")

# Switch back to standard logging
SciMLLogging.set_logging_backend("logging")
```

Note: You need to restart Julia after changing the backend preference.

## Redirecting Output to Files

You can redirect verbose output to files using Julia's logging system:

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
    result = solve_problem(problem, verbose = true)
end
```

## Common Scenarios

### Running Experiments Quietly

When running many experiments, you might want minimal output:

```julia
results = []
for param in parameter_sweep
    # Only show errors and critical information
    result = solve_problem(param, verbose = Minimal())
    push!(results, result)
end
```

### Debugging Issues

When troubleshooting problems, enable maximum verbosity:

```julia
# Show everything to understand what's happening
result = solve_problem(problematic_case, verbose = All())

# Or create custom settings to focus on specific aspects
debug_verbose = SolverVerbosity(
    initialization = InfoLevel(),
    iterations = InfoLevel(),        # Now show iterations for debugging
    convergence = InfoLevel(),
    warnings = WarnLevel()
)

result = solve_problem(problematic_case, verbose = debug_verbose)
```

### Production Runs

For production environments, you might want only warnings and errors:

```julia
# Custom settings for production
production_verbose = SolverVerbosity(
    initialization = Silent(),   # Don't show routine startup
    iterations = Silent(),       # Don't show progress
    convergence = Silent(),      # Don't show normal completion
    warnings = WarnLevel()           # But do show problems
)

result = solve_problem(problem, verbose = production_verbose)
```

## Package-Specific Examples

### Solver Packages

Typical solver verbosity options:

```julia
# Show convergence info but not each iteration
solver_verbose = SolverVerbosity(
    initialization = InfoLevel(),
    iterations = Silent(),
    convergence = InfoLevel(),
    warnings = WarnLevel()
)

solution = solve(problem, solver_verbose)
```

### Optimization Packages

Optimization packages might have different categories:

```julia
# Focus on optimization progress
opt_verbose = OptimizerVerbosity(
    initialization = Silent(),
    objective = InfoLevel(),      # Show objective function values
    constraints = WarnLevel(),    # Show constraint violations
    convergence = InfoLevel()
)

result = optimize(objective, constraints, opt_verbose)
```

## Tips and Best Practices

### Finding Available Options

To see what verbosity options a package provides:

```julia
# Check the documentation
?SolverVerbosity

# Look at the default constructor
SolverVerbosity()

# Many packages document their verbosity categories
```

### Testing Your Settings

Before long runs, test your verbosity settings on a small example:

```julia
# Test with a quick example first
test_result = solve_problem(small_test_case, verbose_settings)

# Then use the same settings for the full problem
result = solve_problem(full_problem, verbose_settings)
```

### Performance Considerations

- Using `verbose = false` or `None()` typically has zero runtime overhead
- Custom verbosity settings have minimal overhead
- File logging might slow down execution if there are many messages

### Combining with Julia's Built-in Logging

You can combine package verbosity with Julia's logging filters:

```julia
using Logging

# Package shows its messages, but Julia filters to only warnings+
with_logger(ConsoleLogger(stderr, Logging.Warn)) do
    result = solve_problem(problem, verbose = true)
end
```

This gives you both package-level control (what messages to generate) and system-level control (what messages to display).