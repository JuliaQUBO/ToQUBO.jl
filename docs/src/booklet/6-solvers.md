# QUBO Solvers

## Solvers, Annealers & Samplers
`ToQUBO`'s main goal is to benefit from non-deterministic samplers, especially *Quantum Adiabatic* devices and other *Annealing* machines. A few `MOI`-compliant interfaces for annealers and samplers are bundled within `ToQUBO` via the `Anneal.jl` submodule and package prototype. Some of them are presented below.

### Simulated Annealing
Provided by D-Wave's open-source code libraries, this [Simulated Annealing](https://en.wikipedia.org/wiki/Simulated_annealing) engine implements some of the features and configuration you would find using the Quantum API. Its adoption is recommended for basic usage, tests, and during early research steps due to its simplicity and ease of use. It does not implement the most advanced Simulated Annealing algorithm available but performs fairly well on small instances. `Anneal.jl` exports this interface as `SimulatedAnnealer.Optimizer`.

### Quantum Annealing
Interfacing with [D-Wave](https://www.dwavesys.com/)'s quantum computers is one of the milestones we expect to achieve with this package. Like other proprietary optimization resources such as [Gurobi](https://gurobi.com) and [FICO® Xpress](https://www.fico.com/en/products/fico-xpress-solver), this requires licensing and extra steps are needed to get access to it. In a first moment, for those willing to get started, the *Simulated Annealing* optimizer might be enough.

While in `JuMP`, run `using Anneal` and look for `QuantumAnnealer.Optimizer`.

### Random Sampling
This sampler is implemented for test purposes and simply assigns 0 or 1 to each variable according to a given probability bias ``0 \le p \le 1``, which defaults to ``p = 0.5``. After running the `using Anneal` command, `RandomSampler.Optimizer` will be available.

### Exact Solver (Exaustive Enumeration)
Also made to be used in tests, the `ExactSolver.Optimizer` interface runs through all possible state configurations, which implies in an exponential time complexity on the number of variables. Thus, only problems with no more than 20 variables should be provided.

## MIQP Solvers
The most accessible alternative to Annealers and Samplers are Mixed-Integer Quadratic Programming (MIQP) Solvers such as [Gurobi](https://github.com/jump-dev/Gurobi.jl) and [CPLEX](https://github.com/jump-dev/CPLEX.jl). These are not intended to be of regular use alongside `ToQUBO` since reformulation usually makes things harder for these folks. Yet, there are still cases where they may be suitable for tests on small instances.
