# Encoding Methods

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


### Linear Encoding
```@docs
ToQUBO.Binary
ToQUBO.Unary
ToQUBO.Arithmetic
ToQUBO.OneHot
```

```@docs
ToQUBO.Mirror
```

### Sequential Encoding
```@docs
ToQUBO.DomainWall
```

### Bounded Coefficients
```@docs
ToQUBO.Bounded
```

## Constraints

A QUBO model is unconstrained. So when `ToQUBO` is reformulating a problem, it needs to encode all constraints into the objective function losing as little information as possible.

As constraints are introduced into the objective function, we need to make sure that they won't be violated.
In order to do that, `ToQUBO` multiplies the encoded constraint by a large penalty ``\rho``, so that any violation would result in a sub-optimal solution to the problem.

Sometimes, the encoding process might introduce higher-order terms, demanding `ToQUBO` to reduce the offending polynomials back to a quadratic form. 

As of today, `ToQUBO` provides encoding for the following constraints:

```@docs
ToQUBO.toqubo_constraint
```

