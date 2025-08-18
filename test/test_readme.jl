using SciMLLogging
using Logging
using Test

# Define verbosity options
mutable struct MyOptions
    level1::Verbosity.Type
    level2::Verbosity.Type
    
    function MyOptions(;
        level1 = Verbosity.Info(),
        level2 = Verbosity.Warn()
    )
        new(level1, level2)
    end
end

# Create verbosity type
struct MyVerbosity{T} <: AbstractVerbositySpecifier{T}
    options::MyOptions
end

@testset "README Example" begin
    # Use it
    verbose = MyVerbosity{true}(MyOptions())

    # Test messages emit at correct levels
    @test_logs (:info, "Info message") @SciMLMessage("Info message", verbose, :level1, :options)
    @test_logs (:warn, "Warning message") @SciMLMessage("Warning message", verbose, :level2, :options)

    # Function form for lazy evaluation
    x = 10
    y = 20
    @test_logs (:info, "Sum: 30") @SciMLMessage(verbose, :level1, :options) do
        z = x + y
        "Sum: $z"
    end

    # Disabled verbosity (no runtime cost)
    silent = MyVerbosity{false}(MyOptions())
    @test_logs min_level=Logging.Debug @SciMLMessage("This won't show", silent, :level1, :options)
end

@testset "Utility Functions" begin
    @test verbosity_to_int(Verbosity.None()) == 0
    @test verbosity_to_int(Verbosity.Info()) == 1
    @test verbosity_to_int(Verbosity.Warn()) == 2
    @test verbosity_to_int(Verbosity.Error()) == 3
    @test verbosity_to_int(Verbosity.Level(5)) == 5
    
    @test verbosity_to_bool(Verbosity.None()) == false
    @test verbosity_to_bool(Verbosity.Info()) == true
    @test verbosity_to_bool(Verbosity.Warn()) == true
end