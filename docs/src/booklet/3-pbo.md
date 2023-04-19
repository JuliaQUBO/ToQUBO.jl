# Pseudo-Boolean Optimization
Internally, problems are represented through a Pseudo-Boolean Optimization (PBO) framework.
The main goal is to represent a given problem using a Pseudo-Boolean Function (PBF) since there is an immediate correspondence between optimization over quadratic PBFs and the QUBO formalism.

```@docs
ToQUBO.PBO.PseudoBooleanFunction
```

## Quadratization
In order to successfully achieve a QUBO formulation, sometimes it is needed to quadratize the resulting PBF, i.e., reduce its degree until reaching the quadratic case. 

A quadratization is a mapping ``\mathcal{Q}: \mathscr{F} \to \mathscr{F}^{2}`` such that

```math 
\forall f \in \mathscr{F}, \forall x \in \{0, 1\}^{n}, \min_{y} \mathcal{Q}\left\lbrace{}f\right\rbrace{}(x; y) = f(x)

```

There are many quadratization methods available[^Dattani2019], and `ToQUBO` implements two of them for now.
However, using Julia's multiple dispatch paradigm, it's possible to extend the quadratization method coverage with your own algorithms.

```@docs
ToQUBO.PBO.quadratize!
```

[^Dattani2019]:
    Nikesh S. Dattani, **Quadratization in discrete optimization and quantum mechanics**, *ArXiv*, 2019 [{doi}](https://doi.org/10.48550/arXiv.1901.04405)

### Implemented Quadratization Techniques

Currently, `ToQUBO` has two reduction algorithms, one for negative and another for positive terms.

For these quadratization techniques, we have introduced a flag `StableQuadratization()`.

```@docs
ToQUBO.Attributes.StableQuadratization
```

```@docs
ToQUBO.PBO.NTR_KZFD
ToQUBO.PBO.PTR_BG
```

### A Primer on Submodularity
A set function ``f : 2^{S} \to \mathbb{R}`` is said to be submodular if

```math
f(X \cup Y) + f(X \cap Y) \le f(X) + f(Y) \forall X, Y \subset S
```

holds.
