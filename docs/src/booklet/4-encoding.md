# Encoding Methods

## Variable Encoding

As you should already know, QUBO models are comprised only of binary variables. So when we are reformulating general optimization problems, one important step is to encode variables into binary ones. 

`ToQUBO` currently implements 6 encoding techniques. Each method introduces a different number of variables, quadratic terms and linear terms. Also, they differ in the range of their coefficients($\Delta$).

| Encoding            | Binary Variables | # Linear terms | # Quadratic terms | $\Delta$ |
|:---------------------:|:------------------:|:----------------:|:-------------------:|:----------:|
| Binary              |  $O(log \ n)$    |  $O(log \ n)$  |      -            | $O(n)$  |
| Unary               |    $O(n)$        |    $O(n)$      |      -            | $O(1)$  |
| One-Hot             |    $O(n)$        |    $O(n)$      |      $O(n^2)$     | $O(n)$  |
| Domain-Wall         |    $O(n)$        |    $O(n)$      |      $O(n)$       | $O(n)$  |
| Bounded-Coefficient |    $O(n)$        |    $O(n)$      |       -           | $O(1)$  |
| Arithmetic Prog     |  $O(\sqrt{n})$   |  $O(\sqrt{n})$ |       -           | $O(\sqrt{n})$  |


### Linear Encoding Methods
```@docs
ToQUBO.Mirror
```

```@docs
ToQUBO.LinearEncoding
ToQUBO.Linear
ToQUBO.Binary
ToQUBO.Unary
ToQUBO.Arithmetic
ToQUBO.OneHot
```

### Sequential Encoding Methods
```@docs
ToQUBO.SequentialEncoding
ToQUBO.DomainWall
```

### Bounded Coefficients
```@docs
ToQUBO.Bounded
```

## Constraint Encoding

As you should already know, a QUBO model is unconstrained. So when `ToQUBO` is reformulating a problem, it needs to encode all constraints into the objective function loosing as little information as possible.

As constraints are introduced into the objective function, we need to make sure that they won't be violated. In order to do that, `ToQUBO` multiplies the encoded constraint by a large penalty $\rho$, so that any violation would result in an infeasible solution to the problem.

Sometimes, moving a constraint to the objective fuction might introduce higher-order terms (degree > 2). If that is the case, `ToQUBO` needs to reduce it back to a quadratic function. 

As of today, `ToQUBO` provides encoding for the following constraints:

```@docs
ToQUBO.toqubo_constraint
```

