# Encoding Methods

```@docs
ToQUBO.Encoding.encode
ToQUBO.Encoding.encode!
ToQUBO.Encoding.encodes
```

## Variables

As you may already know, QUBO models are comprised only of binary variables.
So when we are reformulating general optimization problems, one important step is to encode variables into binary ones.

`ToQUBO` currently implements 6 base encoding techniques.
Each method introduces a different number of variables, quadratic terms and linear terms.
Also, they differ in the magnitude of their coefficients ``\Delta``.

| Encoding              | Binary Variables   | # Linear terms   | # Quadratic terms   | ``\Delta``       |
|:---------------------:|:------------------:|:----------------:|:-------------------:|:----------------:|
| Binary                |  ``O(\log n)``     |  ``O(\log n)``   |      -              | ``O(n)``         |
| Unary                 |    ``O(n)``        |    ``O(n)``      |      -              | ``O(1)``         |
| One-Hot               |    ``O(n)``        |    ``O(n)``      |      ``O(n^2)``     | ``O(n)``         |
| Domain-Wall           |    ``O(n)``        |    ``O(n)``      |      ``O(n)``       | ``O(n)``         |
| Bounded-Coefficient   |    ``O(n)``        |    ``O(n)``      |       -             | ``O(1)``         |
| Arithmetic Prog       |  ``O(\sqrt{n})``   |  ``O(\sqrt{n})`` |       -             | ``O(\sqrt{n})``  |

### Mirror Encoding

```@docs
ToQUBO.Encoding.VariableEncodingMethod
ToQUBO.Encoding.Mirror
```

### Interval Encoding

```@docs
ToQUBO.Encoding.IntervalVariableEncodingMethod
ToQUBO.Encoding.Unary
ToQUBO.Encoding.Binary
ToQUBO.Encoding.Arithmetic
```

#### Bounded Coefficients

```@docs
ToQUBO.Encoding.Bounded
```

### Arbitrary Set Encoding

```@docs
ToQUBO.Encoding.SetVariableEncodingMethod
ToQUBO.Encoding.OneHot
ToQUBO.Encoding.DomainWall
```

### Semi-Domain Encoding

```@docs
ToQUBO.Encoding.Semi
```

### Representation Error

```@docs
ToQUBO.Encoding.encoding_bits
ToQUBO.Encoding.encoding_points
```

Let ``\set{x_{i}}_{i \in [k]}`` be the collection of ``k`` evenly spaced samples from the discretization of an interval ``[a, b] \subseteq \mathbb{R}``.
Its interval length is ``L = \left|b - a\right|``.

The representation error for a given point ``x`` with respect to ``\set{x_{i}}_{i \in [k]}`` is

```math
e_{k}(x) = \min_{i \in [k]} \left|x - x_{i}\right|
```

Assuming that ``x`` behaves as a uniformly distributed random variable, the expected absolute encoding error is

```math
\begin{align*}
\mathbb{E}\left[{e_{k}(x)}\right] &= \frac{1}{L} \int_{a}^{b} e_{k}(x) ~\mathrm{d}x \\
                              &= \frac{1}{4} \frac{L}{k - 1}
\end{align*}
```

Thus, for encoding methods that rely on the regular division of an interval, it is possible to define the number of samples ``k`` necessary to limit the expected error according to an upper bound ``\tau``, that is,

```math
\mathbb{E}\left[{e_{k}(x)}\right] \le \tau \implies k \ge 1 + \frac{L}{4 \tau}
```

This allows the compiler to automatically infer the number of bits to allocate for an encoded variable given the tolerance factor.
For a bounded continuous variable, an explicit
[`ToQUBO.Attributes.VariableEncodingBits`](@ref) value fixes the bit count
directly. When no bit count is set, the compiler reads
[`ToQUBO.Attributes.VariableEncodingATol`](@ref), falling back to
[`ToQUBO.Attributes.DefaultVariableEncodingATol`](@ref), and calls
[`ToQUBO.Encoding.encoding_bits`](@ref) for the selected encoding method and
the variable bounds.

For the default [`ToQUBO.Encoding.Binary`](@ref) method, ``k = 2^n`` evenly
spaced values are represented by ``n`` target binary variables. Combining
``k = 2^n`` with the tolerance bound gives

```math
n \ge \log_{2} \left(1 + \frac{L}{4 \tau}\right),
```

so the compiler uses
``\left\lceil \log_{2} \left(1 + L / 4\tau\right) \right\rceil`` bits.
Other continuous-variable encoding methods use the same tolerance and bounds
inputs with their method-specific
[`ToQUBO.Encoding.encoding_bits`](@ref) or
[`ToQUBO.Encoding.encoding_points`](@ref) rule.

## Constraint Reformulation

