# Compiler Settings

```@docs
ToQUBO.Attributes.StableCompilation
```

## Compiler Messages

```@docs
ToQUBO.Attributes.Warnings
```

## Constraint Feasibility Actions

```@docs
ToQUBO.Attributes.IgnoreFeasibleConstraints
ToQUBO.Attributes.ErrorInfeasibleConstraints
```

## Solve-Result Feasibility

These attributes control how sampled results surface source-model feasibility
and objective values; usage examples live in the
[results manual](@ref "Feasibility in Solve Results").

```@docs
ToQUBO.Attributes.PrimalFeasibilityCheck
ToQUBO.Attributes.AutoFeasibilityReport
ToQUBO.Attributes.SourceObjectiveValue
```

## Compiler Optimization

```@docs
ToQUBO.Attributes.Optimization
```

## Working with target architectures

```@docs
ToQUBO.Attributes.Architecture
```

## Quadratization

```@docs
ToQUBO.Attributes.Quadratize
ToQUBO.Attributes.QuadratizationMethod
ToQUBO.Attributes.StableQuadratization
```

## Variable & Constraint Encoding

### Automatic Penalty Inference

When a constraint, variable encoding, or slack-variable encoding needs a penalty
coefficient and no explicit hint is set, ToQUBO infers one automatically. The
default [`ToQUBO.Attributes.ObjectiveRangePenalty`](@ref) policy uses an
objective-range exact-penalty bound:

```math
\rho = s \cdot \sigma \cdot \left(\frac{U - L + \beta}{\epsilon}\right)
```

where `s` is [`ToQUBO.Attributes.PenaltyScale`](@ref), `β` is
[`ToQUBO.Attributes.PenaltyOffset`](@ref), `σ` is `1` for minimization models
and `-1` for maximization models, `U - L` is the compiled pseudo-boolean
objective range, and `ϵ` is the smallest positive value of the generated
nonnegative penalty function. When every feasible source assignment has a
target representation with zero generated constraint penalty, the default
scale `s = 1` and `β > 0` penalize any infeasible assignment by more than the
largest possible objective improvement available within the compiled objective
range. With custom scales, the same sufficient exactness condition is
`s * (U - L + β) > U - L`; smaller scales can make the penalty a tuning
heuristic rather than a certified exact penalty. A finite continuous-slack
encoding can violate the zero-penalty premise; see
[Slack Resolution and Penalty Contrast](@ref).

The objective range is computed from interval bounds on the compiled PBF over
encoded target binary variables. For normal finite JuMP/MOI models this bound
is finite after encoding, but it may overestimate the exact source-objective
span when an encoding has redundant target states or feasibility relations such
as one-hot sums. That overestimate keeps the penalty sufficient, but it is not
always the tightest possible objective range.

When the objective range or positive penalty gap cannot be certified, ToQUBO
falls back for that coefficient to [`ToQUBO.Attributes.LegacyPenalty`](@ref):

```math
\rho = s \cdot \sigma \cdot \left(\frac{\delta}{\epsilon} + \beta\right)
```

where `δ` is the historical objective gap estimate from `PBO.maxgap`.
The selected policy, objective bounds, inferred penalties with their `ϵ`
sources, and any fallback reasons are exposed through
[`ToQUBO.Attributes.PenaltyPolicyMetadata`](@ref) and the `"penalty_policy"`
field in reformulation metadata.

The precedence is:

1. Explicit hints such as
   [`ToQUBO.Attributes.ConstraintEncodingPenaltyHint`](@ref) are used as-is.
2. Constraint overrides
   [`ToQUBO.Attributes.ConstraintPenaltyScale`](@ref) and
   [`ToQUBO.Attributes.ConstraintPenaltyOffset`](@ref) apply to the source
   constraint and to the slack-variable encoding penalty generated for that
   constraint.
3. Global [`ToQUBO.Attributes.PenaltyPolicy`](@ref),
   [`ToQUBO.Attributes.PenaltyScale`](@ref), and
   [`ToQUBO.Attributes.PenaltyOffset`](@ref) apply everywhere else.

The defaults are `PenaltyPolicy() == ObjectiveRangePenalty()`,
`PenaltyScale() == 1.0`, and `PenaltyOffset() == 1.0`. The coefficient is
positive for minimization models and negative for maximization models, so
explicit hints should use the same sign as the coefficient you want the
compiler to apply.

### Literature Penalty Heuristics

