# Pseudo-Boolean Optimization

Internally, problems are represented through a Pseudo-Boolean Optimization (PBO) framework.
The main goal is to represent a given problem using a Pseudo-Boolean Function (PBF) since there is an immediate correspondence between optimization over quadratic PBFs and the QUBO formalism.

## Quadratization

In order to successfully achieve a QUBO formulation, sometimes it is needed to quadratize the resulting PBF, i.e., reduce its degree until reaching the quadratic case. 

A quadratization is a mapping ``\mathcal{Q}: \mathscr{F} \to \mathscr{F}^{2}`` such that

```math
\forall f \in \mathscr{F}, \forall x \in \{0, 1\}^{n}, \min_{y} \mathcal{Q}\left\lbrace{}f\right\rbrace{}(x; y) = f(x)
```

There are many quadratization methods available[^Dattani2019], and `ToQUBO` implements two of them for now.
However, using Julia's multiple dispatch paradigm, it's possible to extend the quadratization method coverage with your own algorithms.

[^Dattani2019]:
    Nikesh S. Dattani, **Quadratization in discrete optimization and quantum mechanics**, *ArXiv*, 2019 [{doi}](https://doi.org/10.48550/arXiv.1901.04405)

### Quadratization Methods

### Stable Quadratization

The quadratization of a PBF does not guarantee that the resulting function will always be the same, as the order of terms can be different each time. This can be an issue in some situations where a deterministic output is required.

With said that, we have introduced the concept of Stable Quadratization, where the terms of the PBF are sorted, guaranteeing that the resulting PBF will be the same every time.
We have defined it as an attribute of the compiler, with the  [`ToQUBO.Attributes.StableQuadratization`](@ref) flag.
