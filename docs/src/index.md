# ToQUBO.jl Documentation

`ToQUBO.jl` is a Julia Package intended to automatically translate models written in [JuMP](https://github.com/jump-dev/JuMP.jl), into the [QUBO](https://en.wikipedia.org/wiki/Quadratic_unconstrained_binary_optimization) mathematical optimization framework.

## Getting Started

### Installation
```julia
julia> import Pkg

julia> Pkg.add("ToQUBO")
```

### Running
```julia
using JuMP
using ToQUBO
using Anneal

model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

@variable(model, x[1:3], Bin)

@objective(model, Max, 1.0*x[1] + 2.0*x[2] + 3.0*x[3])

@constraint(model, 0.3*x[1] + 0.5*x[2] + 1.0*x[3] <= 1.6)

optimize!(model)

for i = 1:result_count(model)
    xᵢ = value.(x, result = i)
    yᵢ = objective_value(model, result = i)
    println("f($xᵢ) = $yᵢ")
end
```

## Citing ToQUBO.jl
If you use `ToQUBO.jl` in your work, we kindly ask you to include the following citation:
```tex
@software{toqubo:2022,
  author       = {Pedro Xavier and Tiago Andrade and Joaquim Garcia and David Bernal},
  title        = {{ToQUBO.jl}},
  month        = mar,
  year         = 2022,
  publisher    = {Zenodo},
  version      = {v0.1.0},
  doi          = {10.5281/zenodo.6387592},
  url          = {https://doi.org/10.5281/zenodo.6387592}
}
```