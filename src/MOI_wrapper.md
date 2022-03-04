# VirtualQUBOModel

## MathOptInterface API Coverage
This Document is intended to help keeping track of which MOI API Methods and Properties have been implemented for a new model interface.

### Reference:
[jump.dev/MathOptInterface.jl/stable/manual/models/](https://jump.dev/MathOptInterface.jl/stable/manual/models/)

## Model

| Method                         | Status |
| :----------------------------- | :----: |
| `MOI.empty!(::ModelLike)`      |   ✔️    |
| `MOI.is_empty(::ModelLike)`    |   ✔️    |
| `MOI.optimize!(::ModelLike)`   |   ✔️    |
| `Base.show(::IO, ::ModelLike)` |   ✔️    |

| Property                            | Type                          | `get` | `set` | `supports` |
| :---------------------------------- | :---------------------------- | :---: | :---: | :--------: |
| `MOI.ListOfConstraintAttributesSet` | `Vector`                      |   ✔️   |   -   |     -      |
| `MOI.ListOfConstraintIndices`       | `Vector{MOI.ConstraintIndex}` |   ✔️   |   -   |     -      |
| `MOI.ListOfConstraintTypesPresent`  | `Vector`                      |   ✔️   |   -   |     -      |
| `MOI.ListOfModelAttributesSet`      | `Vector`                      |   ✔️   |   -   |     -      |
| `MOI.ListOfVariableAttributesSet`   | `Vector`                      |   ✔️   |   -   |     -      |
| `MOI.ListOfVariableIndices`         | `Vector{MOI.VariableIndex}`   |   ✔️   |   -   |     -      |
| `MOI.NumberOfConstraints`           | `Int`                         |   ✔️   |   -   |     -      |
| `MOI.NumberOfVariables`             | `Int`                         |   ✔️   |   -   |     -      |
| `MOI.Name`                          | `String`                      |   ✔️   |   ✔️   |     -      |
| `MOI.ObjectiveFunction`             | `F`                           |   ✔️   |   -   |     -      |
| `MOI.ObjectiveFunctionType`         | `Type{<:F}`                   |   ✔️   |   -   |     -      |
| `MOI.ObjectiveSense`                | `MOI.OptimizationSense`       |   ✔️   |   -   |     -      |

## Key
| Symbol | Meaning                 |
| :----: | :---------------------- |
|   ✔️    | Already implemented     |
|   ❌    | Not implemented         |
|   ⚠️    | Needs to be implemented |