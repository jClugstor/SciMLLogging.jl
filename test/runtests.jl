using SciMLLogging
using SciMLLogging: None, Minimal, Standard, All, AbstractVerbosityPreset
using Test
using SafeTestsets

@time @safetestset "Basic Tests" include("basics.jl")
@time @safetestset "Basic Tests" include("generation_test.jl")