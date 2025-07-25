using SciMLVerbosity
using Test
using SafeTestSets

@time @safetestset "Basic Tests" include("test/basics.jl")
