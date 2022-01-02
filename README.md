# ToQUBO.jl 🟥🟩🟪🟦

![logo](./assets/logo.svg)

## Introduction

## List of Interpretable Constraints

### Linear constraints
| Mathematical Constraint | MOI Function         | MOI          | Status |
| ----------------------- | -------------------- | ------------ | ------ |
| **a**ᵀ**x** ≤ β         | ScalarAffineFunction | LessThan     | ✔️      |
| **a**ᵀ**x** ≥ α         | ScalarAffineFunction | GreaterThan  | ✔️      |
| **a**ᵀ**x** = β         | ScalarAffineFunction | EqualTo      | ✔️      |
| α ≤ **a**ᵀ**x** ≤ β     | ScalarAffineFunction | Interval     | ⌛      |
| **x**ᵢ ≤ β              | VariableIndex        | LessThan     | ✔️      |
| **x**ᵢ ≥ α              | VariableIndex        | GreaterThan  | ✔️      |
| **x**ᵢ = β              | VariableIndex        | EqualTo      | ✔️      |
| α ≤ **x**ᵢ ≤ β          | VariableIndex        | Interval     | ✔️      |
| A**x** + **b** ∈ ℝⁿ₊    | VectorAffineFunction | Nonnegatives | ❌      |
| A**x** + **b** ∈ ℝⁿ₋    | VectorAffineFunction | Nonpositives | ❌      |
| A**x** + **b** = 0      | VectorAffineFunction | Zeros        | ❌      |

### Conic constraints
| Mathematical Constraint                                       | MOI Function         | MOI Set                          | Status |
| ------------------------------------------------------------- | -------------------- | -------------------------------- | ------ |
| ∥A**x** + **b**∥₂ ≤ **c**ᵀ**x** + d                           | VectorAffineFunction | SecondOrderCone                  | ❌      |
| y ≥ ∥**x**∥₂                                                  | VectorOfVariables    | SecondOrderCone                  | ❌      |
| 2yz ≥ ∥**x**∥₂², y, z ≥ 0                                     | VectorOfVariables    | RotatedSecondOrderCone           | ❌      |
| (**a**₁ᵀ**x** + b₁, **a**₂ᵀ**x** + b₂, **a**₃ᵀ**x** + b₃) ∈ E | VectorAffineFunction | ExponentialCone                  | ❌      |
| A(**x**) ∈ S₊                                                 | VectorAffineFunction | PositiveSemidefiniteConeTriangle | ❌      |
| B(**x**) ∈ S₊                                                 | VectorAffineFunction | PositiveSemidefiniteConeSquare   | ❌      |
| **x** ∈ S₊                                                    | VectorOfVariables    | PositiveSemidefiniteConeTriangle | ❌      |
| **x** ∈ S₊                                                    | VectorOfVariables    | PositiveSemidefiniteConeSquare   | ❌      |

### Quadratic constraints
| Mathematical                       | Constraint	MOI Function | MOI Set                     | Status |
| ---------------------------------- | ----------------------- | --------------------------- | ------ |
| **x**ᵀQ**x** + **a**ᵀ**x** + b ≥ 0 | ScalarQuadraticFunction | GreaterThan                 | ✔️      |
| **x**ᵀQ**x** + **a**ᵀ**x** + b ≤ 0 | ScalarQuadraticFunction | LessThan                    | ✔️      |
| **x**ᵀQ**x** + **a**ᵀ**x** + b = 0 | ScalarQuadraticFunction | EqualTo                     | ✔️      |
| Bilinear matrix inequality         | VectorQuadraticFunction | PositiveSemidefiniteCone... | ❌      |

### Discrete and logical constraints
| Mathematical Constraint            | MOI Function         | MOI Set        | Status |
| ---------------------------------- | -------------------- | -------------- | ------ |
| **x**ᵢ ∈ ℤ                         | VariableIndex        | Integer        | ✔️      |
| **x**ᵢ ∈ {0,1}                     | VariableIndex        | ZeroOne        | ✔️      |
| **x**ᵢ ∈ {0} ∪ \[l, u\]            | VariableIndex        | Semicontinuous | ❌      |
| **x**ᵢ ∈ {0} ∪ {l, l+1, …, u−1, u} | VariableIndex        | Semiinteger    | ❌      |
| [¹](#1)                            | VectorOfVariables    | SOS1           | ❌      |
| [²](#2)                            | VectorOfVariables    | SOS2           | ❌      |
| y = 1 ⟹ **a**ᵀ**x** ∈ S            | VectorAffineFunction | Indicator      | ❌      |

<a id="1">¹</a> 
At most one component of **x** can be nonzero

<a id="2">²</a>
At most two components of **x** can be nonzero, and if so they must be adjacent components

### Legend
- ✔️ Available
- ❌ Unavailable
- ⌛ In Development (Available soon)
- 📖 In need of further reading



<!-- Symbols: ✔️❌⌛📖 -->