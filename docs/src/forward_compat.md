# Writing Code That Works on Both SciMLLogging 1.10+ and 2.0

SciMLLogging 2.0 is a breaking release. To make the rollout across the SciML
ecosystem smooth, SciMLLogging 1.10 forward-ports the parts of the 2.0 API
that can be backported. If downstream packages follow the rules below, the
same source code compiles and runs identically on both 1.10 and 2.0 — so
each package can bump `[compat] SciMLLogging = "1.10, 2"` and migrate ahead
of the 2.0 release without any code changes when 2.0 actually ships.

## Compatibility checklist

A downstream package is **dual-version safe** if it satisfies all of the
following. Each rule is concrete; the rest of this page shows examples.

1. Define verbosity specifiers via the `@verbosity_specifier` macro, not by
   hand-writing a `<: AbstractVerbositySpecifier` struct.
2. If your specifier holds another verbosity specifier (or a preset) as a
   field, declare those fields in a `sub_specifiers = (...)` block, not in
   `toggles`.
3. Use the call form for severity values — `Silent()`, `InfoLevel()`,
   `WarnLevel()`, etc. — not the bare type name.
4. For custom severities, use `MessageLevel(n)` instead of `CustomLevel(n)`.
5. Don't reference the names `AbstractMessageLevel` or `CustomLevel` from
   user code.
6. Don't introspect the field types of the generated struct.
7. Use `is_enabled(verb)` for portable disabled-path checks. Don't dispatch
   on `::AbstractVerbositySpecifier{Enabled}`.
8. Accept either an `AbstractVerbositySpecifier` instance **or** an
   `AbstractVerbosityPreset` singleton wherever your function takes a
   `verbose=` keyword argument.

## Why these rules

| Rule | What changed in 2.0 | Why this rule fixes it |
|---|---|---|
| 1 | `AbstractVerbositySpecifier` becomes parametric `{Enabled}`. Hand-written subtypes need an `{Enabled}` parameter. | The macro generates the parametric subtype for you, transparently. |
| 2 | Sub-specifier fields get their own type parameter for inference. | The `sub_specifiers` keyword exists on 1.10 (no-op) and on 2.0 (parametric). |
| 3 | `Silent`, `InfoLevel`, etc. are types in 1.x and constants in 2.0. The call form `Silent()` resolves correctly in both. | Bare `Silent` means the type in 1.x but the value in 2.0 — different things. The call form is the same value in both. |
| 4 | `CustomLevel` is removed in 2.0; `MessageLevel(n)` is the canonical custom-level constructor. The 1.10 version of `MessageLevel(n)` is provided as a smart constructor that returns the matching standard subtype where possible, otherwise `CustomLevel(n)`. | Both versions accept `MessageLevel(n)`. |
| 5 | Both names are removed in 2.0. | Avoid them. |
| 6 | Toggle field types differ: 1.x uses a wide Union; 2.0 uses concrete `MessageLevel`. Sub-specifier fields are typed differently across versions too. | Treat the struct as opaque — never check `fieldtype` or pattern-match on field types. |
| 7 | `AbstractVerbositySpecifier{Enabled}` only exists in 2.0. The `is_enabled(verb)` helper exists on 1.10 (always returns `true`) and on 2.0 (returns `false` for `None()` instances). | Portable disabled-path branch. |
| 8 | The `sub_specifiers` slot can hold either a sub-spec or a preset, so consumers of those slots see both shapes. | Functions accepting `verbose=` should already handle both via the macro-generated preset constructor. |

## Examples

### Defining a verbosity specifier

**Recommended (dual-version safe):**

