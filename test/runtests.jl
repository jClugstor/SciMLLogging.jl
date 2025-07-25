using SciMLVerbosity
using Test
using SafeTestsets

@time @safetestset "Basic Tests" include("test/basics.jl")
