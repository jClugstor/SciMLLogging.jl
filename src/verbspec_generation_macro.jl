"""
    @verbosity_specifier name begin
        toggles = (...)
        specifiers = (...)   # optional
        presets = (...)
        groups = (...)
    end

Generates a parametric struct and constructors for a verbosity specifier.

# Input Format

**toggles:** Tuple of symbols for leaf verbosity toggles. Fields are typed as `MessageLevel`,
enabling compile-time branch elimination when the specifier is a constant.

**specifiers:** (optional) Tuple of symbols for sub-specifier fields that hold another
`AbstractVerbositySpecifier` or `AbstractVerbosityPreset`. Fields are typed as
`Union{AbstractVerbositySpecifier, AbstractVerbosityPreset}`.

**presets:** Named tuple mapping preset names to field configurations. Each preset maps
field names to message levels, presets, or specifier instances.
Must include at least `Standard`. Can define custom presets beyond the standard five
(None, Minimal, Standard, Detailed, All).

**groups:** Named tuple mapping group names to tuples of field symbols. Groups allow
setting multiple fields at once.

# Generated Code

**Struct:** Creates `name{Enabled} <: AbstractVerbositySpecifier{Enabled}` with concrete
`MessageLevel` fields for toggles and Union fields for specifiers.

**Constructors:**
- `name()`: Default constructor using Standard preset
- `name(preset::AbstractVerbosityPreset)`: Constructor from preset (e.g., `name(Minimal())`)
- `name(; preset=nothing, groups..., kwargs...)`: Keyword constructor with precedence: individual > group > preset

**Custom Preset Types:** Generates struct definitions for non-standard presets.

# Example
```julia
@verbosity_specifier SolverVerbosity begin
    toggles = (:convergence, :step_rejected)

    specifiers = (:linear_verbosity,)

    presets = (
        Standard = (
            convergence      = InfoLevel(),
            step_rejected    = WarnLevel(),
            linear_verbosity = LinearVerbosity(None()),
        ),
    )

    groups = (
        solver = (:convergence, :step_rejected),
    )
end
```
"""
macro verbosity_specifier(name, block)
    local toggles_expr    = nothing
    local specifiers_expr = nothing
    local presets_expr    = nothing
    local groups_expr     = nothing

    if block.head == :block
        for ex in block.args
            if ex isa Expr && ex.head == :(=)
                lhs = ex.args[1]
                rhs = ex.args[2]
                if lhs == :toggles
                    toggles_expr = rhs
                elseif lhs == :specifiers
                    specifiers_expr = rhs
                elseif lhs == :presets
                    presets_expr = rhs
                elseif lhs == :groups
                    groups_expr = rhs
                end
            end
        end
    end

    toggles_expr !== nothing || throw(ArgumentError("toggles must be defined in block"))
    presets_expr !== nothing || throw(ArgumentError("presets must be defined in block"))
    groups_expr  !== nothing || throw(ArgumentError("groups must be defined in block"))

    toggles_expr.head == :tuple || throw(ArgumentError("toggles must be a tuple"))
    toggles = [t.value for t in toggles_expr.args]

    specifiers = if specifiers_expr !== nothing
        specifiers_expr.head == :tuple || throw(ArgumentError("specifiers must be a tuple"))
        [t.value for t in specifiers_expr.args]
    else
        Symbol[]
    end

    all_fields = [toggles; specifiers]

    presets_expr.head == :tuple || throw(ArgumentError("presets must be a NamedTuple"))
    presets_dict = Dict()
    for preset_def in presets_expr.args
        preset_def.head == :(=) || throw(ArgumentError("Each preset must be name = (...)"))
        preset_name   = preset_def.args[1]
        preset_values = preset_def.args[2]
        preset_values.head == :tuple || throw(ArgumentError("Preset values must be a NamedTuple"))
        preset_config = Dict()
        for field_def in preset_values.args
            field_def.head == :(=) || throw(ArgumentError("Each field must be field_name = value"))
            preset_config[field_def.args[1]] = field_def.args[2]
        end
        presets_dict[preset_name] = preset_config
    end

    groups_expr.head == :tuple || throw(ArgumentError("groups must be a NamedTuple"))
    groups_dict = Dict()
    for group_def in groups_expr.args
        group_def.head == :(=) || throw(ArgumentError("Each group must be name = (...)"))
        group_name        = group_def.args[1]
        group_fields_expr = group_def.args[2]
        group_fields_expr.head == :tuple || throw(ArgumentError("Group fields must be a tuple"))
        groups_dict[group_name] = [t isa QuoteNode ? t.value : t for t in group_fields_expr.args]
    end

    preset_names = collect(keys(presets_dict))
    group_names  = collect(keys(groups_dict))

    standard_presets   = (:None, :Minimal, :Standard, :Detailed, :All)
    custom_presets     = filter(p -> !(p in standard_presets), preset_names)
    custom_preset_defs = [:(struct $p <: AbstractVerbosityPreset end) for p in custom_presets]

    # Toggles: concrete MessageLevel — enables @assume_effects :foldable to fire
    # Specifiers: Union for sub-specifiers and presets
    toggle_fields    = [:($(t)::SciMLLogging.MessageLevel) for t in toggles]
    specifier_fields = [:($(s)::Union{SciMLLogging.AbstractVerbositySpecifier, SciMLLogging.AbstractVerbosityPreset}) for s in specifiers]
    struct_fields    = [toggle_fields; specifier_fields]

    struct_def = :(
        struct $name{Enabled} <: SciMLLogging.AbstractVerbositySpecifier{Enabled}
            $(struct_fields...)
        end
    )

    # Preset constructors — None() produces {false}, everything else {true}
    preset_constructors = []
    for preset_name in preset_names
        preset_config = presets_dict[preset_name]
        field_values  = [preset_config[f] for f in all_fields]
        enabled       = preset_name === :None ? false : true
        push!(preset_constructors, :(
            function $name(::$preset_name)
                return $name{$enabled}($(field_values...))
            end
        ))
    end

    # Map each field to its group
    field_to_group = Dict{Symbol, Union{Symbol, Nothing}}()
    for f in all_fields
        field_to_group[f] = nothing
        for (group_name, group_fields) in groups_dict
            if f in group_fields
                field_to_group[f] = group_name
                break
            end
        end
    end

    standard_config  = presets_dict[:Standard]
    fast_path_values = [standard_config[f] for f in all_fields]

    # Group validation
    group_validations = []
    for group_name in group_names
        lazy_str = Expr(
            :macrocall, Symbol("@lazy_str"), LineNumberNode(@__LINE__, @__FILE__),
            "\$($(QuoteNode(group_name))) must be a SciMLLogging.AbstractMessageLevel, got \$(typeof($(group_name)))"
        )
        push!(group_validations, quote
            if $(group_name) !== nothing && !($(group_name) isa AbstractMessageLevel)
                throw(ArgumentError($lazy_str))
            end
        end)
    end

    # Field assignments with precedence: individual > group > preset
    field_assignments = []
    for f in all_fields
        group     = field_to_group[f]
        field_key = QuoteNode(f)
        if group === nothing
            push!(field_assignments, :($f = haskey(kwargs, $field_key) ? kwargs[$field_key] : preset_config[$field_key]))
        else
            push!(field_assignments, :($f = haskey(kwargs, $field_key) ? kwargs[$field_key] : ($group !== nothing ? $group : preset_config[$field_key])))
        end
    end

    # Preset map constant
    preset_configs = []
    for pname in preset_names
        field_values = [presets_dict[pname][f] for f in all_fields]
        push!(preset_configs, :(NamedTuple{$(Tuple(all_fields))}(($(field_values...),))))
    end
    preset_map_const = :(const $(Symbol("_preset_map_", name)) = NamedTuple{$(Tuple(preset_names))}(($(preset_configs...),)))

    kwarg_params      = [Expr(:kw, :preset, :nothing); [Expr(:kw, g, :nothing) for g in group_names]]
    runtime_condition = foldr((a, b) -> :($a && $b), [:($(g) === nothing) for g in group_names]; init = :(preset === nothing && isempty(kwargs)))

    preset_error_str = Expr(
        :macrocall, Symbol("@lazy_str"), LineNumberNode(@__LINE__, @__FILE__),
        "preset must be a SciMLLogging.AbstractVerbosityPreset, got \$(typeof(preset))"
    )
    unknown_option_str = Expr(
        :macrocall, Symbol("@lazy_str"), LineNumberNode(@__LINE__, @__FILE__),
        "Unknown verbosity option: \$key. Valid options are: $(Tuple(all_fields))"
    )
    toggle_type_str = Expr(
        :macrocall, Symbol("@lazy_str"), LineNumberNode(@__LINE__, @__FILE__),
        "\$key is a toggle and must be a SciMLLogging.MessageLevel, got \$(typeof(value))"
    )
    specifier_type_str = Expr(
        :macrocall, Symbol("@lazy_str"), LineNumberNode(@__LINE__, @__FILE__),
        "\$key is a specifier field and must be a SciMLLogging.AbstractVerbositySpecifier or AbstractVerbosityPreset, got \$(typeof(value))"
    )

    main_constructor = quote
        function $name(; $(kwarg_params...), kwargs...)
            kwargs = NamedTuple(kwargs)

            if $runtime_condition
                return $name{true}($(fast_path_values...))
            end

            $(group_validations...)

            if preset !== nothing && !(preset isa AbstractVerbosityPreset)
                throw(ArgumentError($preset_error_str))
            end

            for (key, value) in pairs(kwargs)
                if key in $(Tuple(toggles))
                    !(value isa MessageLevel) && throw(ArgumentError($toggle_type_str))
                elseif key in $(Tuple(specifiers))
                    !(value isa AbstractVerbositySpecifier || value isa AbstractVerbosityPreset) &&
                        throw(ArgumentError($specifier_type_str))
                else
                    throw(ArgumentError($unknown_option_str))
                end
            end

            preset_to_use = preset === nothing ? Standard() : preset
            preset_config = $(Symbol("_preset_map_", name))[typeof(preset_to_use).name.name]

            $(field_assignments...)

            return $name{true}($([f for f in all_fields]...))
        end
    end

    result = quote
        $(custom_preset_defs...)
        $preset_map_const
        $struct_def
        $(preset_constructors...)
        $main_constructor
    end

    return esc(result)
end
