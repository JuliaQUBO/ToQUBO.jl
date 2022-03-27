# ToQUBO.jl 🟥🟩🟪🟦

<div align="center">
    <a href="/docs/src/assets/">
        <img src="/docs/src/assets/logo.svg" width=400px alt="ToQUBO.jl" />
    </a>
    <br>
    <a href="https://github.com/psrenergy/ToQUBO.jl/actions/workflows/ci.yml">
        <img src="https://github.com/psrenergy/ToQUBO.jl/actions/workflows/ci.yml/badge.svg?branch=master" alt="CI" />
    </a>
    <a href="https://github.com/psrenergy/ToQUBO.jl/actions/workflows/documentation.yml">
        <img src="https://github.com/psrenergy/ToQUBO.jl/actions/workflows/documentation.yml/badge.svg?branch=master" alt="Documentation">
    </a>
    <a href="https://zenodo.org/badge/latestdoi/430697061">
        <img src="https://zenodo.org/badge/430697061.svg" alt="DOI">
    </a>
</div>

## Introduction
ToQUBO.jl is a Julia Packaget o reformulate general optimization problems into [QUBO](https://en.wikipedia.org/wiki/Quadratic_unconstrained_binary_optimization) (Quadratic Unconstrained Binary Optimization) instances. This tool aims to convert a broad range of [JuMP](https://github.com/jump-dev/JuMP.jl) problems for straightforward application in many physics and physics-inspired solution methods whose normal optimization form is equivalent to the QUBO. These methods include quantum annealing, quantum gate-circuit optimization algorithms (Quantum Optimization Alternating Ansatz, Variational Quantum Eigensolver), other hardware-accelerated platforms, such as Coherent Ising Machines and Simulated Bifurcation Machines, and more traditional methods such as simulated annealing. During execution, ToQUBO.jl encodes both discrete and continuous variables, maps constraints, and computes their penalties, performing a few model optimization steps along the process. We also present a simple interface to connect various annealers and samplers as QUBO solvers bundled in another package, [Anneal.jl](https://github.com/psrenergy/Anneal.jl).

ToQUBO.jl was written as a [MathOptInterface](https://github.com/jump-dev/MathOptInterface.jl) (MOI) layer that automatically maps between input and output models, thus providing a smooth JuMP modeling experience.

## Getting Started

### Installation
ToQUBO is available via Julia's Pkg:
```julia
julia> ]add ToQUBO
```
or
```julia
julia> using Pkg

julia> Pkg.add("ToQUBO")
```

### Simple Example
```julia
using JuMP
using ToQUBO
using Anneal

model = Model(() -> ToQUBO.Optimizer(Anneal.SimulatedAnnealer.Optimizer))

@variable(model, x[1:3], Bin)
@constraint(model, 0.3*x[1] + 0.5*x[2] + 1.0*x[3] <= 1.6)
@objective(model, Max, 1.0*x[1] + 2.0*x[2] + 3.0*x[3])

optimize!(model)
```

## List of Interpretable Constraints
Below, we present a list containing all[⁴](#4) MOI constraint types and their current reformulation support by ToQUBO.

### Linear constraints
| Mathematical Constraint | MOI Function         | MOI          | Status |
| ----------------------- | -------------------- | ------------ | :----: |
| **a**ᵀ**x** ≤ β         | ScalarAffineFunction | LessThan     |   ✔️    |
| **a**ᵀ**x** ≥ α         | ScalarAffineFunction | GreaterThan  |   ♻️    |
| **a**ᵀ**x** = β         | ScalarAffineFunction | EqualTo      |   ✔️    |
| α ≤ **a**ᵀ**x** ≤ β     | ScalarAffineFunction | Interval     |   ♻️    |
| **x**ᵢ ≤ β              | VariableIndex        | LessThan     |   ✔️    |
| **x**ᵢ ≥ α              | VariableIndex        | GreaterThan  |   ✔️    |
| **x**ᵢ = β              | VariableIndex        | EqualTo      |   ✔️    |
| α ≤ **x**ᵢ ≤ β          | VariableIndex        | Interval     |   ✔️    |
| A**x** + **b** ∈ ℝⁿ₊    | VectorAffineFunction | Nonnegatives |   ♻️    |
| A**x** + **b** ∈ ℝⁿ₋    | VectorAffineFunction | Nonpositives |   ♻️    |
| A**x** + **b** = 0      | VectorAffineFunction | Zeros        |   ♻️    |

### Conic constraints
| Mathematical Constraint                                       | MOI Function         | MOI Set                          | Status |
| ------------------------------------------------------------- | -------------------- | -------------------------------- | :----: |
| ∥A**x** + **b**∥₂ ≤ **c**ᵀ**x** + d                           | VectorAffineFunction | SecondOrderCone                  |   ❌    |
| y ≥ ∥**x**∥₂                                                  | VectorOfVariables    | SecondOrderCone                  |   ❌    |
| 2yz ≥ ∥**x**∥₂², y, z ≥ 0                                     | VectorOfVariables    | RotatedSecondOrderCone           |   ❌    |
| (**a**₁ᵀ**x** + b₁, **a**₂ᵀ**x** + b₂, **a**₃ᵀ**x** + b₃) ∈ E | VectorAffineFunction | ExponentialCone                  |   ❌    |
| A(**x**) ∈ S₊                                                 | VectorAffineFunction | PositiveSemidefiniteConeTriangle |   ❌    |
| B(**x**) ∈ S₊                                                 | VectorAffineFunction | PositiveSemidefiniteConeSquare   |   ❌    |
| **x** ∈ S₊                                                    | VectorOfVariables    | PositiveSemidefiniteConeTriangle |   ❌    |
| **x** ∈ S₊                                                    | VectorOfVariables    | PositiveSemidefiniteConeSquare   |   ❌    |

### Quadratic constraints
| Mathematical                       | Constraint	MOI Function | MOI Set                     | Status |
| ---------------------------------- | ----------------------- | --------------------------- | :----: |
| **x**ᵀQ**x** + **a**ᵀ**x** + b ≥ 0 | ScalarQuadraticFunction | GreaterThan                 |   ♻️    |
| **x**ᵀQ**x** + **a**ᵀ**x** + b ≤ 0 | ScalarQuadraticFunction | LessThan                    |   ✔️    |
| **x**ᵀQ**x** + **a**ᵀ**x** + b = 0 | ScalarQuadraticFunction | EqualTo                     |   ✔️    |
| Bilinear matrix inequality         | VectorQuadraticFunction | PositiveSemidefiniteCone... |   ❌    |

### Discrete and logical constraints
| Mathematical Constraint            | MOI Function         | MOI Set        | Status |
| ---------------------------------- | -------------------- | -------------- | :----: |
| **x**ᵢ ∈ ℤ                         | VariableIndex        | Integer        |   ✔️    |
| **x**ᵢ ∈ {0,1}                     | VariableIndex        | ZeroOne        |   ✔️    |
| **x**ᵢ ∈ {0} ∪ \[l, u\]            | VariableIndex        | Semicontinuous |   ❌    |
| **x**ᵢ ∈ {0} ∪ {l, l+1, …, u−1, u} | VariableIndex        | Semiinteger    |   ❌    |
| [¹](#1)                            | VectorOfVariables    | SOS1           |   ❌    |
| [²](#2)                            | VectorOfVariables    | SOS2           |   ❌    |
| y = 1 ⟹ **a**ᵀ**x** ∈ S            | VectorAffineFunction | Indicator      |   ❌    |

<a id="1">¹</a> 
At most one component of **x** can be nonzero

<a id="2">²</a>
At most two components of **x** can be nonzero, and if so they must be adjacent components

| Symbol | Meaning                          |
| :----: | -------------------------------- |
|   ✔️    | Available                        |
|   ♻️    | Available through Bridges[³](#3) |
|   ❌    | Unavailable                      |
|   ⌛    | In Development (Available soon)  |
|   📖    | Under research                   |

<a id="3">³</a> 
[MOI Bridges](https://jump.dev/MathOptInterface.jl/stable/submodules/Bridges/reference/) provide equivalent constraint mapping.

<a id="4">⁴</a>
If you think this list is incomplete, consider creating an [Issue](https://github.com/psrenergy/ToQUBO.jl/issues) or opening a [Pull Request](https://github.com/psrenergy/ToQUBO.jl/pulls).

<!-- Symbols: ✔️❌⌛📖 -->
