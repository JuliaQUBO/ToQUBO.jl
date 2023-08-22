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
\forall f \in \mathscr{F}, \forall x \in \mathbb{B}^{n}, \min_{y} \mathcal{Q}\left\lbrace{}f\right\rbrace{}(x; y) = f(x)

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

```@docs
ToQUBO.PBO.NTR_KZFD
ToQUBO.PBO.PTR_BG
```

### Stable Quadratization

The quadratization of a PBF does not guarantee that the resulting function will always be the same, as the order of terms can be different each time. This can be an issue in some situations where a deterministic output is required.

With said that, we have introduced the concept of Stable Quadratization, where the terms of the PBF are sorted, guaranteeing that the resulting PBF will be the same every time.
We have defined it as an attribute of the compiler, with the  [`ToQUBO.Attributes.StableQuadratization`](@ref) flag.

### A Primer on Submodularity
**_Definition:_** A set function ``\varphi : 2^{S} \to \mathbb{R}`` is said to be _submodular_ if the following holds[^Schrijver2003]:

```math
\varphi(X \cup Y) + \varphi(X \cap Y) \le \varphi(X) + \varphi(Y) \forall X, Y \subset S
```

As the definition suggests, submodularity can be understood as the discrete counterpart of convexity, playing a similar role in the analysis of the problem's conditioning.

Indeed, given ``\varphi`` and an element ``s \in S``, we define

```math
\Delta_{s} \varphi(\omega) = \varphi(\omega \cup \set{s}) - \varphi(\omega)
```

That said, ``\varphi`` will be submodular if and only if ``\Delta_{s} \varphi(\omega)`` is nonincreasing for every ``s \in S``.

Informally, the reason why submodularity matters in the present context is due its importance as a rough measure of how "swampy" is the energy landscape.

### Submodular Terms in quadratizated polynomials

This concept directly maps to the pseudo-Boolean functional realm, given the correspondence estabilished by defining the _characteristic vector_ ``\mathbf{x}^{(\omega)} \in \mathbb{B}^{n}`` of a set ``\omega \subseteq [n]`` as

```math
x^{(\omega)}_{j} = \left\lbrace\begin{array}{rl}
    1 & \textrm{if} ~ j \in \omega \\
    0 & \textrm{otherwise}
\end{array}\right.
```

and the _characteristic set_ ``\omega^{(\mathbf{x})} = \set{j \in [n] : x_{j} = 1}`` of a vector as ``\mathbf{x} \in \mathbb{B}^{n}``.
With these two definitions in hand, one is able construct pseudo-Boolean polynomials from any set function and vice versa.

Besides the amount of additional variables required, each quadratization procedure yields a specific amount of non-submodular terms[^Dattani2019] depending on the input.
Therefore, the choice of the degree-reduction technique that best fits each incoming expression may lead to an enormous impact on the overall resource budget as well as the conditioning of the final reformulation.

[^Schrijver2003]: Alexander Schrijver, **Combinatorial Optimization - Polyhedra and Efficiency**, p. 766-767, _Springer_, 2003 [{isbn}](https://link.springer.com/book/9783540443896).
