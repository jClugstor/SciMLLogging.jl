module SciMLLogging

import Moshi.Data: @data
import Moshi.Match: @match
import Logging
using LoggingExtras

include("utils.jl")

# Export public API
export AbstractVerbositySpecifier, Verbosity
export @SciMLMessage
export verbosity_to_int, verbosity_to_bool
export SciMLLogger

end
