@define_verbosity_specifier VerbSpec begin
    toggles = (:toggle1, :toggle2, :toggle3, :toggle4, :toggle5,
        :toggle6, :toggle7, :toggle8, :toggle9, :toggle10)

    preset_map = (
        None = (
            toggle1 = Silent(),
            toggle2 = Silent(),
            toggle3 = Silent(),
            toggle4 = Silent(),
            toggle5 = Silent(),
            toggle6 = Silent(),
            toggle7 = Silent(),
            toggle8 = Silent(),
            toggle9 = Silent(),
            toggle10 = Silent()
        ),
        Minimal = (
            toggle1 = WarnLevel(),
            toggle2 = Silent(),
            toggle3 = ErrorLevel(),
            toggle4 = DebugLevel(),
            toggle5 = InfoLevel(),
            toggle6 = WarnLevel(),
            toggle7 = Silent(),
            toggle8 = InfoLevel(),
            toggle9 = DebugLevel(),
            toggle10 = ErrorLevel()
        ),
        Standard = (
            toggle1 = InfoLevel(),
            toggle2 = WarnLevel(),
            toggle3 = DebugLevel(),
            toggle4 = ErrorLevel(),
            toggle5 = Silent(),
            toggle6 = InfoLevel(),
            toggle7 = DebugLevel(),
            toggle8 = WarnLevel(),
            toggle9 = Silent(),
            toggle10 = ErrorLevel()
        ),
        Detailed = (
            toggle1 = DebugLevel(),
            toggle2 = InfoLevel(),
            toggle3 = Silent(),
            toggle4 = WarnLevel(),
            toggle5 = ErrorLevel(),
            toggle6 = DebugLevel(),
            toggle7 = ErrorLevel(),
            toggle8 = Silent(),
            toggle9 = WarnLevel(),
            toggle10 = InfoLevel()
        ),
        All = (
            toggle1 = ErrorLevel(),
            toggle2 = DebugLevel(),
            toggle3 = InfoLevel(),
            toggle4 = Silent(),
            toggle5 = WarnLevel(),
            toggle6 = ErrorLevel(),
            toggle7 = InfoLevel(),
            toggle8 = DebugLevel(),
            toggle9 = WarnLevel(),
            toggle10 = Silent()
        )
    )

    groups = (
        numerical = (:toggle1, :toggle2, :toggle3),
        performance = (:toggle4, :toggle5, :toggle6, :toggle7),
        error_control = (:toggle8, :toggle9, :toggle10)
    )
end

using Test

