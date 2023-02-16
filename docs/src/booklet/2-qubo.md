# QUBO

## Definition

```math
\begin{array}{rl}
   \min        & \mathbf{x}^{\intercal} Q\,\mathbf{x} \\
   \text{s.t.} & \mathbf{x} \in \mathbb{B}^{n}
\end{array}
```

## OK, but why QUBO?

```@docs
ToQUBO.isqubo
ToQUBO.toqubo
ToQUBO.toqubo!
```

```@docs
ToQUBO.toqubo_sense!
ToQUBO.toqubo_variables!
ToQUBO.toqubo_constraint
ToQUBO.toqubo_constraints!
ToQUBO.toqubo_objective!
ToQUBO.toqubo_penalties!
ToQUBO.toqubo_parse!
ToQUBO.toqubo_build!
```