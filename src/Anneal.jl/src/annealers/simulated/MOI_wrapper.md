# Simulated Annealer

## MathOptInterface API Coverage
This Document is intended to help keeping track of which MOI API Methods and Properties have been implemented for a new solver or model interface.

### Reference:
[jump.dev/MathOptInterface.jl/stable/tutorials/implementing/](https://jump.dev/MathOptInterface.jl/stable/tutorials/implementing/)

## Attributes
| Property            | Type                      | `get` | `set` | `supports` |
| :------------------ | :------------------------ | :---: | :---: | :--------: |
| `MOI.SolverName`    | `::String`                |   ✔️   |   -   |     -      |
| `MOI.SolverVersion` | `::String`                |   ✔️   |   -   |     -      |
| `MOI.RawSolver`     | `<:MOI.AbstractOptimizer` |   ✔️   |   -   |     -      |

## Solver-specific attributes
| Property         | Type    | `get` | `set` | `supports` |
| :--------------- | :------ | :---: | :---: | :--------: |
| `NumberOfSweeps` | `::Int` |   ✔️   |   ✔️   |     -      |

## Key
| Symbol | Meaning                 |
| :----: | :---------------------- |
|   ✔️    | Already implemented     |
|   ❌    | Not implemented         |
|   ⚠️    | Needs to be implemented |