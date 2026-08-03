# ToQUBO.jl 🟥🟩🟪🟦

<div align="center">
    <a href="/docs/src/assets/">
        <img src="/docs/src/assets/logo.svg" width=400px alt="ToQUBO.jl" />
    </a>
    <br>
    <a href="https://arxiv.org/abs/2307.02577">
        <img src="https://img.shields.io/badge/arXiv-2307.02577-b31b1b.svg" alt="arXiv"/>
    </a>
    <a href="https://doi.org/10.1080/10556788.2026.2702926">
        <img src="https://img.shields.io/badge/DOI-10.1080%2F10556788.2026.2702926-blue.svg" alt="Journal article DOI"/>
    </a>
    <a href="https://codecov.io/gh/JuliaQUBO/ToQUBO.jl">
        <img src="https://codecov.io/gh/JuliaQUBO/ToQUBO.jl/branch/main/graph/badge.svg" alt="Coverage"/>
    </a>
    <a href="https://github.com/JuliaQUBO/ToQUBO.jl/actions/workflows/ci.yml">
        <img src="https://github.com/JuliaQUBO/ToQUBO.jl/actions/workflows/ci.yml/badge.svg?branch=main" alt="CI" />
    </a>
    <a href="https://www.youtube.com/watch?v=OTmzlTbqdNo">
        <img src="https://img.shields.io/badge/JuliaCon-2022-9558b2" alt="JuliaCon 2022">
    </a>
    <a href="https://JuliaQUBO.github.io/ToQUBO.jl/dev">
        <img src="https://img.shields.io/badge/docs-dev-blue.svg" alt="Docs">
    </a>
    <a href="https://doi.org/10.5281/zenodo.21763525">
        <img src="https://zenodo.org/badge/DOI/10.5281/zenodo.21763525.svg" alt="ToQUBO.jl Zenodo DOI">
    </a>
</div>

