# Examples in QUBO.jl

Application-oriented examples for the JuliaQUBO ecosystem now live in the
[`QUBO.jl` documentation](https://juliaqubo.github.io/QUBO.jl/QUBO.jl/dev/),
which serves as the canonical entry point for workflows that combine the
compiler, drivers, and tooling packages.

`ToQUBO.jl` keeps the package-specific workflow and reference material in this
manual. For a local walkthrough of building and solving a model with
`ToQUBO.Optimizer`, see [Running a Model](@ref).

The current example pages in `QUBO.jl` are:

- [Knapsack](https://juliaqubo.github.io/QUBO.jl/QUBO.jl/dev/examples/knapsack/), a small binary model with a capacity constraint that compiles to a compact QUBO.
- [Prime Factorization](https://juliaqubo.github.io/QUBO.jl/QUBO.jl/dev/examples/prime_factorization/), a bounded integer model that highlights automatic encoding and quadratization.
- [Portfolio Optimization](https://juliaqubo.github.io/QUBO.jl/QUBO.jl/dev/examples/portfolio_optimization/), a small continuous allocation model that shows how bounded encodings affect the compiled problem size.
