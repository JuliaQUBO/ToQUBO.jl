# QUBO

## Definition
**Q**uadratic **U**nconstrained **B**inary **O**ptimization, as the name suggests, refers to the global minimization or maximization of a quadratic polynomial on binary variables.
A common presentation, the quadratic matrix form, is written as

```math
\begin{array}{rl}
   \min_{\mathbf{x}} & \mathbf{x}' Q\,\mathbf{x} \\
   \textrm{s.t.}     & \mathbf{x} \in \mathbb{B}^{n}
\end{array}
```

where ``Q \in \mathbb{R}^{n \times n}`` is symmetric and ``\mathbb{B} = \lbrace{0, 1}\rbrace``.
Note that, since ``x^{2} = x`` holds for ``x \in \mathbb{B}``, the linear terms of the objective function are stored in the main diagonal of ``Q``.

## OK, but why QUBO?
Mathematically speaking, there is a notorious equivalence between QUBO and [Max-Cut](https://en.wikipedia.org/wiki/Maximum_cut) problems, e.g. for every QUBO instance there is an information preserving Max-Cut reformulation and vice versa.
This statement is followed by two immediate implications:

1. In the general case, solving QUBO globally is NP-Hard.
2. It is a simple yet expressive mathematical programming framework.

Implication 1. tells us that such problems are computationally intractable and that heuristics and metaheuristics are to be employed instead of exact methods.
No 2. relates to the fact that we are able to represent many other optimization models by means of the QUBO formalism.

The [Ising Model](https://en.wikipedia.org/wiki/Ising_model), on the other hand, is a mathematical abstraction to describe statistical interactions within mechanical systems with interesting properties for encoding combinatorial problems.
Its _Hamiltonian_ leads to an optimization formulation in terms of the _spin_ values of their states, given by

```math
\begin{array}{rl}
   \min_{\mathbf{s}} & \mathbf{h}'\mathbf{s} + \mathbf{s}' J\,\mathbf{s} \\
   \textrm{s.t.}     & \mathbf{s} \in \lbrace{-1,+1}\rbrace^{n}
\end{array}
```

with strictly upper triangular ``J \in \mathbb{R}^{n \times n}`` and ``\mathbf{h} \in \mathbb{R}``.

[![D-Wave Washington 1000Q](../assets/figures/quantum-chip.png)](https://commons.wikimedia.org/wiki/File:D-Wave-Washington-1000Q.jpg)

The Ising reformulation alternative draws the bridge between QUBO problems and devices designed to sample global or approximate ground states of the Ising Hamiltonian with high probability[^Mohseni2022].
Some of the paradigms that stand out in this context are quantum gate-based optimization algorithms (QAOA and VQE), quantum annealers, hardware-accelerated platforms (Coherent Ising Machines and Simulated Bifurcation Machines) and physics-inspired methods (Simulated Annealing, Parallel Tempering).
The significant advances in these computing systems contributed to the growing popularity of the model across the literature.

[^Mohseni2022]: Mohseni, N., McMahon, P. L. & Byrnes, T. **Ising machines as hardware solvers of combinatorial optimization problems**. _Nat Rev Phys 4_, 363–379 (2022). [{arXiv}](https://arxiv.org/pdf/2204.00276.pdf)
  