## Introduction
ToQUBO.jl is a Julia package to reformulate general optimization problems into [QUBO](https://en.wikipedia.org/wiki/Quadratic_unconstrained_binary_optimization) (Quadratic Unconstrained Binary Optimization) instances. This tool aims to convert a broad range of [JuMP](https://github.com/jump-dev/JuMP.jl) problems for straightforward application in many physics and physics-inspired solution methods whose normal optimization form is equivalent to the QUBO. These methods include quantum annealing, quantum gate-circuit optimization algorithms (Quantum Optimization Alternating Ansatz, Variational Quantum Eigensolver), other hardware-accelerated platforms, such as Coherent Ising Machines and Simulated Bifurcation Machines, and more traditional methods such as simulated annealing. During execution, ToQUBO.jl encodes both discrete and continuous variables, maps constraints, and computes their penalties, performing a few model optimization steps along the process. A simple interface to connect various annealers and samplers as QUBO solvers is defined in [QUBODrivers.jl](https://github.com/JuliaQUBO/QUBODrivers.jl).

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
| $\vec{x} Q \vec{x} + \vec{a}' \vec{x} + b \ge 0$      | ScalarQuadraticFunction | GreaterThan              |   ✔️    |
| $\vec{x} Q \vec{x} + \vec{a}' \vec{x} + b \le 0$      | ScalarQuadraticFunction | LessThan                 |   ✔️    |
| $\vec{x} Q \vec{x} + \vec{a}' \vec{x} + b = 0$        | ScalarQuadraticFunction | EqualTo                  |   ✔️    |
| Bilinear matrix inequality                            | VectorQuadraticFunction | PositiveSemidefiniteCone |   ❌    |

### Discrete and logical constraints

| Mathematical Constraint                                                              | MOI Function         | MOI Set        | Status |
| ------------------------------------------------------------------------------------ | -------------------- | -------------- | :----: |
| $x_i  \in \mathbb{Z}$                                                                | VariableIndex        | Integer        |   ✔️    |
| $x_i \in \left\lbrace{0, 1}\right\rbrace$                                            | VariableIndex        | ZeroOne        |   ✔️    |
| $x_i \in \left\lbrace{0}\right\rbrace \cup \left[{l, u}\right]$                      | VariableIndex        | Semicontinuous |   ✔️    |
| $x_i \in \left\lbrace{0}\right\rbrace \cup \left[{l, l + 1, \dots, u - 1, u}\right]$ | VariableIndex        | Semiinteger    |   ✔️    |
| [¹](#1)                                                                              | VectorOfVariables    | SOS1           |   ✔️    |
| [²](#2)                                                                              | VectorOfVariables    | SOS2           |   📖    |
| $y = 1 \implies \vec{a}' \vec{x} \in S$                                              | VectorAffineFunction | Indicator      |   ✔️    |
| $y = 1 \implies \vec{x}' Q \vec{x} + \vec{a}' \vec{x} \in S$                         | VectorQuadraticFunction | Indicator   |   ✔️    |

<a id="1">¹</a> 
At most one component of **x** can be nonzero

<a id="2">²</a>
At most two components of **x** can be nonzero, and if so they must be adjacent components

Indicator constraints are supported for activation on zero or one when the
inner constraint is scalar affine or quadratic with an `EqualTo`, `LessThan`,
`GreaterThan`, or `Interval` bound set. Generalized disjunctive programming (GDP)
models should use [DisjunctiveProgramming.jl](https://github.com/infiniteopt/DisjunctiveProgramming.jl)'s
`Indicator()` reformulation, which emits JuMP/MOI indicator constraints that
ToQUBO compiles directly; no separate `DisjunctiveToQUBO.jl` runtime package is
required. ToQUBO's maintained GDP support is this indicator-constraint
compilation path, not a separate GDP-specific API or runtime dependency on
`DisjunctiveProgramming.jl`. The historical
[`pedromxavier/DisjunctiveToQUBO.jl`](https://github.com/pedromxavier/DisjunctiveToQUBO.jl)
repository should be treated as a paper artifact, not as part of ToQUBO's
runtime surface or CI. The associated paper is Xavier, Pedro Maciel, Pedro
Ripper, Joshua Pulsipher, Joaquim Dias Garcia, Nelson Maculan, and David E.
Bernal Neira. "Disjunctive programming meets QUBO." In *Computer Aided Chemical
Engineering*, vol. 53, pp. 3433-3438. Elsevier, 2024.
[`ScienceDirect`](https://www.sciencedirect.com/science/chapter/bookseries/pii/B9780443288241505731).

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
If you think this list is incomplete, consider creating an [Issue](https://github.com/JuliaQUBO/ToQUBO.jl/issues) or opening a [Pull Request](https://github.com/JuliaQUBO/ToQUBO.jl/pulls).

## Citing ToQUBO.jl
<!-- citation-policy:start -->
For general use of `ToQUBO.jl` and the broader `QUBO.jl` ecosystem, cite the
[published journal article](https://doi.org/10.1080/10556788.2026.2702926). The
earlier [arXiv preprint](https://arxiv.org/abs/2307.02577) remains available,
but the journal article is the version of record.

For a software citation, use the
[Zenodo concept DOI](https://doi.org/10.5281/zenodo.21763525). The concept DOI
is the evergreen identifier for the actively maintained archive and is the DOI
recorded in `CITATION.cff`. When reproducibility requires an exact release,
cite the matching version DOI instead; the archive for `v0.6.1` is
[10.5281/zenodo.21763526](https://doi.org/10.5281/zenodo.21763526).

The BibTeX entries below pin that exact release. Replace the `@software` entry's
`doi` and `url` with the concept DOI when an evergreen software citation is
preferred:

```bibtex
@article{xavier2026qubojl,
  author       = {Maciel Xavier, Pedro and Ripper, Pedro and Andrade, Tiago and Dias Garcia, Joaquim and Maculan, Nelson and Bernal Neira, David E.},
  title        = {{QUBO.jl: a Julia ecosystem for quadratic unconstrained binary optimization}},
  journal      = {Optimization Methods and Software},
  year         = {2026},
  pages        = {1--24},
  doi          = {10.1080/10556788.2026.2702926},
  url          = {https://doi.org/10.1080/10556788.2026.2702926}
}

@software{toqubo:2026,
  author       = {Maciel Xavier, Pedro and Ripper, Pedro and Andrade, Tiago and Dias Garcia, Joaquim and Bernal Neira, David E.},
  title        = {{ToQUBO.jl}},
  year         = {2026},
  publisher    = {Zenodo},
  version      = {v0.6.1},
  doi          = {10.5281/zenodo.21763526},
  url          = {https://doi.org/10.5281/zenodo.21763526},
  note         = {Evergreen concept DOI: 10.5281/zenodo.21763525}
}
```

The [historical concept DOI](https://doi.org/10.5281/zenodo.6387591) covers
releases through `v0.1.6` and remains part of the project's provenance; it is
not the identifier for current releases. Machine-readable metadata is in
[`CITATION.cff`](https://github.com/JuliaQUBO/ToQUBO.jl/blob/main/CITATION.cff),
with BibTeX in
[`CITATION.bib`](https://github.com/JuliaQUBO/ToQUBO.jl/blob/main/CITATION.bib).
<!-- citation-policy:end -->

---

<div align="center">
    <a href="https://github.com/JuliaQUBO/QUBO.jl">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/JuliaQUBO/QUBO.jl/refs/heads/main/docs/src/assets/logo-collaboration-dark.png">
      <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/JuliaQUBO/QUBO.jl/refs/heads/main/docs/src/assets/logo-collaboration-light.png">
      <img alt="QUBO.jl Collaboration" src="https://raw.githubusercontent.com/JuliaQUBO/QUBO.jl/refs/heads/main/docs/src/assets/logo-collaboration-light.png">
    </picture> 
    </a>
</div>
