# VirtualQUBOModel
## MathOptInterface API Coverage

This Document is intended to help keeping track of which MOI API Methods and Properties have been implemented for a new solver or model interface.

### Reference:
[jump.dev/MathOptInterface.jl/stable/tutorials/implementing/](https://jump.dev/MathOptInterface.jl/stable/tutorials/implementing/)

<!-- Symbols: ✔️❌⚠️ -->

## Optimizer

| Method                            | Status |
| :-------------------------------- | :----: |
| `MOI.empty!(::Optimizer)`         |   ⚠️    |
| `MOI.is_empty(::Optimizer)::Bool` |   ⚠️    |
| `MOI.optimize!(::Optimizer)`      |   ⚠️    |
| `Base.show(::IO, ::Optimizer)`    |   ❌    |

## Constraint Support

| Method                                                                                                                            | Status |
| :-------------------------------------------------------------------------------------------------------------------------------- | :----: |
| `MOI.supports_constraint(`<br/>`::Optimizer,`<br/>`::Type{<:MOI.AbstractFunction},`<br/>`::Type{<:MOI.AbstractSet}`<br/>`)::Bool` |   ⚠️    |

## The `copy_to` interface 

| Method                                      | Status |
| :------------------------------------------ | :----: |
| `MOI.copy_to(::Optimizer, ::MOI.ModelLike)` |   ⚠️    |

## Attributes

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