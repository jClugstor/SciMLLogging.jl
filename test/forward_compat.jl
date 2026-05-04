# Tests for the forward-compatibility surface added in 1.10. These exercise
# new APIs that exist in both 1.10+ and 2.0, so downstream packages can target
# either version with the same source code.

using SciMLLogging
using SciMLLogging: SciMLLogging, AbstractVerbositySpecifier, AbstractVerbosityPreset,
    AbstractMessageLevel, Silent, DebugLevel, InfoLevel, WarnLevel, ErrorLevel,
    CustomLevel, MessageLevel, None, Minimal, Standard, Detailed, All,
    @verbosity_specifier, @SciMLMessage, is_enabled
using Test

@testset "MessageLevel(n) returns standard constants for 0..4" begin
    @test MessageLevel(0) isa Silent
    @test MessageLevel(1) isa DebugLevel
    @test MessageLevel(2) isa InfoLevel
    @test MessageLevel(3) isa WarnLevel
    @test MessageLevel(4) isa ErrorLevel
end

@testset "MessageLevel(n) returns CustomLevel for non-standard integers" begin
    @test MessageLevel(-500) isa CustomLevel
    @test MessageLevel(-500).level == -500
    @test MessageLevel(2000) isa CustomLevel
    @test MessageLevel(2000).level == 2000
end

@testset "MessageLevel result is usable in a verbosity specifier kwarg" begin
    @verbosity_specifier MLConstructorTest begin
        toggles = (:a, :b)
        presets = (
            None     = (a = Silent(),    b = Silent()),
            Minimal  = (a = Silent(),    b = Silent()),
            Standard = (a = InfoLevel(), b = WarnLevel()),
            Detailed = (a = DebugLevel(), b = InfoLevel()),
            All      = (a = DebugLevel(), b = DebugLevel()),
        )
        groups = ()
    end

    v = MLConstructorTest(a = MessageLevel(2), b = MessageLevel(3))
    @test v.a isa InfoLevel
    @test v.b isa WarnLevel
end

@testset "is_enabled returns true for any 1.x verbosity specifier" begin
    @verbosity_specifier IsEnabledTest begin
        toggles = (:x,)
        presets = (
            None     = (x = Silent(),),
            Standard = (x = InfoLevel(),),
        )
        groups = ()
    end

    @test is_enabled(IsEnabledTest()) === true
    @test is_enabled(IsEnabledTest(None())) === true   # 1.x: always true
    # On 2.0, IsEnabledTest(None()) returns a {false} instance and is_enabled
    # would be false there. The portable usage is `is_enabled(verb)` and
    # downstream code should not assume either return value across versions.
end

@testset "sub_specifiers block is recognized and treated as additional toggles" begin
    @verbosity_specifier OuterSpecForwardCompat begin
        toggles        = (:outer_a, :outer_b)
        sub_specifiers = (:inner,)

        presets = (
            None = (
                outer_a = Silent(),
                outer_b = Silent(),
                inner   = None(),
            ),
            Minimal = (
                outer_a = WarnLevel(),
                outer_b = Silent(),
                inner   = Minimal(),
            ),
            Standard = (
                outer_a = InfoLevel(),
                outer_b = WarnLevel(),
                inner   = Standard(),
            ),
            Detailed = (
                outer_a = DebugLevel(),
                outer_b = InfoLevel(),
                inner   = Detailed(),
            ),
            All = (
                outer_a = DebugLevel(),
                outer_b = DebugLevel(),
                inner   = All(),
            ),
        )

        groups = (
            outer_group = (:outer_a, :outer_b),
        )
    end

    # Default (Standard preset)
    v = OuterSpecForwardCompat()
    @test v.outer_a isa InfoLevel
    @test v.outer_b isa WarnLevel
    @test v.inner   isa Standard

    # Preset constructor sets every field, including the sub_specifier slot
    v_min = OuterSpecForwardCompat(Minimal())
    @test v_min.outer_a isa WarnLevel
    @test v_min.inner   isa Minimal

    # Override the sub_specifier via kwarg with a sub-spec instance
    @verbosity_specifier InnerForwardCompat begin
        toggles = (:t,)
        presets = (
            None     = (t = Silent(),),
            Standard = (t = InfoLevel(),),
        )
        groups = ()
    end
    inner_inst = InnerForwardCompat()
    v2 = OuterSpecForwardCompat(inner = inner_inst)
    @test v2.inner === inner_inst
    @test v2.outer_a isa InfoLevel  # from Standard preset

    # Override with a preset value
    v3 = OuterSpecForwardCompat(inner = Detailed())
    @test v3.inner isa Detailed

    # Group still works
    v4 = OuterSpecForwardCompat(outer_group = ErrorLevel())
    @test v4.outer_a isa ErrorLevel
    @test v4.outer_b isa ErrorLevel
end

@testset "sub_specifiers without explicit declaration still works (none required)" begin
    # Toggle-only spec — the new keyword being optional shouldn't change anything
    @verbosity_specifier ToggleOnly begin
        toggles = (:t,)
        presets = (
            None     = (t = Silent(),),
            Standard = (t = InfoLevel(),),
        )
        groups = ()
    end
    @test ToggleOnly().t isa InfoLevel
    @test ToggleOnly(None()).t isa Silent
end

@testset "sub_specifiers must be a tuple if provided" begin
    @test_throws LoadError @eval @verbosity_specifier BadSubSpecs begin
        toggles        = (:t,)
        sub_specifiers = "not a tuple"
        presets = (Standard = (t = InfoLevel(),),)
        groups = ()
    end
end
