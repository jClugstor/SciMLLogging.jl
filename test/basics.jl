using SciMLLogging
using SciMLLogging: SciMLLogging, AbstractVerbositySpecifier, @SciMLMessage, VerbosityPreset, AbstractMessageLevel, WarnLevel, InfoLevel, ErrorLevel, Silent, None, All, Minimal
using Logging
using Test

# Structs for testing package - simplified structure
struct TestVerbosity{T} <: AbstractVerbositySpecifier{T}
    test1::AbstractMessageLevel
    test2::AbstractMessageLevel
    test3::AbstractMessageLevel
    test4::AbstractMessageLevel

    function TestVerbosity{T}(;
            test1 = WarnLevel(),
            test2 = InfoLevel(),
            test3 = ErrorLevel(),
            test4 = Silent()) where {T}
        new{T}(test1, test2, test3, test4)
    end
end

TestVerbosity() = TestVerbosity{true}()
TestVerbosity(enabled::Bool) = enabled ? TestVerbosity{true}() : TestVerbosity{false}()

function TestVerbosity(preset::VerbosityPreset)
    if preset isa SciMLLogging.None
        TestVerbosity{false}()
    elseif preset isa SciMLLogging.All
        TestVerbosity{true}(
            test1 = InfoLevel(),
            test2 = InfoLevel(),
            test3 = InfoLevel(),
            test4 = InfoLevel()
        )
    elseif preset isa Minimal
        TestVerbosity{true}(
            test1 = ErrorLevel(),
            test2 = Silent(),
            test3 = ErrorLevel(),
            test4 = Silent()
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
    verbose_all = TestVerbosity(All())
    verbose_minimal = TestVerbosity(Minimal())
    verbose_none = TestVerbosity(None())

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

@testset "Nested @SciMLMessage macros" begin
    verbose = TestVerbosity{true}()

    # Test that @SciMLMessage can be called inside another @SciMLMessage function block
    @test_logs (:warn, "Inner message from nested call") (:info, "Outer message with nested result") begin
        result = @SciMLMessage(verbose, :test2) do
            @SciMLMessage("Inner message from nested call", verbose, :test1)
            "Outer message with nested result"
        end
    end

    # Test nested with both function-based inner and outer
    counter = 0
    @test_logs (:info, "Inner computation: 5") (:warn, "Outer result: 5") begin
        @SciMLMessage(verbose, :test1) do
            inner_result = @SciMLMessage(verbose, :test2) do
                counter = 5
                "Inner computation: $counter"
            end
            "Outer result: $counter"
        end
    end
end
