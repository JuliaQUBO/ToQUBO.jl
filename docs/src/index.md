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
<!-- citation-policy:start -->
For general use of `ToQUBO.jl` and the broader `QUBO.jl` ecosystem, cite the
[published journal article](https://doi.org/10.1080/10556788.2026.2702926).

For a software citation, use the
[Zenodo concept DOI](https://doi.org/10.5281/zenodo.21763525). The concept DOI
is the evergreen identifier for the actively maintained archive. For
exact-version reproducibility, cite the corresponding version DOI; the archive
for `v0.6.1` is
[10.5281/zenodo.21763526](https://doi.org/10.5281/zenodo.21763526).

The corresponding BibTeX entries are:

```bibtex
@article{xavier2026qubojl,
  author       = {Maciel Xavier, Pedro and Ripper, Pedro and Andrade, Tiago and Dias Garcia, Joaquim and Maculan, Nelson and Bernal Neira, David E.},
  title        = {{QUBO.jl: A Julia Ecosystem for Quadratic Unconstrained Binary Optimization}},
  journal      = {Optimization Methods and Software},
  year         = {2026},
  pages        = {1--24},
  doi          = {10.1080/10556788.2026.2702926},
  url          = {https://doi.org/10.1080/10556788.2026.2702926}
}

@software{toqubo:2026,
  author       = {Maciel Xavier, Pedro and Ripper, Pedro and Andrade, Tiago and Dias Garcia, Joaquim and Bernal Neira, David E.},
  title        = {{ToQUBO.jl}},
  year         = {2026},
  publisher    = {Zenodo},
  version      = {v0.6.1},
  doi          = {10.5281/zenodo.21763526},
  url          = {https://doi.org/10.5281/zenodo.21763526},
  note         = {Evergreen concept DOI: 10.5281/zenodo.21763525}
}
```

The [historical concept DOI](https://doi.org/10.5281/zenodo.6387591) covers
releases through `v0.1.6` and remains part of the project's provenance; it is
not the identifier for current releases. Machine-readable metadata is in
[`CITATION.cff`](https://github.com/JuliaQUBO/ToQUBO.jl/blob/main/CITATION.cff),
with BibTeX in
[`CITATION.bib`](https://github.com/JuliaQUBO/ToQUBO.jl/blob/main/CITATION.bib).
<!-- citation-policy:end -->
