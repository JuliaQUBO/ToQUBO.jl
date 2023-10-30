# ToQUBO.jl Documentation

`ToQUBO.jl` is a Julia Package intended to automatically translate models written in [JuMP](https://github.com/jump-dev/JuMP.jl), into the [QUBO](https://en.wikipedia.org/wiki/Quadratic_unconstrained_binary_optimization) mathematical optimization framework.

## Quick Start

### Installation
```julia
julia> import Pkg

julia> Pkg.add("ToQUBO")
```

### Example
```@example
using JuMP
using ToQUBO
using DWave

model = Model(() -> ToQUBO.Optimizer(DWave.Neal.Optimizer))

@variable(model, x[1:3], Bin)
@objective(model, Max, 1.0*x[1] + 2.0*x[2] + 3.0*x[3])
@constraint(model, 0.3*x[1] + 0.5*x[2] + 1.0*x[3] <= 1.6)

optimize!(model)

solution_summary(model)
```

## Citing ToQUBO.jl
If you use `ToQUBO.jl` in your work, we kindly ask you to include the following citation:
```tex
@software{toqubo:2023,
  author       = {Pedro Maciel Xavier and Pedro Ripper and Tiago Andrade and Joaquim Dias Garcia and David E. Bernal Neira},
  title        = {{ToQUBO.jl}},
  month        = {feb},
  year         = {2023},
  publisher    = {Zenodo},
  version      = {v0.1.5},
  doi          = {10.5281/zenodo.7644291},
  url          = {https://doi.org/10.5281/zenodo.7644291}
}
```