```julia
using SciMLLogging

@verbosity_specifier MySolverVerbosity begin
    toggles = (:initialization, :iterations, :convergence, :warnings)

    # If your spec carries another verbosity (e.g. a linear-solve verbosity),
    # declare it here instead of in `toggles`. On 1.10 this is a no-op alias for
    # toggles; on 2.0 each entry gets its own concrete type parameter for
    # inference.
    sub_specifiers = (:linear_verbosity,)

    presets = (
        None = (
            initialization   = Silent(),
            iterations       = Silent(),
            convergence      = Silent(),
            warnings         = Silent(),
            linear_verbosity = None(),
        ),
        Standard = (
            initialization   = InfoLevel(),
            iterations       = Silent(),
            convergence      = InfoLevel(),
            warnings         = WarnLevel(),
            linear_verbosity = Standard(),
        ),
        # ... Minimal, Detailed, All ...
    )

    groups = (
        solver = (:initialization, :iterations, :convergence),
    )
end
```

**Avoid:**

```julia
# Won't compile on 2.0 — supertype becomes parametric.
struct MySolverVerbosity <: AbstractVerbositySpecifier
    initialization
    iterations
end
```

### Setting message levels

**Recommended:**

```julia
verbose = MyVerbosity(
    initialization = InfoLevel(),     # call form
    iterations     = Silent(),
    custom_thing   = MessageLevel(7), # forward-compat constructor
)
```

**Avoid:**

```julia
# `Silent` (no parens) means the type in 1.x but the constant value in 2.0.
verbose = MyVerbosity(initialization = Silent)

# `CustomLevel` is removed in 2.0.
verbose = MyVerbosity(custom_thing = CustomLevel(7))
```

### Holding sub-specifiers

**Recommended:**

```julia
@verbosity_specifier DEVerbosity begin
    toggles        = (:dt_select, :step_rejected)
    sub_specifiers = (:nonlinear_verbosity, :linear_verbosity)

    presets = (
        Standard = (
            dt_select           = InfoLevel(),
            step_rejected       = WarnLevel(),
            nonlinear_verbosity = Standard(),         # preset OR
            linear_verbosity    = LinearVerbosity(),  # sub-spec instance
        ),
        # ...
    )

    groups = ()
end
```

**Avoid:** putting `nonlinear_verbosity` into `toggles`. It works on 1.x but
will be rejected by 2.0's stricter toggle validation (toggles in 2.0 must be
`MessageLevel`-only).

### Disabled-path checks

**Recommended:**

```julia
function my_solve(prob; verbose = MyVerbosity(Standard()))
    if !is_enabled(verbose)
        # short-circuit any expensive verbosity-related setup
    end
    # ...
end
```

**Avoid:**

```julia
# Won't compile on 1.x — the abstract type is non-parametric there.
if verbose isa AbstractVerbositySpecifier{false}
    ...
end
```

### Functions with a `verbose=` argument

**Recommended:** accept either an instance or a preset, and pass through to
construction. The macro-generated preset constructor already handles this.

```julia
function my_solve(prob; verbose = MyVerbosity(Standard()))
    # `verbose` may be a MyVerbosity instance OR an AbstractVerbosityPreset
    # singleton. If it's a preset, materialize it.
    verb = verbose isa AbstractVerbosityPreset ? MyVerbosity(verbose) : verbose
    # ...
end
```

This is required because anything stored in a `sub_specifiers` slot of an
upstream verbosity can be either form when a downstream consumer pulls it
out and forwards it.

## Compat bound for the rollout

Once a downstream package has adopted the rules above, set:

```toml
[compat]
SciMLLogging = "1.10, 2"
```

This lets the package work with anyone resolving against either major
version. When the entire SciML ecosystem has migrated, you can later tighten
to `SciMLLogging = "2"` and drop the 1.x compatibility.

## What 2.0 still breaks

These changes can't be made backward-compatible inside 1.x:

- The supertype parameter `AbstractVerbositySpecifier{Enabled}` — any
  hand-written `<: AbstractVerbositySpecifier` struct must add the parameter
  on 2.0.
- The removal of `AbstractMessageLevel` and `CustomLevel` as exported names.
- Stricter toggle field validation: 2.0 toggle fields are `MessageLevel`-only,
  whereas 1.x accepted preset/spec values too.

Following the checklist avoids all three: rule 1 keeps you out of the
hand-written supertype path, rule 5 avoids the removed names, and rule 2
moves preset/spec values into the `sub_specifiers` slot where they're
correctly typed in 2.0.
