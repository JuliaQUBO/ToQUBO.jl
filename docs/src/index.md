# ToQUBO.jl Documentation

`ToQUBO.jl` is a Julia Package intended to automatically translate models written in [JuMP](https://github.com/jump-dev/JuMP.jl), into the [QUBO](https://en.wikipedia.org/wiki/Quadratic_unconstrained_binary_optimization) mathematical optimization framework.

## Installation

### **Pre-release note:**
This project is not yet available through Julia's package manager. Thus, it is still necessary to clone `ToQUBO.jl` from its GitHub repo.
```shell
$ git clone https://github.com/psrenergy/ToQUBO.jl
$ cd ToQUBO.jl
$ julia --project=.
```

To use the `Anneal.jl` submodule, it will be necessary to run
```julia
(ToQUBO) pkg> dev .\\src\\Anneal.jl
```
on Julia's REPL beforehand.

## Citing ToQUBO.jl

If you use `ToQUBO.jl` in your work, we kindly ask you to include the following citation:
```tex
@software{ToQUBO.jl:2022,
  author = {Pedro Xavier and Tiago Andrade and Joaquim Garcia and David Bernal},
  title = {ToQUBO.jl},
  url = {https://github.com/psrenergy/ToQUBO.jl},
  version = {0.1.0},
  date = {2022-03-31},
}
```