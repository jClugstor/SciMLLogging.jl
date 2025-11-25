function generate_verbosity_specifier(name::Symbol, toggles, preset_map, groups)
    # Extract presets from preset_map keys
    presets = collect(keys(preset_map))

    # Standard presets that already exist
    standard_presets = (:None, :Minimal, :Standard, :Detailed, :All)

    # Find custom presets that need type definitions
    custom_presets = filter(p -> !(p in standard_presets), presets)

    # Generate singleton types for custom presets
    custom_preset_types = []
    for custom_preset in custom_presets
        push!(custom_preset_types, quote
            struct $custom_preset <: AbstractVerbosityPreset end
        end)
    end

    # Validate that each preset has entries for all toggles
    for preset in presets
        preset_config = preset_map[preset]
        preset_toggle_keys = keys(preset_config)
        for toggle in toggles
            if !(toggle in preset_toggle_keys)
                error("Preset :$preset is missing toggle :$toggle. Available toggles in preset: $preset_toggle_keys")
            end
        end
    end

    # Generate the verbosity specifier struct
    # Create type parameters for each toggle
    type_params = [Symbol("T$i") for i in eachindex(toggles)]

    # Build struct fields with type parameters
    struct_fields = []
    for (i, toggle) in enumerate(toggles)
        push!(struct_fields, :($(toggle)::$(type_params[i])))
    end

    # Create the parametric struct definition
    struct_def = quote
        struct $name{$(type_params...)} <: AbstractVerbositySpecifier
            $(struct_fields...)
        end
    end

    # Generate constructor that gets typeof arguments
    inner_constructor = quote
        function $name($(toggles...))
            return $name{$([:(typeof($t)) for t in toggles]...)}($(toggles...))
        end
    end

    # Generate constructors for each preset
    constructors = []
    for preset in presets
        preset_config = preset_map[preset]

        # Build the positional arguments for this preset
        field_values = []
        for toggle in toggles
            push!(field_values, preset_config[toggle])
        end

        # Create constructor function
        constructor = quote
            function $name(::$preset)
                return $name($(field_values...))
            end
        end

        push!(constructors, constructor)
    end

    # Generate keyword argument constructor
    # Build mapping from toggle to its containing group (if any)
    toggle_to_group = Dict{Symbol, Union{Symbol, Nothing}}()
    for toggle in toggles
        toggle_to_group[toggle] = nothing
        for group_name in keys(groups)
            if toggle in groups[group_name]
                toggle_to_group[toggle] = group_name
                break
            end
        end
    end

    # Default preset
    default_preset = Standard()

    # Capture runtime data for the generated functions
    _preset_map = preset_map

    # Build the runtime helper function name
    runtime_helper_name = Symbol("_build_$(name)_runtime")

    # Generate validation expressions for groups
    group_params = collect(keys(groups))
    group_validations = []
    for group_name in group_params
        push!(group_validations, quote
            if $(group_name) !== nothing && !($(group_name) isa AbstractMessageLevel)
                throw(ArgumentError("$($(QuoteNode(group_name))) must be a SciMLLogging.AbstractMessageLevel, got $(typeof($(group_name)))"))
            end
        end)
    end

    # Generate validation for individual kwargs
    all_toggle_symbols = collect(toggles)
    kwargs_validation = quote
        for (key, value) in pairs(kwargs)
            if !(key in $all_toggle_symbols)
                throw(ArgumentError("Unknown verbosity option: \$key. Valid options are: $($all_toggle_symbols)"))
            end
            if !(value isa AbstractMessageLevel)
                throw(ArgumentError("\$key must be a SciMLLogging.AbstractMessageLevel, got \$(typeof(value))"))
            end
        end
    end

    # Build the group application logic with precedence: individual > group > preset
    group_application_entries = []
    for toggle in toggles
        group = toggle_to_group[toggle]
        if group === nothing
            # Not in any group: individual > preset
            push!(group_application_entries, quote
                $toggle = haskey(kwargs, $(QuoteNode(toggle))) ? kwargs[$(QuoteNode(toggle))] : preset_config[$(QuoteNode(toggle))]
            end)
        else
            # In a group: individual > group > preset
            push!(group_application_entries, quote
                $toggle = if haskey(kwargs, $(QuoteNode(toggle)))
                    kwargs[$(QuoteNode(toggle))]
                elseif $group !== nothing
                    $group
                else
                    preset_config[$(QuoteNode(toggle))]
                end
            end)
        end
    end

    # Build the runtime helper
    runtime_helper = quote
        function $(runtime_helper_name)($(group_params...), preset, kwargs)
            # Validate group arguments
            $(group_validations...)

            # Validate preset
            if preset !== nothing && !(preset isa AbstractVerbosityPreset)
                throw(ArgumentError("preset must be a SciMLLogging.AbstractVerbosityPreset, got \$(typeof(preset))"))
            end

            # Validate individual kwargs
            $kwargs_validation

            # Get preset configuration
            preset_to_use = preset === nothing ? $default_preset : preset
            preset_config = $_preset_map[typeof(preset_to_use).name.name]

            # Apply precedence: individual kwargs > group > preset
            $(group_application_entries...)

            return $name($([t for t in toggles]...))
        end
    end

    # Build fast path values for Standard preset
    standard_config = preset_map[:Standard]
    fast_path_values = [standard_config[t] for t in toggles]

    # Build the @generated wrapper function
    wrapper_name = Symbol("_build_$(name)")

    # Build the expression that the @generated function will return for the fast path
    fast_path_expr = :($name($(fast_path_values...)))

    # Build the expression for the slow path
    slow_path_expr = :($runtime_helper_name($(group_params...), preset, kwargs))

    # Build chained && conditions for compile-time check
    compile_time_checks = [:($(g) === Nothing) for g in group_params]
    push!(compile_time_checks, :(preset === Nothing))
    push!(compile_time_checks, :(kwargs <: NamedTuple{()}))
    # Chain them with binary && operators
    compile_time_condition = compile_time_checks[1]
    for check in compile_time_checks[2:end]
        compile_time_condition = :($compile_time_condition && $check)
    end

    # Build chained && conditions for runtime check
    runtime_checks = [:($(g) === nothing) for g in group_params]
    push!(runtime_checks, :(preset === nothing))
    push!(runtime_checks, :(isempty(kwargs)))
    # Chain them with binary && operators
    runtime_condition = runtime_checks[1]
    for check in runtime_checks[2:end]
        runtime_condition = :($runtime_condition && $check)
    end
    
    # Quote the expressions for the generated function to return
    quoted_fast_path = QuoteNode(fast_path_expr)
    quoted_slow_path = QuoteNode(slow_path_expr)

    wrapper_function = quote
        function $(wrapper_name)($(group_params...), preset, kwargs)
            if @generated
                # Check if all params are Nothing and kwargs is empty (fast default path)
                if $compile_time_condition
                    # Return expression that constructs the default directly
                    return $quoted_fast_path
                else
                    # Delegate to runtime logic
                    return $quoted_slow_path
                end
            else
                # Runtime fallback
                if $runtime_condition
                    # Fast default path
                    return $name($(fast_path_values...))
                else
                    # Complex path
                    return $runtime_helper_name($(group_params...), preset, kwargs)
                end
            end
        end
    end

    # Build the main keyword constructor
    kwarg_params = []
    push!(kwarg_params, Expr(:kw, :preset, :nothing))
    for g in group_params
        push!(kwarg_params, Expr(:kw, g, :nothing))
    end

    main_constructor = quote
        function $name(; $(kwarg_params...), kwargs...)
            $(wrapper_name)($(group_params...), preset, NamedTuple(kwargs))
        end
    end

    return (custom_preset_types = custom_preset_types,
            struct_def = struct_def,
            inner_constructor = inner_constructor,
            preset_constructors = constructors,
            runtime_helper = runtime_helper,
            wrapper_function = wrapper_function,
            main_constructor = main_constructor)
