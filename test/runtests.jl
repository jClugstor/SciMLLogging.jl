using SciMLLogging
using Test
using SafeTestsets

@time @safetestset "Basic Tests" include("basics.jl")
@time @safetestset "README Examples" include("test_readme.jl")
