module Verbosity
    abstract type LogLevel end
    struct Silent <: LogLevel end
    struct Info <: LogLevel end
    struct Warn <: LogLevel end
    struct Error <: LogLevel end
    struct Level <: LogLevel
        level::Int
    end

    abstract type VerbosityPreset end
    struct None <: VerbosityPreset end
    struct All <: VerbosityPreset end
    struct Minimal <: VerbosityPreset end
    struct Standard <: VerbosityPreset end
    struct Detailed <: VerbosityPreset end
end

using .Verbosity

"""
AbstractVerbositySpecifier{T}
    Base for types which specify which log messages are emitted at what level.
    
"""
abstract type AbstractVerbositySpecifier{T} end

# Utilities 

function message_level(verbose::AbstractVerbositySpecifier{true}, option)
    opt_level = getproperty(verbose, option)

    if opt_level isa Verbosity.Silent
        return nothing
    elseif opt_level isa Verbosity.Info
        return Logging.Info
    elseif opt_level isa Verbosity.Warn
        return Logging.Warn
    elseif opt_level isa Verbosity.Error
        return Logging.Error
    elseif opt_level isa Verbosity.Level
        return Logging.LogLevel(opt_level.level)
    else
        return nothing
    end
end

function message_level(verbose::AbstractVerbositySpecifier{false}, option)
    return nothing
end

function emit_message(
        f::Function, verbose::AbstractVerbositySpecifier{true}, level, file, line,
        _module)
    message = f()
    Base.@logmsg level message _file=file _line=line _module=_module
end

function emit_message(message::String, verbose::AbstractVerbositySpecifier{true},
        level, file, line, _module)
    Base.@logmsg level message _file=file _line=line _module=_module
end

function emit_message(message::String, verbose::AbstractVerbositySpecifier{false},
    level, file, line, _module)
end 

function emit_message(
        f, verbose::AbstractVerbositySpecifier{false}, level, file, line, _module)
end

function emit_message(message::String, verbose::AbstractVerbositySpecifier{true},
    level::Nothing, file, line, _module)
end 

function emit_message(
    f, verbose::AbstractVerbositySpecifier{true}, option::Nothing, file, line, _module)
end


"""
A macro that emits a log message based on the log level specified in the `option` of the `AbstractVerbositySpecifier` supplied.

`f_or_message` may be a message String, or a 0-argument function that returns a String.

## Usage

To emit a simple string, `@SciMLMessage("message", verbosity, :option)` will emit a log message with the LogLevel specified in `verbosity` for the given `option`.

`@SciMLMessage` can also be used to emit a log message coming from the evaluation of a 0-argument function. This function is resolved in the environment of the macro call.
Therefore it can use variables from the surrounding environment. This may be useful if the log message writer wishes to carry out some calculations using existing variables
and use them in the log message.

```julia
# String message
@SciMLMessage("Hello", verbose, :test1)

# Function for lazy evaluation
x = 10
y = 20

@SciMLMessage(verbosity, :option) do
    z = x + y
    "Sum: \$z"
end
```
"""
macro SciMLMessage(f_or_message, verb, option)
    line = __source__.line
    file = string(__source__.file)
    _module = __module__
    expr = :(emit_message($(esc(f_or_message)), $(esc(verb)), message_level($(esc(verb)), $(esc(option))), $file, $line, $_module))
    return expr
end

# For backwards compat to be not breaking. Also might be used in the future for log filtering.
macro SciMLMessage(f_or_message, verb, option, group)
    line = __source__.line
    file = string(__source__.file)
    _module = __module__
    return :(emit_message(
        $(esc(f_or_message)), $(esc(verb)), message_level($(esc(verb)), $(esc(option))), $file, $line, $_module))
end

"""
        `verbosity_to_int(verb::Verbosity.LogLevel)`
    Takes a `Verbosity.LogLevel` and gives a corresponding integer value.
    Verbosity settings that use integers or enums that hold integers are relatively common.
    This provides an interface so that these packages can be used with SciMLVerbosity. Each of the basic verbosity levels
    are mapped to an integer.

    - Silent() => 0
    - Info() => 1
    - Warn() => 2
    - Error() => 3
    - Level(i) => i
"""
function verbosity_to_int(verb::Verbosity.LogLevel)
    if verb isa Verbosity.Silent
        return 0
    elseif verb isa Verbosity.Info
        return 1
    elseif verb isa Verbosity.Warn
        return 2
    elseif verb isa Verbosity.Error
        return 3
    elseif verb isa Verbosity.Level
        return verb.level
    else
        return 0
    end
end

"""
        `verbosity_to_bool(verb::Verbosity.LogLevel)`
    Takes a `Verbosity.LogLevel` and gives a corresponding boolean value.
    Verbosity settings that use booleans are relatively common.
    This provides an interface so that these packages can be used with SciMLVerbosity.
    If the verbosity is `Verbosity.Silent`, then `false` is returned. Otherwise, `true` is returned.
"""
function verbosity_to_bool(verb::Verbosity.LogLevel)
    if verb isa Verbosity.Silent
        return false
    else
        return true
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
