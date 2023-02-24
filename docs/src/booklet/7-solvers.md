# QUBO Solvers

## Solvers, Annealers & Samplers
[`ToQUBO.jl`](https://github.com/psrenergy/ToQUBO.jl)'s main goal is to make use of parameterized stochastic optimization solvers, particularly those relying on non-conventional hardware such as *Quantum Annealing* and other *Ising Machines*.
A few `MOI`-compliant interfaces for annealers and samplers are bundled within [`ToQUBO.jl`](https://github.com/psrenergy/ToQUBO.jl) via the [`Anneal.jl`](https://github.com/psrenergy/Anneal.jl) companion package.
Some of them are presented below.

## Simulated Annealing
Provided by D-Wave's open-source code libraries, this [Simulated Annealing](https://en.wikipedia.org/wiki/Simulated_annealing) engine implements some of the features and configurations you would find using the Quantum API.
Its adoption is recommended for basic usage, tests, and research due to its robustness, simplicity and ease of use.
The [`DWaveNeal.jl`](https://github.com/psrenergy/DWaveNeal.jl) package uses [`Anneal.jl`](https://github.com/psrenergy/Anneal.jl) to deliver an interface to this sampler.

## Quantum Annealing
Interfacing with [D-Wave](https://www.dwavesys.com/)'s quantum annealer is one of the milestones we expect to achieve with this package.
Like other proprietary optimization resources such as [Gurobi](https://gurobi.com), [FICO® Xpress](https://www.fico.com/en/products/fico-xpress-solver) and [IBM® CPLEX®](https://www.ibm.com/products/ilog-cplex-optimization-studio/cplex-optimizer), this requires licensing and extra steps are needed to get an access token.
In a first moment, for those willing to get started, the [`DWaveNeal.jl`](https://github.com/psrenergy/DWaveNeal.jl) optimizer might be enough to learn the ropes.

## Random Sampling
This sampler is implemented for test purposes and simply assigns 0 or 1 to each variable according to a given probability bias ``0 \le p \le 1``, which defaults to ``p = 0.5``.
After running the `using Anneal` command, `RandomSampler.Optimizer` will be available.

## Exact Solver (Exhaustive Enumeration)
Also made to be used in tests, the `ExactSolver.Optimizer` interface runs through all possible state configurations, which implies in an exponential time complexity on the number of variables.
Thus, only problems with at most ``\approxeq 20`` variables should be provided since visiting ``2^{20} \approxeq 10^{6}`` states can already take up to a few seconds.

## Mixed-Integer Quadratic Programming
The most accessible alternative to the forementioned methods are Mixed-Integer Quadratic Programming (MIQP) solvers such as [Gurobi](https://github.com/jump-dev/Gurobi.jl), [CPLEX](https://github.com/jump-dev/CPLEX.jl), [SCIP](https://github.com/scipopt/SCIP.jl) and [BARON](https://github.com/jump-dev/BARON.jl).
These are not intended to be of regular use alongside [`ToQUBO.jl`](https://github.com/psrenergy/ToQUBO.jl) since providing a QUBO reformulation will usually make things harder for non-specialized solvers.
Yet, there are still a few cases where they may be suitable, such as tests, benchmarks, or any other situation where global optimality is a must.
