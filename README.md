# ToQUBO.jl 🟥🟩🟪🟦

<div align="center">
    <a href="/docs/src/assets/">
        <img src="/docs/src/assets/logo.svg" width=400px alt="ToQUBO.jl" />
    </a>
    <br>
    <a href="https://codecov.io/gh/psrenergy/ToQUBO.jl">
        <img src="https://codecov.io/gh/psrenergy/ToQUBO.jl/branch/master/graph/badge.svg?token=ECM5OQ9T67"/>
    </a>
    <a href="https://github.com/psrenergy/ToQUBO.jl/actions/workflows/ci.yml">
        <img src="https://github.com/psrenergy/ToQUBO.jl/actions/workflows/ci.yml/badge.svg?branch=master" alt="CI" />
    </a>
    <a href="https://psrenergy.github.io/ToQUBO.jl/dev">
        <img src="https://img.shields.io/badge/docs-dev-blue.svg" alt="Docs">
    </a>
    <a href="https://zenodo.org/badge/latestdoi/430697061">
        <img src="https://zenodo.org/badge/430697061.svg" alt="DOI">
    </a>
</div>

## Introduction
ToQUBO.jl is a Julia package to reformulate general optimization problems into [QUBO](https://en.wikipedia.org/wiki/Quadratic_unconstrained_binary_optimization) (Quadratic Unconstrained Binary Optimization) instances. This tool aims to convert a broad range of [JuMP](https://github.com/jump-dev/JuMP.jl) problems for straightforward application in many physics and physics-inspired solution methods whose normal optimization form is equivalent to the QUBO. These methods include quantum annealing, quantum gate-circuit optimization algorithms (Quantum Optimization Alternating Ansatz, Variational Quantum Eigensolver), other hardware-accelerated platforms, such as Coherent Ising Machines and Simulated Bifurcation Machines, and more traditional methods such as simulated annealing. During execution, ToQUBO.jl encodes both discrete and continuous variables, maps constraints, and computes their penalties, performing a few model optimization steps along the process. A simple interface to connect various annealers and samplers as QUBO solvers is defined in [QUBODrivers.jl](https://github.com/psrenergy/QUBODrivers.jl).

ToQUBO.jl was written as a [MathOptInterface](https://github.com/jump-dev/MathOptInterface.jl) (MOI) layer that automatically maps between input and output models, thus providing a smooth JuMP modeling experience.

## Getting Started

### Installation
ToQUBO is available via Julia's Pkg:

```julia
julia> using Pkg

julia> Pkg.add("ToQUBO")
```

### Simple Example
```julia
using JuMP
using ToQUBO
using QUBODrivers

model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

@variable(model, x[1:3], Bin)
@constraint(model, 0.3*x[1] + 0.5*x[2] + 1.0*x[3] <= 1.6)
@objective(model, Max, 1.0*x[1] + 2.0*x[2] + 3.0*x[3])

optimize!(model)

for i = 1:result_count(model)
    xi = value.(x, result = i)
    yi = objective_value(model, result = i)

    println("f($xi) = $yi")
end
```

## List of Interpretable Constraints
Below, we present a list containing all[⁴](#4) MOI constraint types and their current reformulation support by ToQUBO.

### Linear constraints

| Mathematical Constraint                      | MOI Function         | MOI Set      | Status |
| -------------------------------------------- | -------------------- | ------------ | :----: |
| $\vec{a}' \vec{x} \le \beta$            | ScalarAffineFunction | LessThan     |   ✔️    |
| $\vec{a}' \vec{x} \ge \alpha$           | ScalarAffineFunction | GreaterThan  |   ♻️    |
| $\vec{a}' \vec{x} = \beta$              | ScalarAffineFunction | EqualTo      |   ✔️    |
| $\alpha \le \vec{a}' \vec{x} \le \beta$ | ScalarAffineFunction | Interval     |   ♻️    |
| $x_i \le \beta$                              | VariableIndex        | LessThan     |   ✔️    |
| $x_i \ge \alpha$                             | VariableIndex        | GreaterThan  |   ✔️    |
| $x_i = \beta$                                | VariableIndex        | EqualTo      |   ✔️    |
| $\alpha \le x_i \le \beta$                   | VariableIndex        | Interval     |   ✔️    |
| $A \vec{x} + b \in \mathbb{R}_{+}^{n}$       | VectorAffineFunction | Nonnegatives |   ♻️    |
| $A \vec{x} + b \in \mathbb{R}_{-}^{n}$       | VectorAffineFunction | Nonpositives |   ♻️    |
| $A \vec{x} + b = 0$                          | VectorAffineFunction | Zeros        |   ♻️    |

### Conic constraints

| Mathematical Constraint                                                                                           | MOI Function         | MOI Set                          | Status |
| ----------------------------------------------------------------------------------------------------------------- | -------------------- | -------------------------------- | :----: |
| $\left\lVert{}{A \vec{x} + b}\right\rVert{}_{2} \le \vec{c}' \vec{x} + d$                                    | VectorAffineFunction | SecondOrderCone                  |   📖    |
| $y \ge \left\lVert{}{\vec{x}}\right\rVert{}_{2}$                                                                  | VectorOfVariables    | SecondOrderCone                  |   📖    |
| $2 y z \ge \left\lVert{}{\vec{x}}\right\rVert{}_{2}^{2}; y, z \ge 0$                                              | VectorOfVariables    | RotatedSecondOrderCone           |   📖    |
| $\left( \vec{a}'_1 \vec{x} + b_1,\vec{a}'_2 \vec{x} + b_2,\vec{a}'_3 \vec{x} + b_3 \right) \in E$ | VectorAffineFunction | ExponentialCone                  |   ❌    |
| $A(\vec{x}) \in S_{+}$                                                                                            | VectorAffineFunction | PositiveSemidefiniteConeTriangle |   ❌    |
| $B(\vec{x}) \in S_{+}$                                                                                            | VectorAffineFunction | PositiveSemidefiniteConeSquare   |   ❌    |
| $\vec{x} \in S_{+}$                                                                                               | VectorOfVariables    | PositiveSemidefiniteConeTriangle |   ❌    |
| $\vec{x} \in S_{+}$                                                                                               | VectorOfVariables    | PositiveSemidefiniteConeSquare   |   ❌    |

### Quadratic constraints

| Mathematical Constraint                               | MOI Function            | MOI Set                  | Status |
| ----------------------------------------------------- | ----------------------- | ------------------------ | :----: |
| $\vec{x} Q \vec{x} + \vec{a}' \vec{x} + b \ge 0$      | ScalarQuadraticFunction | GreaterThan              |   ♻️    |
| $\vec{x} Q \vec{x} + \vec{a}' \vec{x} + b \le 0$      | ScalarQuadraticFunction | LessThan                 |   ✔️    |
| $\vec{x} Q \vec{x} + \vec{a}' \vec{x} + b = 0$        | ScalarQuadraticFunction | EqualTo                  |   ✔️    |
| Bilinear matrix inequality                            | VectorQuadraticFunction | PositiveSemidefiniteCone |   ❌    |

### Discrete and logical constraints

| Mathematical Constraint                                                              | MOI Function         | MOI Set        | Status |
| ------------------------------------------------------------------------------------ | -------------------- | -------------- | :----: |
| $x_i  \in \mathbb{Z}$                                                                | VariableIndex        | Integer        |   ✔️    |
| $x_i \in \left\lbrace{0, 1}\right\rbrace$                                            | VariableIndex        | ZeroOne        |   ✔️    |
| $x_i \in \left\lbrace{0}\right\rbrace \cup \left[{l, u}\right]$                      | VariableIndex        | Semicontinuous |   ⌛    |
| $x_i \in \left\lbrace{0}\right\rbrace \cup \left[{l, l + 1, \dots, u - 1, u}\right]$ | VariableIndex        | Semiinteger    |   ⌛    |
| [¹](#1)                                                                              | VectorOfVariables    | SOS1           |   ✔️    |
| [²](#2)                                                                              | VectorOfVariables    | SOS2           |   📖    |
| $y = 1 \implies \vec{a}' \vec{x} \in S$                                              | VectorAffineFunction | Indicator      |   📖    |//////

<a id="1">¹</a> 
At most one component of **x** can be nonzero

<a id="2">²</a>
At most two components of **x** can be nonzero, and if so they must be adjacent components

| Symbol | Meaning                            |
| :----: | ---------------------------------- |
|   ✔️    | Available                          |
|   ♻️    | Available through Bridges[³](#3)   |
|   ❌    | Unavailable                        |
|   ⌛    | Under Development (Available soon) |
|   📖    | Under Research                     |

<a id="3">³</a> 
[MOI Bridges](https://jump.dev/MathOptInterface.jl/stable/submodules/Bridges/reference/) provide equivalent constraint mapping.

<a id="4">⁴</a>
If you think this list is incomplete, consider creating an [Issue](https://github.com/psrenergy/ToQUBO.jl/issues) or opening a [Pull Request](https://github.com/psrenergy/ToQUBO.jl/pulls).

## Citing ToQUBO.jl
If you use `ToQUBO.jl` in your work, we kindly ask you to include the following citation:
```tex
@software{toqubo:2023,
  author       = {Pedro Maciel Xavier and Pedro Ripper and Tiago Andrade and Joaquim Dias Garcia and David E. Bernal Neira},
  title        = {{ToQUBO.jl}},
  month        = {feb},
  year         = {2023},
  publisher    = {Zenodo},
  version      = {v0.1.5},
  doi          = {10.5281/zenodo.7644291},
  url          = {https://doi.org/10.5281/zenodo.7644291}
}
```

<div align="center">
    <h2>PSR Quantum Optimization Toolchain</h2>
    <a href="https://github.com/psrenergy/ToQUBO.jl">
        <img width="200px" src="https://raw.githubusercontent.com/psrenergy/ToQUBO.jl/master/docs/src/assets/logo.svg" alt="ToQUBO.jl" />
    </a>
    <a href="https://github.com/psrenergy/QUBODrivers.jl">
        <img width="200px" src="https://raw.githubusercontent.com/psrenergy/QUBODrivers.jl/master/docs/src/assets/logo.svg" alt="QUBODrivers.jl" />
    </a>
    <a href="https://github.com/psrenergy/QUBOTools.jl">
        <img width="200px" src="https://raw.githubusercontent.com/psrenergy/QUBOTools.jl/main/docs/src/assets/logo.svg" alt="QUBOTools.jl" />
    </a>
</div>
