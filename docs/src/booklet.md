# ToQUBO.jl Booklet
This booklet aims to gather the theoretical and practical details behind `ToQUBO` and provide documentation for project internals. The target audience includes, among others, advanced users and those willing to contribute to the project. The latter are advised to read the following sections, as they give a glimpse of the ideas employed up to now.

## QUBO
```math
\begin{array}{rl}
   \min        & \mathbf{x}^{\intercal} Q\,\mathbf{x} \\
   \text{s.t.} & \mathbf{x} \in \mathbb{B}^{n}
\end{array}
```

```@docs
ToQUBO.isqubo
ToQUBO.toqubo
ToQUBO.toqubo!
```

```@docs
ToQUBO.toqubo_sense!
ToQUBO.toqubo_variables!
ToQUBO.toqubo_constraint!
ToQUBO.toqubo_objective!
```

## Pseudo-Boolean Optimization
Internally, problems are represented through a Pseudo-Boolean Optimization (PBO) framework. The main goal is to represent a given problem using a Pseudo-Boolean Function (PBF) since there is an immediate correspondence between quadratic PBFs and QUBO forms.

```@docs
ToQUBO.PBO.PseudoBooleanFunction
ToQUBO.PBO.residual
ToQUBO.PBO.derivative
ToQUBO.PBO.gradient
ToQUBO.PBO.gap
ToQUBO.PBO.sharpness
ToQUBO.PBO.discretize
ToQUBO.PBO.relaxed_gcd
```

### A Primer on Submodularity

A set function ``f : 2^{S} \to \mathbb{R}`` is said to be submodular if

```math
f(X \cup Y) + f(X \cap Y) \le f(X) + f(Y) \forall X, Y \subset S
```

holds.

### Quadratization
In order to successfully achieve a QUBO formulation, sometimes it is needed to quadratize the resulting PBF, i.e., reduce its degree until reaching the quadratic case. There are many quadratization methods available, and `ToQUBO` implements a few of them.

```@docs
ToQUBO.PBO.quadratize
ToQUBO.PBO.@quadratization
```

## Virtual Mapping
During reformulation, `ToQUBO` holds two distinct models, namely the *Source Model* and the *Target Model*. The source model is a generic `MOI` model restricted to the supported constraints. The target one is on the QUBO form used during the solving process. Both lie within a *Virtual Model*, which provides the necessary API integration and keeps all variable and constraint mapping tied together.

This is done in a transparent fashion for both agents since the user will mostly interact with the presented model, and the solvers will only access the generated one.

### Virtual Variables
Every virtual model stores a collection of virtual variables, intended to provide a link between those in the source and those to be created in the target model. Each virtual variable stores enconding information for later expansion and evaluation.

```@docs
ToQUBO.VirtualMapping.VirtualVariable
ToQUBO.VirtualMapping.mapvar!
ToQUBO.VirtualMapping.expandℝ!
ToQUBO.VirtualMapping.slackℝ!
ToQUBO.VirtualMapping.expandℤ!
ToQUBO.VirtualMapping.slackℤ!
ToQUBO.VirtualMapping.mirror𝔹!
ToQUBO.VirtualMapping.slack𝔹!
```

### Virtual Models
```@docs
ToQUBO.VirtualModel
```

### Annealing & Sampling
`ToQUBO`'s main goal is to benefit from non-deterministic samplers, especially *Quantum Adiabatic* devices and other *Annealing* machines. A few `MOI`-compliant interfaces for annealers and samplers are bundled within `ToQUBO` via the `Anneal.jl` submodule and package prototype. Some of them are presented below.

### Quantum Annealing
Interfacing with [D-Wave](https://www.dwavesys.com/)'s quantum computers is one of the milestones we expect to achieve with this package. Like other proprietary optimization resources such as [Gurobi](https://gurobi.com) and [FICO® Xpress](https://www.fico.com/en/products/fico-xpress-solver), this requires licensing and extra steps are needed to get access to it. In a first moment, for those willing to get started, the *Simulated Annealing* optimizer might be enough.

While in `JuMP`, run `using Anneal` and look for `QuantumAnnealer.Optimizer`.

### Simulated Annealing
Provided by D-Wave's open-source code libraries, this [Simulated Annealing](https://en.wikipedia.org/wiki/Simulated_annealing) engine implements some of the features and configuration you would find using the Quantum API. Its adoption is recommended for basic usage, tests, and during early research steps due to its simplicity and ease of use. It does not implement the most advanced Simulated Annealing algorithm available but performs fairly well on small instances. `Anneal.jl` exports this interface as `SimulatedAnnealer.Optimizer`.

### Random Sampling
This sampler is implemented for test purposes and simply assigns 0 or 1 to each variable according to a given probability bias ``0 \le p \le 1``, which defaults to ``p = 0.5``. After running the `using Anneal` command, `RandomSampler.Optimizer` will be available.

### Exact Solver (Exaustive Enumeration)
Also made to be used in tests, the `ExactSolver.Optimizer` interface runs through all possible state configurations, which implies in an exponential time complexity on the number of variables. Thus, only problems with no more than 20 variables should be provided.

## MIQP Solvers
The most accessible alternative to Annealers and Samplers are Mixed-Integer Quadratic Programming (MIQP) Solvers such as [Gurobi](https://github.com/jump-dev/Gurobi.jl) and [CPLEX](https://github.com/jump-dev/CPLEX.jl). These are not intended to be of regular use alongside `ToQUBO` since reformulation usually makes things harder for these folks. Yet, there are still cases where they may be suitable for tests on small instances.

### Custom Error Types
```@docs
ToQUBO.QUBOError
```