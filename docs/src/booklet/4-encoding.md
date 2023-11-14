# Encoding Methods

```@docs
ToQUBO.Encoding.encode
ToQUBO.Encoding.encode!
ToQUBO.Encoding.encodes
```

## Variables

As you may already know, QUBO models are comprised only of binary variables.
So when we are reformulating general optimization problems, one important step is to encode variables into binary ones.

`ToQUBO` currently implements 6 encoding techniques.
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

### Representation Error

```@docs
ToQUBO.Encoding.encoding_bits
ToQUBO.Encoding.encoding_points
```

Let ``\set{x_{i}}_{i \in [k]}`` be the collection of ``k`` evenly spaced samples from the discretization of an interval ``[a, b] \subseteq \mathbb{R}``.

The representation error for a given point ``x`` with respect to ``\set{x_{i}}_{i \in [k]}`` is

```math
e_{k}(x) = \min_{i \in [k]} \left|x - x_{i}\right|
```

Assuming that ``x`` behaves as a uniformly distributed random variable, the expected absolute encoding error is

```math
\begin{align*}
\mathbb{E}\left[{e_{k}(x)}\right] &= \frac{1}{b - a} \int_{a}^{b} e_{k}(x) ~\mathrm{d}x \\
                              &= \frac{1}{4} \frac{b - a}{k - 1}
\end{align*}
```

Thus, for encoding methods that rely on the regular division of an interval, it is possible to define the number of samples ``k`` necessary to limit the expected error according to an upper bound ``\tau``, that is,

```math
\mathbb{E}\left[{e_{k}(x)}\right] \le \tau \implies k \ge 1 + \frac{b - a}{4 \tau}
```

This allows the compiler to automatically infer the number of bits to allocate for an encoded variable given the tolerance factor.

## Constraints

A QUBO model is unconstrained. So when `ToQUBO` is reformulating a problem, it needs to encode all constraints into the objective function losing as little information as possible.

As constraints are introduced into the objective function, we need to make sure that they won't be violated.
In order to do that, `ToQUBO` multiplies the encoded constraint by a large penalty ``\rho``, so that any violation would result in a sub-optimal solution to the problem.

Sometimes, the encoding process might introduce higher-order terms, demanding `ToQUBO` to reduce the offending polynomials back to a quadratic form.
