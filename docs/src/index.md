# ToQUBO.jl Documentation

`ToQUBO.jl` is a Julia Package intended to automatically translate models written in [JuMP](https://github.com/jump-dev/JuMP.jl), into the [QUBO](https://en.wikipedia.org/wiki/Quadratic_unconstrained_binary_optimization) mathematical optimization framework.

## Quick Start

### Installation

```julia
julia> import Pkg

julia> Pkg.add("ToQUBO")
```

### Example

#### Using the Exact Sampler

```@example
using JuMP
using ToQUBO
using QUBODrivers

model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

@variable(model, x[1:3], Bin)
@objective(model, Max, 1.0*x[1] + 2.0*x[2] + 3.0*x[3])
@constraint(model, 0.3*x[1] + 0.5*x[2] + 1.0*x[3] <= 1.6)

optimize!(model)

solution_summary(model)
```

#### Using PySA (Simulated Annealing)

PySA can be used in the same optimizer wrapper pattern when it is available in
your project environment:

```julia
using JuMP
using ToQUBO
using PySA

model = Model(() -> ToQUBO.Optimizer(PySA.Optimizer))

@variable(model, x[1:3], Bin)
@objective(model, Max, 1.0*x[1] + 2.0*x[2] + 3.0*x[3])
@constraint(model, 0.3*x[1] + 0.5*x[2] + 1.0*x[3] <= 1.6)

optimize!(model)

solution_summary(model)
```

Application-oriented examples now live in the [Examples in QUBO.jl](@ref)
section.

## Citing ToQUBO.jl

If you use `ToQUBO.jl` in your work, we kindly ask you to include the following citation:

```tex
@software{toqubo:2023,
  author       = {Pedro Maciel Xavier and Pedro Ripper and Tiago Andrade and Joaquim Dias Garcia and David E. Bernal Neira},
  title        = {{ToQUBO.jl}},
  month        = {feb},
  year         = {2023},
  publisher    = {Zenodo},
  version      = {v0.1.9},
  doi          = {10.5281/zenodo.7644291},
  url          = {https://doi.org/10.5281/zenodo.7644291}
}
```

For the broader `QUBO.jl` ecosystem paper, cite the published journal article:

```tex
@article{xavier2026qubojl,
  author       = {Pedro Maciel Xavier and Pedro Ripper and Tiago Andrade and Joaquim Dias Garcia and Nelson Maculan and David E. Bernal Neira},
  title        = {{QUBO.jl: A Julia Ecosystem for Quadratic Unconstrained Binary Optimization}},
  journal      = {Optimization Methods and Software},
  year         = {2026},
  pages        = {1--24},
  doi          = {10.1080/10556788.2026.2702926},
  url          = {https://doi.org/10.1080/10556788.2026.2702926}
}
```

The [arXiv preprint](https://arxiv.org/abs/2307.02577) remains available.
