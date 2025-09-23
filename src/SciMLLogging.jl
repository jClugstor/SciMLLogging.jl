module SciMLLogging

import Logging
using LoggingExtras
using Preferences

include("verbosity.jl")
include("utils.jl")

# Export public API
export AbstractVerbositySpecifier, VerbosityPreset
export @SciMLMessage
export verbosity_to_int, verbosity_to_bool
export SciMLLogger
export set_logging_backend, get_logging_backend

end
