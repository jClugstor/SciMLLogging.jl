using SciMLLogging
using SciMLLogging: Verbosity, AbstractVerbositySpecifier, @SciMLMessage
using Logging
using Test

# Structs for testing package - simplified structure
struct TestVerbosity{T} <: AbstractVerbositySpecifier{T}
    test1::Verbosity.LogLevel
    test2::Verbosity.LogLevel
    test3::Verbosity.LogLevel
    test4::Verbosity.LogLevel

    function TestVerbosity{T}(;
            test1 = Verbosity.Warn(),
            test2 = Verbosity.Info(),
            test3 = Verbosity.Error(),
            test4 = Verbosity.Silent()) where T
        new{T}(test1, test2, test3, test4)
    end
end

TestVerbosity() = TestVerbosity{true}()
TestVerbosity(enabled::Bool) = enabled ? TestVerbosity{true}() : TestVerbosity{false}()

function TestVerbosity(preset::Verbosity.VerbosityPreset)
    if preset isa Verbosity.None
        TestVerbosity{false}()
    elseif preset isa Verbosity.All
        TestVerbosity{true}(
            test1 = Verbosity.Info(),
            test2 = Verbosity.Info(),
            test3 = Verbosity.Info(),
            test4 = Verbosity.Info()
        )
    elseif preset isa Verbosity.Minimal
        TestVerbosity{true}(
            test1 = Verbosity.Error(),
            test2 = Verbosity.Silent(),
            test3 = Verbosity.Error(),
            test4 = Verbosity.Silent()
        )
    else
        TestVerbosity{true}()
    end
end

# Tests 

@testset "Basic tests" begin
    verbose = TestVerbosity{true}()

    @test_logs (:warn, "Test1") @SciMLMessage("Test1", verbose, :test1)
    @test_logs (:info, "Test2") @SciMLMessage("Test2", verbose, :test2)
    @test_logs (:error, "Test3") @SciMLMessage("Test3", verbose, :test3)
    @test_logs min_level = Logging.Debug @SciMLMessage("Test4", verbose, :test4)

    x = 30
    y = 30

    @test_logs (:warn, "Test1: 60") @SciMLMessage(verbose, :test1) do
        z = x + y
        "Test1: $z"
    end
end

@testset "Verbosity presets" begin
    # Test with different presets
    verbose_all = TestVerbosity(Verbosity.All())
    verbose_minimal = TestVerbosity(Verbosity.Minimal())
    verbose_none = TestVerbosity(Verbosity.None())

    # All preset should log info level messages
    @test_logs (:info, "All preset test") @SciMLMessage("All preset test", verbose_all, :test1)

    # Minimal preset should only log errors
    @test_logs (:error, "Minimal preset test") @SciMLMessage("Minimal preset test", verbose_minimal, :test1)

    # None preset should not log anything
    @test_logs min_level = Logging.Debug @SciMLMessage("None preset test", verbose_none, :test1)
end

@testset "Disabled verbosity" begin
    verbose_off = TestVerbosity{false}()

    # Should not log anything when verbosity is disabled
    @test_logs min_level = Logging.Debug @SciMLMessage("Should not appear", verbose_off, :test1)
    @test_logs min_level = Logging.Debug @SciMLMessage("Should not appear", verbose_off, :test2)
end

@testset "Backwards compatibility" begin
    verbose = TestVerbosity{true}()

    # Test 4-argument version for backwards compatibility
    # The group argument should be ignored but the macro should still work
    @test_logs (:warn, "Backwards compat test") @SciMLMessage("Backwards compat test", verbose, :test1, :ignored_group)
    @test_logs (:info, "Backwards compat test 2") @SciMLMessage("Backwards compat test 2", verbose, :test2, :another_ignored_group)

    # Test function-based version with 4 arguments
    x = 42
    @test_logs (:error, "Backwards function test: 42") @SciMLMessage(verbose, :test3, :ignored_group) do
        "Backwards function test: $x"
    end
end
