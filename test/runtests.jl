using Pkg
using Test
using SafeTestsets

const GROUP = get(ENV, "GROUP", "All")

function activate_downstream_env()
    Pkg.activate("downstream")
    Pkg.develop(PackageSpec(path = dirname(@__DIR__)))
    return Pkg.instantiate()
end

if GROUP == "Core" || GROUP == "All"
    @time @safetestset "Basic Tests" include("basics.jl")
    @time @safetestset "Verbosity Specifier Generation Tests" include("generation_test.jl")
    @time @safetestset "Explicit Imports" include("explicit_imports.jl")
    if isempty(VERSION.prerelease)
        Pkg.add("JET")
        @time @safetestset "JET" include("jet.jl")
    end
end

if GROUP == "Downstream"
    activate_downstream_env()
    @time @safetestset "Downstream solve JET" include("downstream/solve_jet.jl")
end
