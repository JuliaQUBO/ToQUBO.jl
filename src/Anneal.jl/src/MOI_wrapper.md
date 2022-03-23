# Abstract Annealer

## MathOptInterface API Coverage
This Document is intended to help keeping track of which MOI API Methods and Properties have been implemented for a new solver or model interface.

### Reference:
[jump.dev/MathOptInterface.jl/stable/tutorials/implementing/](https://jump.dev/MathOptInterface.jl/stable/tutorials/implementing/)

## Optimizer Interface
| Method                                        | Status |
| :-------------------------------------------- | :----: |
| `MOI.empty!(::Optimizer)`                     |   ✔️    |
| `MOI.is_empty(::Optimizer)::Bool`             |   ✔️    |
| `MOI.optimize!(::Optimizer, ::MOI.ModelLike)` |   ✔️    |
| `Base.show(::IO, ::Optimizer)`                |   ✔️    |

## Constraint Support
| Method                                                              | Status |
| :------------------------------------------------------------------ | :----: |
| `MOI.supports_constraint(::Optimizer, ::F, ::S)::Bool where {F, S}` |   ✔️    |

## Attributes
| Property                    | Type      | `get` | `set` | `supports` |
| :-------------------------- | :-------- | :---: | :---: | :--------: |
| `MOI.SolverName`            | `String`  |   ✔️   |   -   |     -      |
| `MOI.SolverVersion`         | `String`  |   ✔️   |   -   |     -      |
| `MOI.RawSolver`             | `String`  |   ✔️   |   -   |     -      |
| `MOI.Name`                  | `String`  |   ✔️   |   ✔️   |     ✔️      |
| `MOI.Silent`                | `Bool`    |   ✔️   |   ✔️   |     ✔️      |
| `MOI.TimeLimitSec`          | `Float64` |   ✔️   |   ✔️   |     ✔️      |
| `MOI.RawOptimizerAttribute` | `Any`     |   ✔️   |   ✔️   |     ✔️      |
| `MOI.NumberOfThreads`       | `Int`     |   ✔️   |   ✔️   |     ✔️      |

## The `copy_to` interface 
| Method                                      | Status |
| :------------------------------------------ | :----: |
| `MOI.copy_to(::Optimizer, ::MOI.ModelLike)` |   ✔️    |

## Names
| Property             | Type     | `get` | `set` | `supports` |
| :------------------- | :------- | :---: | :---: | :--------: |
| `MOI.VariableName`   | `String` |   ❌   |   -   |     -      |
| `MOI.ConstraintName` | `String` |   ❌   |   -   |     -      |

## Solution
| Property                | Type                        | `get` | `set` | `supports` |
| :---------------------- | :-------------------------- | :---: | :---: | :--------: |
| `MOI.DualStatus`        | `MOI.ResultStatusCode`      |   ❌   |   -   |     -      |
| `MOI.PrimalStatus`      | `MOI.ResultStatusCode`      |   ✔️   |   -   |     -      |
| `MOI.RawStatusString`   | `String`                    |   ✔️   |   -   |     -      |
| `MOI.ResultCount`       | `Int`                       |   ✔️   |   -   |     -      |
| `MOI.TerminationStatus` | `MOI.TerminationStatusCode` |   ✔️   |   -   |     -      |
| `MOI.ObjectiveValue`    | `T`                         |   ✔️   |   -   |     -      |
| `MOI.SolveTimeSec`      | `Float64`                   |   ✔️   |   -   |     -      |
| `MOI.VariablePrimal`    | `T`                         |   ✔️   |   -   |     -      |

| Property                | Type | `get` | `set` | `supports` |
| :---------------------- | :--- | :---: | :---: | :--------: |
| `MOI.ObjectiveFunction` | -    |   -   |   -   |     ✔️      |

## Integer Solver
| Property             | Type | `get` | `set` | `supports` |
| :------------------- | :--- | :---: | :---: | :--------: |
| `MOI.ObjectiveBound` | `T`  |   ⚠️   |   -   |     -      |
| `MOI.RelativeGap`    | `T`  |   ⚠️   |   -   |     -      |

## Warm Start
| Property                  | Type | `get` | `set` | `supports` |
| :------------------------ | :--- | :---: | :---: | :--------: |
| `MOI.VariablePrimalStart` | `T`  |   ❌   |   ❌   |     ❌      |

## Solver-specific attributes
| Property        | Type  | `get` | `set` | `supports` |
| :-------------- | :---- | :---: | :---: | :--------: |
| `NumberOfReads` | `Int` |   ✔️   |   ✔️   |     -      |

## Key
| Symbol | Meaning                 |
| :----: | :---------------------- |
|   ✔️    | Already implemented     |
|   ❌    | Not implemented         |
|   ⚠️    | Needs to be implemented |