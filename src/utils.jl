@data Verbosity begin
    None
    Info
    Warn
    Error
    Level(Int)
    Edge
    All
    Default
end

"""
$(TYPEDEF)

Base for types which specify which log messages are emitted at what level.
"""
abstract type AbstractVerbositySpecifier{T} end




# Utilities 

function message_level(verbose::AbstractVerbositySpecifier{true}, option, group)
    group = getproperty(verbose, group)
    opt_level = getproperty(group, option)

    @match opt_level begin
        Verbosity.None() => nothing
        Verbosity.Info() => Logging.Info
        Verbosity.Warn() => Logging.Warn
        Verbosity.Error() => Logging.Error
        Verbosity.Level(i) => Logging.LogLevel(i)
    end
end

function emit_message(
    f::Function, verbose::V, option, group, file, line,
    _module) where {V<:AbstractVerbositySpecifier{true}}
    level = message_level(
        verbose, option, group)
    if !isnothing(level)
        message = f()
        Base.@logmsg level message _file = file _line = line _module = _module
    end
end

function emit_message(message::String, verbose::V,
    option, group, file, line, _module) where {V<:AbstractVerbositySpecifier{true}}
    level = message_level(verbose, option, group)

    if !isnothing(level)
        Base.@logmsg level message _file = file _line = line _module = _module _group = group
    end
end

function emit_message(
    f, verbose::AbstractVerbositySpecifier{false}, option, group, file, line, _module)
end

@doc doc"""
A macro that emits a log message based on the log level specified in the `option` and `group` of the `AbstractVerbositySpecifier` supplied. 
    
`f_or_message` may be a message String, or a 0-argument function that returns a String. 

## Usage
To emit a simple string, `@SciMLMessage("message", verbosity, :option, :group)` will emit a log message with the LogLevel specified in `verbosity`, at the appropriate `option` and `group`. 

`@SciMLMessage` can also be used to emit a log message coming from the evaluation of a 0-argument function. This function is resolved in the environment of the macro call.
Therefore it can use variables from the surrounding environment. This may be useful if the log message writer wishes to carry out some calculations using existing variables
and use them in the log message.

```julia
x = 10
y = 20

@SciMLMessage(verbosity, :option, :group) do 
    z = x + y
    "Message is: x + y = \$z"
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

function SciMLLogger(; info_repl=true, warn_repl=true, error_repl=true,
    info_file=nothing, warn_file=nothing, error_file=nothing)
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