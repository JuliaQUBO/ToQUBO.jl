# Pseudo-Boolean Optimization
Internally, problems are represented through a Pseudo-Boolean Optimization (PBO) framework.
The main goal is to represent a given problem using a Pseudo-Boolean Function (PBF) since there is an immediate correspondence between quadratic PBFs and QUBO forms.

```@docs
ToQUBO.PBO.PseudoBooleanFunction
```

## Quadratization
In order to successfully achieve a QUBO formulation, sometimes it is needed to quadratize the resulting PBF, i.e., reduce its degree until reaching the quadratic case. There are many quadratization methods available, and `ToQUBO` implements a few of them.

```@docs
ToQUBO.PBO.quadratize!
```

### A Primer on Submodularity
A set function ``f : 2^{S} \to \mathbb{R}`` is said to be submodular if

```math
f(X \cup Y) + f(X \cap Y) \le f(X) + f(Y) \forall X, Y \subset S
```

holds.