@testset "VerbSpec Constructor Tests" begin
    # Test 1: Default constructor (no arguments) - should use Standard preset
    @testset "Default constructor" begin
        v = SciMLLogging.VerbSpec()
        @test v.toggle1 == InfoLevel()
        @test v.toggle2 == WarnLevel()
        @test v.toggle3 == DebugLevel()
        @test v.toggle10 == ErrorLevel()
    end

    # Test 2: Preset constructors
    @testset "Preset constructors" begin
        # None preset
        v_none = SciMLLogging.VerbSpec(None())
        @test all(getfield(v_none, f) == Silent() for f in fieldnames(typeof(v_none)))

        # Minimal preset
        v_min = SciMLLogging.VerbSpec(Minimal())
        @test v_min.toggle1 == WarnLevel()
        @test v_min.toggle2 == Silent()
        @test v_min.toggle3 == ErrorLevel()

        # Standard preset
        v_std = SciMLLogging.VerbSpec(Standard())
        @test v_std.toggle1 == InfoLevel()
        @test v_std.toggle2 == WarnLevel()

        # Detailed preset
        v_det = SciMLLogging.VerbSpec(Detailed())
        @test v_det.toggle1 == DebugLevel()
        @test v_det.toggle2 == InfoLevel()

        # All preset
        v_all = SciMLLogging.VerbSpec(All())
        @test v_all.toggle1 == ErrorLevel()
        @test v_all.toggle2 == DebugLevel()
    end

    # Test 3: Keyword constructor with preset parameter
    @testset "Keyword constructor with preset" begin
        v = SciMLLogging.VerbSpec(preset=Minimal())
        @test v.toggle1 == WarnLevel()
        @test v.toggle2 == Silent()
    end

    # Test 4: Group parameters
    @testset "Group parameters" begin
        # Set all numerical toggles to ErrorLevel
        v = SciMLLogging.VerbSpec(numerical=ErrorLevel())
        @test v.toggle1 == ErrorLevel()  # numerical group
        @test v.toggle2 == ErrorLevel()  # numerical group
        @test v.toggle3 == ErrorLevel()  # numerical group
        @test v.toggle4 == ErrorLevel()  # performance group (from Standard preset)

        # Set all performance toggles
        v2 = SciMLLogging.VerbSpec(performance=InfoLevel())
        @test v2.toggle4 == InfoLevel()  # performance group
        @test v2.toggle5 == InfoLevel()  # performance group
        @test v2.toggle6 == InfoLevel()  # performance group
        @test v2.toggle7 == InfoLevel()  # performance group

        # Set all error_control toggles
        v3 = SciMLLogging.VerbSpec(error_control=DebugLevel())
        @test v3.toggle8 == DebugLevel()  # error_control group
        @test v3.toggle9 == DebugLevel()  # error_control group
        @test v3.toggle10 == DebugLevel()  # error_control group
    end

    # Test 5: Individual toggle parameters
    @testset "Individual toggle parameters" begin
        v = SciMLLogging.VerbSpec(toggle1=ErrorLevel())
        @test v.toggle1 == ErrorLevel()
        @test v.toggle2 == WarnLevel()  # from Standard preset

        # Multiple individual toggles
        v2 = SciMLLogging.VerbSpec(toggle1=ErrorLevel(), toggle5=WarnLevel())
        @test v2.toggle1 == ErrorLevel()
        @test v2.toggle5 == WarnLevel()
    end

    # Test 6: Precedence: individual > group > preset
    @testset "Precedence tests" begin
        # Individual overrides group
        v = SciMLLogging.VerbSpec(numerical=WarnLevel(), toggle1=ErrorLevel())
        @test v.toggle1 == ErrorLevel()  # individual wins
        @test v.toggle2 == WarnLevel()   # from group
        @test v.toggle3 == WarnLevel()   # from group

        # Group overrides preset
        v2 = SciMLLogging.VerbSpec(preset=None(), numerical=InfoLevel())
        @test v2.toggle1 == InfoLevel()  # from group
        @test v2.toggle4 == Silent()     # from preset (not in numerical group)

        # All three levels
        v3 = SciMLLogging.VerbSpec(preset=None(), performance=WarnLevel(), toggle4=ErrorLevel())
        @test v3.toggle4 == ErrorLevel()  # individual wins
        @test v3.toggle5 == WarnLevel()   # from group
        @test v3.toggle1 == Silent()      # from preset
    end

    # Test 7: Combining preset with groups
    @testset "Preset with groups" begin
        v = SciMLLogging.VerbSpec(preset=Minimal(), numerical=DebugLevel())
        @test v.toggle1 == DebugLevel()  # from group
        @test v.toggle2 == DebugLevel()  # from group
        @test v.toggle3 == DebugLevel()  # from group
        @test v.toggle4 == DebugLevel()  # from Minimal preset
    end

    # Test 8: All three: preset, groups, and individual toggles
    @testset "Preset + groups + individual toggles" begin
        v = SciMLLogging.VerbSpec(
            preset=Detailed(),
            numerical=ErrorLevel(),
            performance=WarnLevel(),
            toggle1=InfoLevel(),
            toggle4=DebugLevel()
        )
        @test v.toggle1 == InfoLevel()   # individual wins
        @test v.toggle2 == ErrorLevel()  # from numerical group
        @test v.toggle3 == ErrorLevel()  # from numerical group
        @test v.toggle4 == DebugLevel()  # individual wins
        @test v.toggle5 == WarnLevel()   # from performance group
        @test v.toggle8 == Silent()      # from Detailed preset
    end

    # Test 9: Type stability - ensure parametric types work
    @testset "Type stability" begin
        v = SciMLLogging.VerbSpec()
        @test typeof(v) <: SciMLLogging.VerbSpec
        @test isconcretetype(typeof(v))
    end

    # Test 10: Error handling
    @testset "Error handling" begin
        # Invalid group argument type
        @test_throws ArgumentError SciMLLogging.VerbSpec(numerical="invalid")

        # Invalid individual toggle type
        @test_throws ArgumentError SciMLLogging.VerbSpec(toggle1="invalid")

        # Unknown toggle name
        @test_throws ArgumentError SciMLLogging.VerbSpec(unknown_toggle=ErrorLevel())

        # Invalid preset type
        @test_throws ArgumentError SciMLLogging.VerbSpec(preset="invalid")
    end
end