A QUBO model is unconstrained, so `ToQUBO` translates each supported source
constraint into a penalty term and adds it to the objective. The default
reformulations below are nonnegative and are constructed to vanish when the
residual and any required slack can be represented exactly. The implementation
lives in
[`src/compiler/constraints.jl`](https://github.com/JuliaQUBO/ToQUBO.jl/blob/main/src/compiler/constraints.jl).

For a scalar affine or quadratic function ``f(x)``, the compiler first forms a
residual ``g(x)`` relative to the set bound. The default reformulations are:

| MOI set | Feasible residual | Penalty before multiplying by ``\rho`` |
|:--|:--|:--|
| `EqualTo(b)` | ``g(x) = f(x) - b = 0`` | ``g(x)^2`` |
| `LessThan(u)` | ``g(x) = f(x) - u \leq 0`` | ``(g(x) + z)^2`` |
| `GreaterThan(l)` | ``g(x) = f(x) - l \geq 0`` | ``(g(x) - z)^2`` |
| `Interval(l, u)` | ``l \leq f(x) \leq u`` | the sum of the `GreaterThan(l)` and `LessThan(u)` penalties |

The `EqualTo` row shows the default
[`ToQUBO.Attributes.QuadraticPenalty`](@ref) method. Its sign-definite shortcut
and the optional [`ToQUBO.Attributes.LinearPenalty`](@ref) method are described
below.

The one-sided reformulations introduce a bounded nonnegative slack ``z`` so
that feasible residuals can be brought to zero. If ``L_g`` and ``U_g`` are
bounds on the residual, `LessThan` uses ``z \in [0, |L_g|]`` and
`GreaterThan` uses ``z \in [0, |U_g|]``. `Interval` constraints are split at
their lower and upper bounds and the two generated penalties are added.

The compiler also uses residual bounds to avoid unnecessary slack variables or
higher-order terms. A `LessThan` residual that is already nonnegative over the
encoded domain can be used directly as ``g(x)``; a `GreaterThan` residual that
is already nonpositive can be used as ``-g(x)``. For an `EqualTo` constraint,
a nonnegative residual can be used directly instead of squared. These
sign-definite shortcuts preserve zero exactly at feasible assignments. The
compiler separately detects always-feasible and infeasible constraints; the
corresponding warning, omission, and error behavior is controlled by the
[constraint feasibility actions](@ref "Constraint Feasibility Actions").

The generated penalty is multiplied by ``\rho`` before it is added to the
objective. Automatic inference, fixed hints, and per-constraint overrides for
``\rho`` are documented under [Automatic Penalty Inference](@ref) and
[Changing Penalty Values](@ref).

### Continuous Slack Resolution

An integer slack can be represented on its integer grid. A continuous slack,
however, still needs a finite binary encoding before the QUBO is built. Set
[`ToQUBO.Attributes.SlackVariableEncodingBits`](@ref) to fix its bit count, or
use [`ToQUBO.Attributes.SlackVariableEncodingATol`](@ref) to choose the
tolerance used for bit-count inference. The selected encoding method comes from
[`ToQUBO.Attributes.SlackVariableEncodingMethod`](@ref).

The required real-valued slack can fall between two values on the encoded grid.
In that case ``g(x) \pm z`` cannot reach zero even though the original
continuous inequality is feasible, leaving a positive squared-residual floor.
Finer resolution reduces this representation error but consumes more target
binary variables and can change the effective penalty landscape. The bit-count
relationship is derived in [Representation Error](@ref), and the user-facing
settings are summarized under [Continuous Variable Resolution](@ref).

Sampling-feasibility behavior that motivated this documentation is tracked in
[#205](https://github.com/JuliaQUBO/ToQUBO.jl/issues/205). The resolution and
penalty interaction is being analyzed in
[#208](https://github.com/JuliaQUBO/ToQUBO.jl/issues/208), while a possible
slack-free alternative is tracked separately in
[#207](https://github.com/JuliaQUBO/ToQUBO.jl/issues/207).

Equality constraints use a squared residual penalty by default. The compiler
can also encode an equality constraint with a signed linear residual through
[`ToQUBO.Attributes.LinearPenalty`](@ref). This option follows the linear Ising
penalty method studied by Mirkarimi et al.[^Mirkarimi2024PRR] and demonstrated
experimentally for quantum annealing.[^Mirkarimi2024NJP] It is a heuristic
method: the sign and magnitude of ``\rho`` affect whether the residual
discourages the intended violations, so `ToQUBO` requires an explicit
[`ToQUBO.Attributes.ConstraintEncodingPenaltyHint`](@ref) instead of inferring
``\rho`` automatically.

When any reformulation creates terms above quadratic degree, the compiler marks
the model for quadratization and reduces those terms before building the target
QUBO.

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
