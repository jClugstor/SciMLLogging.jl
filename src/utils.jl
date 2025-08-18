"""
    Verbosity

A sum type representing different verbosity levels.

# Variants
- `None`: No output
- `Info`: Maps to `Logging.Info`
- `Warn`: Maps to `Logging.Warn`  
- `Error`: Maps to `Logging.Error`
- `Level(Int)`: Custom log level
- `Edge`: Special case handling
- `All`: Maximum verbosity
- `Default`: Default settings
- `Code(Expr)`: Execute custom code
"""
@data Verbosity begin
    None
    Info
    Warn
    Error
    Level(Int)
    Edge
    All
    Default
    Code(Expr)
end

"""
    AbstractVerbositySpecifier{T}

Abstract base type for verbosity specifiers.

The type parameter `T` is a boolean:
- `T = true`: Verbosity enabled, messages will be processed
- `T = false`: Verbosity disabled, no runtime overhead
"""
abstract type AbstractVerbositySpecifier{T} end

# Utilities 

function message_level(verbose::AbstractVerbositySpecifier{true}, option, group)
    group = getproperty(verbose, group)
    opt_level = getproperty(group, option)

    @match opt_level begin
        Verbosity.Code(expr) => expr
        Verbosity.None() => nothing
        Verbosity.Info() => Logging.Info
        Verbosity.Warn() => Logging.Warn
        Verbosity.Error() => Logging.Error
        Verbosity.Level(i) => Logging.LogLevel(i)
    end
end

function emit_message(
        f::Function, verbose::V, option, group, file, line,
        _module) where {V <: AbstractVerbositySpecifier{true}}
    level = message_level(
        verbose, option, group)

    if level isa Expr
        level
    elseif !isnothing(level)
        message = f()
        Base.@logmsg level message _file=file _line=line _module=_module
    end
end

function emit_message(message::String, verbose::V,
        option, group, file, line, _module) where {V <: AbstractVerbositySpecifier{true}}
    level = message_level(verbose, option, group)

    if !isnothing(level)
        Base.@logmsg level message _file=file _line=line _module=_module _group=group
    end
end

function emit_message(
        f, verbose::AbstractVerbositySpecifier{false}, option, group, file, line, _module)
end

"""
    @SciMLMessage(message_or_function, verbose, option, group)

Emit a log message based on verbosity settings.

# Arguments
- `message_or_function`: String message or 0-argument function returning a string
- `verbose`: An `AbstractVerbositySpecifier` instance
- `option`: Symbol for the specific option (e.g., `:test1`)
- `group`: Symbol for the group containing the option (e.g., `:options`)

# Examples
```julia
# String message
@SciMLMessage("Hello", verbose, :test1, :options)

# Function for lazy evaluation
x = 10
y = 20
@SciMLMessage(verbose, :test1, :options) do
    z = x + y
    "Sum: \$z"
end
```
"""
macro SciMLMessage(f_or_message, verb, option, group)
    line = __source__.line
    file = string(__source__.file)
    _module = __module__
    return :(emit_message(
        $(esc(f_or_message)), $(esc(verb)), $option, $group, $file, $line, $_module))
end

"""
    verbosity_to_int(verb::Verbosity.Type)

Convert a `Verbosity.Type` to an integer.

# Mapping
- `None()` → 0
- `Info()` → 1
- `Warn()` → 2
- `Error()` → 3
- `Level(i)` → i
"""
function verbosity_to_int(verb::Verbosity.Type)
    @match verb begin
        Verbosity.None() => 0
        Verbosity.Info() => 1
        Verbosity.Warn() => 2
        Verbosity.Error() => 3
        Verbosity.Level(i) => i
    end
end

"""
    verbosity_to_bool(verb::Verbosity.Type)

Convert a `Verbosity.Type` to a boolean.

Returns `false` for `Verbosity.None()`, `true` for all other levels.
"""
function verbosity_to_bool(verb::Verbosity.Type)
    @match verb begin
        Verbosity.None() => false
        _ => true
    end
end

"""
    SciMLLogger(; kwargs...)

Create a logger that routes messages to REPL and/or files based on log level.

# Keyword Arguments
- `info_repl = true`: Show info messages in REPL
- `warn_repl = true`: Show warnings in REPL
- `error_repl = true`: Show errors in REPL
- `info_file = nothing`: File path for info messages
- `warn_file = nothing`: File path for warnings
- `error_file = nothing`: File path for errors
"""
function SciMLLogger(; info_repl = true, warn_repl = true, error_repl = true,
        info_file = nothing, warn_file = nothing, error_file = nothing)
    info_sink = isnothing(info_file) ? NullLogger() : FileLogger(info_file)
    warn_sink = isnothing(warn_file) ? NullLogger() : FileLogger(warn_file)
    error_sink = isnothing(error_file) ? NullLogger() : FileLogger(error_file)

    repl_filter = EarlyFilteredLogger(current_logger()) do log
        if log.level == Logging.Info && info_repl
            return true
        end

        if log.level == Logging.Warn && warn_repl
            return true
        end

        if log.level == Logging.Error && error_repl
            return true
        end

        return false
    end

    info_filter = EarlyFilteredLogger(info_sink) do log
        log.level == Logging.Info
    end

    warn_filter = EarlyFilteredLogger(warn_sink) do log
        log.level == Logging.Warn
    end

    error_filter = EarlyFilteredLogger(error_sink) do log
        log.level == Logging.Error
    end

    TeeLogger(repl_filter, info_filter, warn_filter, error_filter)
end
