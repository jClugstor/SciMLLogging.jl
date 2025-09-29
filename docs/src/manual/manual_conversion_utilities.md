# Conversion Utilities

SciMLLogging provides utility functions to convert message levels to common formats used by other packages.

## Integer Conversion

```@docs
verbosity_to_int
```

Convert message levels to integers for packages that use numeric verbosity levels:

```julia
using SciMLLogging

# Standard levels
verbosity_to_int(Silent())        # Returns 0
verbosity_to_int(InfoLevel())     # Returns 1
verbosity_to_int(WarnLevel())     # Returns 2
verbosity_to_int(ErrorLevel())    # Returns 3

# Custom levels
verbosity_to_int(CustomLevel(10)) # Returns 10
verbosity_to_int(CustomLevel(-5)) # Returns -5
```

## Boolean Conversion

```@docs
verbosity_to_bool
```

Convert message levels to booleans for packages that use simple on/off verbosity:

```julia
using SciMLLogging

# Silent returns false
verbosity_to_bool(Silent())        # Returns false

# All other levels return true
verbosity_to_bool(InfoLevel())     # Returns true
verbosity_to_bool(WarnLevel())     # Returns true
verbosity_to_bool(ErrorLevel())    # Returns true
verbosity_to_bool(CustomLevel(5))  # Returns true
```

## Usage Examples

### Integrating with Integer-Based Packages

```julia
# Package that expects integer verbosity levels
function external_solver(problem; verbosity_level = 0)
    if verbosity_level >= 1
        println("Starting solver...")
    end
    # ...
end

# Use with SciMLLogging
verbose_spec = MyPackageVerbosity(Standard())
level = verbosity_to_int(verbose_spec.progress)
result = external_solver(problem, verbosity_level = level)
```

### Integrating with Boolean-Based Packages

```julia
# Package that expects boolean verbosity
function simple_algorithm(data; verbose = false)
    if verbose
        println("Processing data...")
    end
    # ...
end

# Use with SciMLLogging
verbose_spec = MyPackageVerbosity(Standard())
is_verbose = verbosity_to_bool(verbose_spec.progress)
result = simple_algorithm(data, verbose = is_verbose)
```