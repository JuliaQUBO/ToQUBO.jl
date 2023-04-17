# QUBO

## Definition
**Q**uadratic **U**nconstrained **B**inary **O**ptimization, as its name suggests, refers to the global minimization or maximization of a given quadratic polynomial over binary variables whose domain is not constrained in any way.
A common mathematical presentation is given by their quadratic matrix form, i.e.

```math
\begin{array}{rl}
   \min_{\mathbf{x}} & \mathbf{x}' Q\,\mathbf{x} \\
   \textrm{s.t.}     & \mathbf{x} \in \mathbb{B}^{n}
\end{array}
```

where ``Q \in \mathbb{R}^{n \times n}`` is symmetric and ``\mathbb{B} = \lbrace{0, 1}\rbrace``.

## OK, but why QUBO?
Mathematically speaking, there is a notorious equivalence between QUBO and [Max-Cut](https://en.wikipedia.org/wiki/Maximum_cut) problems, e.g. for every QUBO instance there is an information preserving Max-Cut reformulation and vice versa.
This statement has two immediate implications:
1. In the general case, solving QUBO globally is NP-Hard.
2. It is a simple yet expressive mathematical programming framework.

Implication 1. tells us that such problems are computationally intractable and that heuristics and metaheuristics are to be employed instead of exact methods.
No 2. relates to the fact that we are able to represent many other optimization models by means of the QUBO formalism.

Moreover, [Ising Model](https://en.wikipedia.org/wiki/Ising_model).

```math
\begin{array}{rl}
   \min_{\mathbf{s}} & \mathbf{h}'\mathbf{s} + \mathbf{s}' J\,\mathbf{s} \\
   \textrm{s.t.}     & \mathbf{s} \in \lbrace{-1,+1}\rbrace^{n}
\end{array}
```

With that said, the significant advances in computing systems and algorithms specialized for sampling QUBOs have contributed to their popularity.

Some of the paradigms that stand out for running QUBOs are quantum gate-based optimization algorithms (QAOA and VQE), quantum annealers and hardware-accelerated platforms (Coherent Ising Machines and Simulated Bifurcation Machines).

[![D-Wave Washington 1000Q](../assets/figures/quantum-chip.png)](https://commons.wikimedia.org/wiki/File:D-Wave-Washington-1000Q.jpg)

```@docs
ToQUBO.isqubo
ToQUBO.toqubo
ToQUBO.toqubo!
```
