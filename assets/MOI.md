# MathOptInterface API Coverage (Template)

### Reference:
[jump.dev/MathOptInterface.jl/stable/tutorials/implementing/](https://jump.dev/MathOptInterface.jl/stable/tutorials/implementing/)

<!-- Symbols: ✔️❌⚠️ -->

## Optimizer

| Method                         | Status |
| :----------------------------- | :----: |
| `MOI.empty!(::Optimizer)`      |   ⚠️    |
| `MOI.is_empty(::Optimizer)::Bool`    |   ⚠️    |
| `MOI.optimize!(::Optimizer)`   |   ⚠️    |
| `Base.show(::IO, ::Optimizer)` |   ❌    |

## Constraint Support

| Method                                                                                                                      | Status |
| :-------------------------------------------------------------------------------------------------------------------------- | :----: |
| `MOI.supports_constraint(`<br/>`::Optimizer,`<br/>`::Type{<:MOI.AbstractFunction},`<br/>`::Type{<:MOI.AbstractSet}`<br/>`)::Bool` |   ⚠️    |

## The `copy_to` interface 

| Method                                      | Status |
| :------------------------------------------ | :----: |
| `MOI.copy_to(::Optimizer, ::MOI.ModelLike)` |   ⚠️    |

## The incremental interface 

| Method                                                                                                                  | Status |
| :---------------------------------------------------------------------------------------------------------------------- | :----: |
| `MOI.add_variable(::Optimizer)::MOI.VariableIndex`                                                                                         |   ⚠️    |
| `MOI.add_variables(::Optimizer, ::Int)::Vector{MOI.VariableIndex}`                                                                                 |   ⚠️    |
| `MOI.add_constraint(`<br/>`::Optimizer,`<br/>`::F,`<br/>`::S`<br/>`)::MOI.ConstraintIndex{F, S} where {F, S}`                  |   ⚠️    |
| `MOI.add_constraints(`<br/>`::Optimizer,`<br/>`Vector{F},`<br/>`Vector{S}`<br/>`)::Vector{MOI.ConstraintIndex{F, S}} where {F, S}` |   ⚠️    |
| `MOI.is_valid(::Optimizer, i::MOI.Index)::Bool`                                                                                             |   ⚠️    |
| `MOI.delete(::Optimizer, i::MOI.Index)`                                                                                               |   ⚠️    |

| Property                    | Type      | `get` | `set` | `supports` |
| :-------------------------- | :-------- | :---: | :---: | :--------: |
| `MOI.SolverName`            | `String`  |   ⚠️   |   ❌   |     ❌      |
| `MOI.SolverVersion`         | `String`  |   ⚠️   |   ❌   |     ❌      |
| `MOI.RawSolver`             | `String`  |   ⚠️   |   ❌   |     ❌      |
| `MOI.Name`                  | `String`  |   ⚠️   |   ⚠️   |     ⚠️      |
| `MOI.Silent`                | `Bool`    |   ⚠️   |   ⚠️   |     ⚠️      |
| `MOI.TimeLimitSec`          | `Float64` |   ⚠️   |   ⚠️   |     ⚠️      |
| `MOI.RawOptimizerAttribute` | `?`       |   ⚠️   |   ⚠️   |     ⚠️      |
| `MOI.NumberOfThreads`       | `Int`     |   ⚠️   |   ⚠️   |     ⚠️      |

## Model

| Method                         | Status |
| :----------------------------- | :----: |
| `MOI.empty!(::Optimizer)`      |   ⚠️    |
| `MOI.is_empty(::Optimizer)`    |   ⚠️    |
| `MOI.optimize!(::Optimizer)`   |   ⚠️    |
| `Base.show(::IO, ::Optimizer)` |   ❌    |

| Property | Type | `get` | `set` | `supports` |
| :------- | :--- | :---: | :---: | :--------: |
|          |      |   ⚠️   |   ⚠️   |     ⚠️      |

## Key
| Symbol | Meaning                 |
| :----: | :---------------------- |
|   ✔️    | Already implemented     |
|   ❌    | Not implemented         |
|   ⚠️    | Needs to be implemented |