# LinearVerbosity configuration
@define_verbosity_specifier LinearVerbosity begin
    toggles = (
        :default_lu_fallback,
        :no_right_preconditioning,
        :using_IterativeSolvers,
        :IterativeSolvers_iterations,
        :KrylovKit_verbosity,
        :KrylovJL_verbosity,
        :HYPRE_verbosity,
        :pardiso_verbosity,
        :blas_errors,
        :blas_invalid_args,
        :blas_info,
        :blas_success,
        :condition_number,
        :convergence_failure,
        :solver_failure,
        :max_iters
    )

    preset_map = (
        None = (
            default_lu_fallback = Silent(),
            no_right_preconditioning = Silent(),
            using_IterativeSolvers = Silent(),
            IterativeSolvers_iterations = Silent(),
            KrylovKit_verbosity = Silent(),
            KrylovJL_verbosity = Silent(),
            HYPRE_verbosity = Silent(),
            pardiso_verbosity = Silent(),
            blas_errors = Silent(),
            blas_invalid_args = Silent(),
            blas_info = Silent(),
            blas_success = Silent(),
            condition_number = Silent(),
            convergence_failure = Silent(),
            solver_failure = Silent(),
            max_iters = Silent()
        ),
        Minimal = (
            default_lu_fallback = Silent(),
            no_right_preconditioning = Silent(),
            using_IterativeSolvers = Silent(),
            IterativeSolvers_iterations = Silent(),
            KrylovKit_verbosity = Silent(),
            KrylovJL_verbosity = Silent(),
            HYPRE_verbosity = Silent(),
            pardiso_verbosity = Silent(),
            blas_errors = WarnLevel(),
            blas_invalid_args = WarnLevel(),
            blas_info = Silent(),
            blas_success = Silent(),
            condition_number = Silent(),
            convergence_failure = Silent(),
            solver_failure = Silent(),
            max_iters = Silent()
        ),
        Standard = (
            default_lu_fallback = Silent(),
            no_right_preconditioning = Silent(),
            using_IterativeSolvers = Silent(),
            IterativeSolvers_iterations = Silent(),
            KrylovKit_verbosity = CustomLevel(1),
            KrylovJL_verbosity = Silent(),
            HYPRE_verbosity = InfoLevel(),
            pardiso_verbosity = Silent(),
            blas_errors = WarnLevel(),
            blas_invalid_args = WarnLevel(),
            blas_info = Silent(),
            blas_success = Silent(),
            condition_number = Silent(),
            convergence_failure = WarnLevel(),
            solver_failure = WarnLevel(),
            max_iters = WarnLevel()
        ),
        Detailed = (
            default_lu_fallback = WarnLevel(),
            no_right_preconditioning = InfoLevel(),
            using_IterativeSolvers = InfoLevel(),
            IterativeSolvers_iterations = Silent(),
            KrylovKit_verbosity = CustomLevel(2),
            KrylovJL_verbosity = CustomLevel(1),
            HYPRE_verbosity = InfoLevel(),
            pardiso_verbosity = CustomLevel(1),
            blas_errors = WarnLevel(),
            blas_invalid_args = WarnLevel(),
            blas_info = InfoLevel(),
            blas_success = InfoLevel(),
            condition_number = Silent(),
            convergence_failure = WarnLevel(),
            solver_failure = WarnLevel(),
            max_iters = WarnLevel()
        ),
        All = (
            default_lu_fallback = WarnLevel(),
            no_right_preconditioning = InfoLevel(),
            using_IterativeSolvers = InfoLevel(),
            IterativeSolvers_iterations = InfoLevel(),
            KrylovKit_verbosity = CustomLevel(3),
            KrylovJL_verbosity = CustomLevel(1),
            HYPRE_verbosity = InfoLevel(),
            pardiso_verbosity = CustomLevel(1),
            blas_errors = WarnLevel(),
            blas_invalid_args = WarnLevel(),
            blas_info = InfoLevel(),
            blas_success = InfoLevel(),
            condition_number = InfoLevel(),
            convergence_failure = WarnLevel(),
            solver_failure = WarnLevel(),
            max_iters = WarnLevel()
        )
    )

    groups = (
        error_control = (:default_lu_fallback, :blas_errors, :blas_invalid_args),
        performance = (:no_right_preconditioning,),
        numerical = (:using_IterativeSolvers, :IterativeSolvers_iterations,
                     :KrylovKit_verbosity, :KrylovJL_verbosity, :HYPRE_verbosity,
                     :pardiso_verbosity, :blas_info, :blas_success, :condition_number,
                     :convergence_failure, :solver_failure, :max_iters)
    )
end

# Test LinearVerbosity
@testset "LinearVerbosity Tests" begin
    @testset "Default constructor" begin
        v = LinearVerbosity()
        @test v.blas_errors == WarnLevel()
        @test v.default_lu_fallback == Silent()
        @test v.KrylovKit_verbosity == CustomLevel(1)
    end

    @testset "Preset constructors" begin
        v_none = LinearVerbosity(None())
        @test all(getfield(v_none, f) == Silent() for f in fieldnames(typeof(v_none)))

        v_min = LinearVerbosity(Minimal())
        @test v_min.blas_errors == WarnLevel()
        @test v_min.convergence_failure == Silent()
    end

    @testset "Group parameters" begin
        v = LinearVerbosity(error_control=ErrorLevel())
        @test v.default_lu_fallback == ErrorLevel()
        @test v.blas_errors == ErrorLevel()
        @test v.blas_invalid_args == ErrorLevel()
    end
end

