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