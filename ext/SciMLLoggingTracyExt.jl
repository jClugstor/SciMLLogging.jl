module SciMLLoggingTracyExt

using SciMLLogging
using Tracy
import Logging

# Map log levels to Tracy color symbols
function level_to_color(level)
    if level == Logging.Debug
        return :cyan
    elseif level == Logging.Info
        return :green
    elseif level == Logging.Warn
        return :yellow
    elseif level == Logging.Error
        return :red
    else
        return :white  # Default for custom levels
    end
end

# Override the fallback implementation when Tracy is loaded
function SciMLLogging.emit_tracy_message(msg, level, _file, _line, __module)
    # Use Tracy.jl's tracymsg to emit the message with color based on log level
    # The message will show up in the Tracy profiler with appropriate color
    color = level_to_color(level)
    return Tracy.tracymsg(msg; color)
end

end