Besides the exactness-oriented default, ToQUBO offers the static
penalty-weight heuristics evaluated by Ayodele
([arXiv:2206.11040](https://arxiv.org/abs/2206.11040)), selectable through
[`ToQUBO.Attributes.PenaltyPolicy`](@ref). They typically produce smaller,
sampler-friendlier coefficients than the certified bound, at the price of not
guaranteeing exactness. Each computes a bound `λ` on the compiled
pseudo-Boolean objective and applies it with the same composition as the
default policy, ``\rho = s \sigma (\lambda + \beta) / \epsilon``:

| Policy | `λ` | Scope |
|:--|:--|:--|
| [`ToQUBO.Attributes.UBPositivePenalty`](@ref) | Sum of all non-constant objective coefficients (requires them nonnegative) | global |
| [`ToQUBO.Attributes.MaxCoefficientPenalty`](@ref) | Largest non-constant objective coefficient | global |
| [`ToQUBO.Attributes.VLMPenalty`](@ref) | Largest one-flip objective change (Verma–Lewis) | global |
| [`ToQUBO.Attributes.MOMCPenalty`](@ref) | `max(1, VLM / γ)`, `γ` the smallest positive one-flip change of the penalty function | per penalty function |
| [`ToQUBO.Attributes.MOCPenalty`](@ref) | `max(1, max abs one-flip objective/penalty ratio)` | per penalty function |

The per-penalty-function policies (MOMC, MOC) infer one coefficient per
constraint, variable-encoding, and slack-encoding penalty, so different
constraints receive different weights. One-flip changes generalize the
quadratic row-sum form of the reference to arbitrary degree by crediting each
monomial to every variable it contains. When a policy's validity conditions do
not hold (for example, a negative objective coefficient under
`UBPositivePenalty`, or a penalty function without a positive one-flip
change), ToQUBO falls back to [`ToQUBO.Attributes.LegacyPenalty`](@ref) for
that coefficient and records the reason in
[`ToQUBO.Attributes.PenaltyPolicyMetadata`](@ref).

```@docs
ToQUBO.Attributes.UBPositivePenalty
ToQUBO.Attributes.MaxCoefficientPenalty
ToQUBO.Attributes.VLMPenalty
ToQUBO.Attributes.MOMCPenalty
ToQUBO.Attributes.MOCPenalty
```

Use the controls according to how much of the model you want to change:

- Use [`ToQUBO.Attributes.PenaltyPolicy`](@ref) to select the automatic
  inference policy. Choose a literature heuristic above when the certified
  bound is too conservative for your sampler, or set it to
  [`ToQUBO.Attributes.LegacyPenalty`](@ref) only when you need to reproduce
  the historical maxgap-based coefficients.
- Use [`ToQUBO.Attributes.PenaltyScale`](@ref) and
  [`ToQUBO.Attributes.PenaltyOffset`](@ref) to change all automatically
  inferred penalties while preserving their policy-dependent objective and
  penalty-gap dependence.
- Use [`ToQUBO.Attributes.ConstraintPenaltyScale`](@ref) and
  [`ToQUBO.Attributes.ConstraintPenaltyOffset`](@ref) when one source
  constraint needs a different automatic penalty. These overrides also apply to
  the slack-variable encoding penalty generated for that constraint.
- Use explicit hints such as
  [`ToQUBO.Attributes.ConstraintEncodingPenaltyHint`](@ref),
  [`ToQUBO.Attributes.SlackVariableEncodingPenaltyHint`](@ref), or
  [`ToQUBO.Attributes.VariableEncodingPenaltyHint`](@ref) when you need a fixed
  coefficient. Hints bypass the automatic scale and offset settings.

!!! note "ToQUBO-specific settings"
    These attributes control the ToQUBO compiler, so the reference for setting,
    overriding, and retrieving penalty coefficients belongs in this manual.
    End-to-end ecosystem examples can live in the `QUBO.jl` documentation and
    link back here when they tune ToQUBO penalties.

### Changing Penalty Values

For feasibility tuning, start by inspecting
[`ToQUBO.Attributes.PenaltyPolicyMetadata`](@ref) and sweeping `PenaltyScale()`
while keeping explicit hints unset. If only one constraint needs adjustment,
override that constraint's automatic scale or offset. Pin exact penalty values
only when you have a known coefficient to apply.

Finite-run stochastic samplers such as `DWave.Neal` may need stronger penalties
than the default exact-penalty bound to return feasible samples at a useful
rate. In that case, prefer targeted
[`ToQUBO.Attributes.ConstraintPenaltyScale`](@ref) overrides for the source
constraints that are violated most often, instead of increasing the global
[`ToQUBO.Attributes.PenaltyScale`](@ref) or replacing automatic inference with
fixed hints everywhere. For example, if equality constraints `c2`, `c3`, and
`c4` need about a 400x larger automatic penalty under a sampler:

```julia
set_attribute.(c2, Ref(Attributes.ConstraintPenaltyScale()), 400.0)
set_attribute.(c3, Ref(Attributes.ConstraintPenaltyScale()), 400.0)
set_attribute.(c4, Ref(Attributes.ConstraintPenaltyScale()), 400.0)
```

This keeps the selected automatic policy and its metadata, while reshaping the
penalty landscape only around the constraints that need more sampler pressure.

```@example penalty-settings
using JuMP
using QUBODrivers
using ToQUBO
using ToQUBO: Attributes, Encoding

# Use an exact sampler for a small example. Replace it with your QUBO solver.
model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))
@variable(model, x[1:2], Bin)
@variable(model, 0 <= z <= 3, Int)
@objective(model, Min, 3x[1] + x[2] + z)

capacity = @constraint(model, x[1] + x[2] <= 1)
assignment = @constraint(model, x[1] + x[2] == 1)

# Model-wide automatic penalty tuning.
set_attribute(model, Attributes.PenaltyScale(), 2.0)
set_attribute(model, Attributes.PenaltyOffset(), 1.0)

# Automatic tuning for one source constraint and its slack encoding.
set_attribute(capacity, Attributes.ConstraintPenaltyScale(), 4.0)
set_attribute(capacity, Attributes.ConstraintPenaltyOffset(), 2.0)

# Fixed values for specific generated penalties.
set_attribute(assignment, Attributes.ConstraintEncodingPenaltyHint(), 12.0)
set_attribute(capacity, Attributes.SlackVariableEncodingMethod(), Encoding.OneHot())
set_attribute(capacity, Attributes.SlackVariableEncodingPenaltyHint(), 9.0)
set_attribute(z, Attributes.VariableEncodingMethod(), Encoding.OneHot())
set_attribute(z, Attributes.VariableEncodingPenaltyHint(), 6.0)

optimize!(model)

rho_capacity = get_attribute(capacity, Attributes.ConstraintEncodingPenalty())
rho_assignment = get_attribute(assignment, Attributes.ConstraintEncodingPenalty())
eta_capacity = get_attribute(capacity, Attributes.SlackVariableEncodingPenalty())
theta_z = get_attribute(z, Attributes.VariableEncodingPenalty())
policy_metadata = get_attribute(model, Attributes.PenaltyPolicyMetadata())

# The capacity penalty is inferred by the automatic policy.
@assert rho_capacity !== nothing
@assert rho_assignment == 12.0
@assert eta_capacity == 9.0
@assert theta_z == 6.0
@assert policy_metadata["policy"] == "ObjectiveRangePenalty"
```

Very small `ϵ` values or broad objective ranges can produce large penalties.
Inspect the policy metadata before overriding the policy or pinning explicit
penalties.

### Value-Set Variable Encoding

Variables restricted to an explicit finite set of values — discrete component
choices, tariff levels, or a non-uniform (for example, logarithmically spaced)
grid for a continuous quantity — can be declared directly with
[`ToQUBO.Attributes.VariableEncodingSet`](@ref) together with a set encoding
method (`Encoding.OneHot` or `Encoding.DomainWall`):

```@example value-set-encoding
using JuMP
using QUBODrivers
using ToQUBO
using ToQUBO: Attributes, Encoding

model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

@variable(model, x, Int)
@objective(model, Min, x)

set_attribute(x, Attributes.VariableEncodingMethod(), Encoding.OneHot())
set_attribute(x, Attributes.VariableEncodingSet(), [-1.0, 1.0, 3.0])

optimize!(model)

value(x)
```

The set replaces the bounds-derived domain, so bounds are optional; when
explicit bounds are present, every entry must respect them. Integer variables
require integer-valued entries. Interval encoding methods (`Encoding.Binary`,
`Encoding.Unary`, `Encoding.Arithmetic`, `Encoding.Bounded`) reject value sets
with a compilation error — choose a set encoding for the variable instead.
For continuous variables, pass the exact grid you want (for example
`exp10.(range(-1, 2; length = 4))` for logarithmic spacing). Encoding-feasible
decoded states always land on a grid point; samples that violate the set
encoding's penalty (for example, an all-zero or multi-hot one-hot state) can
decode off-grid, so inspect sample feasibility or the penalty value as usual
when working with raw sample sets.

```@docs
ToQUBO.Attributes.VariableEncodingSet
```

### Continuous Variable Resolution

Bounded continuous variables need a finite binary representation before the
compiler can build the QUBO. Set
[`ToQUBO.Attributes.VariableEncodingBits`](@ref) or
[`ToQUBO.Attributes.DefaultVariableEncodingBits`](@ref) to choose that bit
count explicitly. When the bit count is unset, ToQUBO derives it from the
variable bounds and [`ToQUBO.Attributes.VariableEncodingATol`](@ref), falling
back to [`ToQUBO.Attributes.DefaultVariableEncodingATol`](@ref).

The tolerance rule is described in the booklet's [Representation Error](@ref)
section. Smaller tolerances or wider bounds generally allocate more target
binary variables. Slack variables generated from constraints use the analogous
[`ToQUBO.Attributes.SlackVariableEncodingATol`](@ref) and
[`ToQUBO.Attributes.SlackVariableEncodingBits`](@ref) settings. See
[Constraint Reformulation](@ref) for how inequality constraints generate these
slacks and where their finite resolution enters the penalty.

### Slack Resolution and Penalty Contrast

First check whether the constraint actually generates a slack. `EqualTo`
constraints encode their residual directly and do not own an inequality slack.
`LessThan`, `GreaterThan`, and the two sides of `Interval` can generate one,
although a sign-definite shortcut or an always-feasible constraint can avoid
it. After compilation, inspect:

```julia
metadata = ToQUBO.reformulation_metadata(JuMP.unsafe_backend(model))
metadata["slack_variables"]
```

Those entries identify the source constraints that own generated slacks and
expose their encoding and expansion terms.

The [`ToQUBO.Attributes.Discretize`](@ref) setting determines which slack path
is relevant:

- `Discretize(true)` is the default. The compiler discretizes each constraint
  residual and generates an integer slack, so those generated slacks do not
  introduce the continuous-grid floor described below.
- `Discretize(false)` preserves noninteger residual coefficients and generates
  a continuous slack. Its finite binary encoding may not contain the exact
  value needed to cancel a feasible residual.

For the default binary encoding of a continuous slack on ``[0, S]`` with ``n``
bits, the grid spacing is

```math
\Delta = \frac{S}{2^n - 1}.
```

If a feasible source assignment needs slack ``z^\star``, its smallest squared
penalty is

```math
p_F = \min_k |z^\star - k\Delta|^2 \leq \frac{\Delta^2}{4}.
```

The floor is zero when ``z^\star`` lies on the grid, and grid alignment means
that it need not decrease strictly at every added bit. Resolution alone also
does not determine a safe penalty coefficient. For a minimization model, let
an infeasible assignment have objective advantage ``B > 0`` and smallest
penalty ``p_I``. A positive coefficient ``\rho`` prefers the feasible
assignment only when

```math
\rho (p_I - p_F) > B.
```

When `p_I - p_F` is positive, this gives
``\rho > B / (p_I - p_F)``. When ``p_I \leq p_F``, no positive `rho` can repair
the ordering; increasing it can strengthen the wrong preference. Refining the
slack encoding, changing the source model's tolerance, or choosing a different
reformulation must first make the contrast positive.

ToQUBO does not currently relax a residual to a tolerance band or rescale a
constraint automatically from slack resolution; the checks above diagnose
whether either policy could be valid for a particular continuous-slack model.

Use this diagnostic sequence before changing penalties:

1. Classify the violated source constraint and confirm slack ownership in the
   reformulation metadata. Equality violations are not caused by slack
   resolution.
2. Check `Discretize()`. Under the default `true` path, investigate the
   compiled integer penalty and solver behavior rather than applying a
   continuous-resolution multiplier.
3. Under `false`, inspect the slack expansion, estimate ``p_F`` and a relevant
   ``p_I``, and establish positive contrast before increasing ``\rho``. Use
   [`ToQUBO.Attributes.SlackVariableEncodingBits`](@ref) or
   [`ToQUBO.Attributes.SlackVariableEncodingATol`](@ref) when finer resolution
   is the appropriate tradeoff.
4. Separate exact-model energy ordering from finite-run sampler behavior. If
   the energy ordering is correct but a stochastic sampler still returns
   violations, use targeted
   [`ToQUBO.Attributes.ConstraintPenaltyScale`](@ref) tuning as described in
   [Changing Penalty Values](@ref), and check whether violations move to other
   constraint families.

The [Slack-resolution penalty analysis](https://github.com/JuliaQUBO/ToQUBO.jl/blob/main/benchmarks/reports/slack_resolution_analysis.md)
derives this condition with an executable public fixture. Its canonical #205
audit found that the troublesome c2-c4 families were slack-free binary
equalities and that the model's generated inequality slacks were integral under
`Discretize(true)`. Their finite-run sampler behavior therefore supports the
targeted constraint guidance above, not resolution-aware scaling as a remedy
for #205.

### Constraint Penalty Methods

Equality constraints are encoded with
[`ToQUBO.Attributes.QuadraticPenalty`](@ref) by default. This normally squares
the residual and lets the compiler infer a penalty coefficient when
[`ToQUBO.Attributes.ConstraintEncodingPenaltyHint`](@ref) is not set. When the
parsed residual is provably nonnegative, the compiler can instead add the
residual directly to avoid unnecessary higher-order terms while preserving the
same minimizer at zero. The same automatic penalty inference applies to this
sign-definite shortcut.

Use [`ToQUBO.Attributes.LinearPenalty`](@ref) only when you want an equality
constraint encoded as its signed residual. Since this form can make infeasible
assignments cheaper when the sign or magnitude is wrong, automatic penalty
inference is disabled. Every equality constraint that uses `LinearPenalty()`
must also have an explicit
[`ToQUBO.Attributes.ConstraintEncodingPenaltyHint`](@ref).

The method is motivated by the linear Ising penalty approach of Mirkarimi et
al.[^Mirkarimi2024PRR], its quantum annealing demonstration,[^Mirkarimi2024NJP]
and the accompanying Durham data and code archive.[^Mirkarimi2024Data]
Those papers highlight the main tradeoff reflected in this API: linear
penalties can avoid the extra couplings introduced by quadratic penalties, but
they are heuristic and are not guaranteed to exactly enforce every constraint.

```julia
using JuMP
using ToQUBO
using ToQUBO: Attributes

model = Model(ToQUBO.Optimizer)
@variable(model, x[1:2], Bin)
@objective(model, Min, 0)
c = @constraint(model, x[1] + x[2] == 1)

set_attribute(model, Attributes.DefaultConstraintEncodingMethod(), Attributes.LinearPenalty())
set_attribute(c, Attributes.ConstraintEncodingPenaltyHint(), -2.0)
```

For mixed models, keep the default method as
[`ToQUBO.Attributes.QuadraticPenalty`](@ref) and set
[`ToQUBO.Attributes.ConstraintEncodingMethod`](@ref) only on the constraints
that should use the linear residual.

For scalar inequalities, [`ToQUBO.Attributes.UnbalancedPenalty`](@ref) removes
the generated constraint slack. For a `LessThan` residual ``g(x) \leq 0`` it
uses

```math
\lambda_1 g(x) + \lambda_2 g(x)^2,
```

and for a `GreaterThan` residual ``g(x) \geq 0`` it negates the linear term.
The default ``\lambda_1 = 1`` and ``\lambda_2 = 1/2`` come from truncating an
exponential barrier at quadratic order; pass two finite positive values to
`UnbalancedPenalty(linear, quadratic)` to tune their ratio. The explicit
`ConstraintEncodingPenaltyHint` supplies the overall scale and must have the
appropriate sign for the model sense.

```julia
using JuMP
using ToQUBO
using ToQUBO: Attributes

model = Model(ToQUBO.Optimizer)
@variable(model, x[1:3], Bin)
capacity = @constraint(model, 2x[1] + x[2] + x[3] <= 2)

set_attribute(
    capacity,
    Attributes.ConstraintEncodingMethod(),
    Attributes.UnbalancedPenalty(),
)
set_attribute(capacity, Attributes.ConstraintEncodingPenaltyHint(), 4.0)
```

Prefer this method when the target-variable budget is more important than an
exact slack reformulation and you can tune and validate the resulting energy
ordering on representative instances. Feasible assignments need not receive
equal or zero penalty, so the method can change which feasible point is lowest
in energy; automatic exact-penalty inference is therefore disabled. Keep the
default `QuadraticPenalty()` slack formulation when exact zero penalty for a
representable feasible slack and automatic penalty inference are required.
Affine inequalities remain quadratic without new variables. A quadratic source
inequality can still create higher-order terms and quadratization variables,
and an `Interval` applies the unbalanced form to both bounds.

The method follows the unbalanced penalization formulation of
Montañez-Barrera et al.[^MontanezBarrera2024] An exact hinge such as
``\max(0, g(x))^2`` is not generally a QUBO, while the real-coefficient
approximation in Colucci et al.[^Colucci2023] still uses ``K`` auxiliary binary
variables. Neither provides the no-new-variable affine QUBO used here.

[^Mirkarimi2024PRR]:
    Puya Mirkarimi, Ishaan Shukla, David C. Hoyle, Ross Williams, and Nicholas
    Chancellor. **Quantum optimization with linear Ising penalty functions for
    customer data science**. _Physical Review Research_ 6, 043241 (2024).
    [{doi}](https://doi.org/10.1103/PhysRevResearch.6.043241)

[^Mirkarimi2024NJP]:
    Puya Mirkarimi, David C. Hoyle, Ross Williams, and Nicholas Chancellor.
    **Experimental demonstration of improved quantum optimization with linear
    Ising penalties**. _New Journal of Physics_ 26, 103005 (2024).
    [{doi}](https://doi.org/10.1088/1367-2630/ad7e4a)

[^Mirkarimi2024Data]:
    Puya Mirkarimi, Ishaan Shukla, David C. Hoyle, Ross Williams, and Nicholas
    Chancellor. **Quantum optimization with linear Ising penalty functions for
    customer data science [dataset]**. Durham University data and code archive
    (2024). [{doi}](https://doi.org/10.15128/r2fq977t82m)

[^MontanezBarrera2024]:
    J. A. Montañez-Barrera, Dennis Willsch, A. Maldonado-Romo, and Kristel
    Michielsen. **Unbalanced penalization: a new approach to encode inequality
    constraints of combinatorial problems for quantum optimization
    algorithms**. _Quantum Science and Technology_ 9, 025022 (2024).
    [{doi}](https://doi.org/10.1088/2058-9565/ad35e4)

[^Colucci2023]:
    Giuseppe Colucci, Stan van der Linde, and Frank Phillipson. **Power Network
    Optimization: A Quantum Approach**. _IEEE Access_ 11, 98926–98938 (2023).
    [{doi}](https://doi.org/10.1109/ACCESS.2023.3312997)

```@docs
ToQUBO.Attributes.VariableEncodingBits
ToQUBO.Attributes.DefaultVariableEncodingBits
ToQUBO.Attributes.VariableEncodingATol
ToQUBO.Attributes.DefaultVariableEncodingATol
ToQUBO.Attributes.VariableEncodingMethod
ToQUBO.Attributes.DefaultVariableEncodingMethod
ToQUBO.Attributes.VariableEncodingPenaltyHint
ToQUBO.Attributes.VariableEncodingPenalty
ToQUBO.Attributes.SlackVariableEncodingMethod
ToQUBO.Attributes.SlackVariableEncodingATol
ToQUBO.Attributes.SlackVariableEncodingBits
ToQUBO.Attributes.SlackVariableEncodingPenaltyHint
ToQUBO.Attributes.SlackVariableEncodingPenalty
ToQUBO.Attributes.ObjectiveRangePenalty
ToQUBO.Attributes.LegacyPenalty
ToQUBO.Attributes.PenaltyPolicy
ToQUBO.Attributes.PenaltyPolicyMetadata
ToQUBO.Attributes.PenaltyOffset
ToQUBO.Attributes.PenaltyScale
ToQUBO.Attributes.ConstraintPenaltyOffset
ToQUBO.Attributes.ConstraintPenaltyScale
ToQUBO.Attributes.QuadraticPenalty
ToQUBO.Attributes.LinearPenalty
ToQUBO.Attributes.UnbalancedPenalty
ToQUBO.Attributes.DefaultConstraintEncodingMethod
ToQUBO.Attributes.ConstraintEncodingMethod
ToQUBO.Attributes.ConstraintEncodingPenaltyHint
ToQUBO.Attributes.ConstraintEncodingPenalty
```

## Discretization

```@docs
ToQUBO.Attributes.Discretize
```