end

function eval_verbosity_specifier(generated_code)
    # Evaluate custom preset types first
    if !isempty(generated_code.custom_preset_types)
        for preset_type in generated_code.custom_preset_types
            Core.eval(@__MODULE__, preset_type)
        end
    end
    # Then evaluate the main struct
    Core.eval(@__MODULE__, generated_code.struct_def)

    # Evaluate the inner constructor (type-inferring constructor)
    Core.eval(@__MODULE__, generated_code.inner_constructor)

    # Then the constructors and helper functions
    for constructor in generated_code.preset_constructors
        Core.eval(@__MODULE__, constructor)
    end
    Core.eval(@__MODULE__, generated_code.runtime_helper)
    Core.eval(@__MODULE__, generated_code.wrapper_function)
    Core.eval(@__MODULE__, generated_code.main_constructor)

    return nothing
end

"""
    define_verbosity_specifier(name::Symbol, toggles, preset_map, groups)

Convenience function that generates and evaluates a verbosity specifier in one step.
Equivalent to calling `generate_verbosity_specifier` followed by `eval_verbosity_specifier`.

# Arguments
- `name`: Symbol for the struct name
- `toggles`: Tuple of symbols representing individual toggle names
- `preset_map`: NamedTuple mapping preset names to their configurations
- `groups`: NamedTuple mapping group names to tuples of toggle symbols

# Example
```julia
define_verbosity_specifier(:MyVerbosity,
    (:toggle1, :toggle2),
    (Standard = (toggle1 = InfoLevel(), toggle2 = WarnLevel()),),
    (group1 = (:toggle1,),))
```
"""
function define_verbosity_specifier(name::Symbol, toggles, preset_map, groups)
    generated = generate_verbosity_specifier(name, toggles, preset_map, groups)
    eval_verbosity_specifier(generated)
    return nothing
end