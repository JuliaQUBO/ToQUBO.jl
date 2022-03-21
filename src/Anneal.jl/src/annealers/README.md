# Anneal.jl - QUBO Annealers and Samplers

To setup your own QUBO annealing/sampling system, one must implement some `MathOptInterface` and `Anneal` API requirements.

## `MathOptInterface`

| Method              | Return Type | `get` | `set` | `supports` |
| :------------------ | :---------- | :---: | :---: | :--------: |
| `MOI.SolverName`    | `String`    |   ⚠️   |   -   |     -      |
| `MOI.SolverVersion` | `String`    |   ⚠️   |   -   |     -      |
| `MOI.RawSolver`     | `String`    |   ⚠️   |   -   |     -      |

## `Anneal`

### `struct Optimizer{T} <: Anneal.AbstractSampler{T}`

### `Anneal.sample(::Optimizer{T})`

```julia
Anneal.@anew begin
    NumberOfReads::Int = 1_000
end
```