using SciMLVerbosity
using Test

@time @safetestset "Basic Tests" include("test/basics.jl")
