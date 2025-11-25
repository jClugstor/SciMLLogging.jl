module SciMLLogging

import Logging
using LoggingExtras
using Preferences

include("verbosity.jl")
include("utils.jl")
include("verbosity_specifier_generator.jl")

# Export public API
export AbstractVerbositySpecifier, AbstractVerbosityPreset, AbstractMessageLevel
export DebugLevel, InfoLevel, WarnLevel, ErrorLevel, CustomLevel, Silent
export @SciMLMessage
export verbosity_to_int, verbosity_to_bool
export SciMLLogger
export set_logging_backend, get_logging_backend
export None, Minimal, Standard, Detailed, All
export generate_verbosity_specifier, eval_verbosity_specifier, define_verbosity_specifier

end
