# Portfolio Optimization

In this example, we will be exploring an optimization model for asset distribution where the expected return is maximized while mitigating the financial risk.
The following approach was inspired by a [JuMP tutorial](https://jump.dev/JuMP.jl/stable/tutorials/nonlinear/portfolio/), where monthly stock prices for three assets are provided, namely `IBM`, `WMT` and `SEHI`.

The modelling presented below aggregates the risk measurement ``\mathbf{x}' \Sigma \mathbf{x}`` as a penalty term to the objective function, thus yielding

```math
\begin{array}{rll}
    \max_{\mathbf{x}} & \mathbf{\mu}'\mathbf{x} - \lambda\, \mathbf{x}' \Sigma \mathbf{x}             \\
    \textrm{s.t.}     & 0 \le {x}_{i} \le 1                                               & \forall i \\
                      & \sum_{i} {x}_{i} = 1
\end{array}
```

where ``\mu_{i} = \mathbb{E}[r_{i}]`` is the expected return value for each investment ``i``; ``\Sigma`` is the covariance matrix and ``\lambda`` is the risk-aversion penalty factor.

## Stock prices
```@example portfolio-optimization
using DataFrames
using Statistics

assets = [:IBM, :WMT, :SEHI]

df = DataFrames.DataFrame(
    [
         93.043    51.826    1.063
         84.585    52.823    0.938
        111.453    56.477    1.000
         99.525    49.805    0.938
         95.819    50.287    1.438
        114.708    51.521    1.700
        111.515    51.531    2.540
        113.211    48.664    2.390
        104.942    55.744    3.120
         99.827    47.916    2.980
         91.607    49.438    1.900
        107.937    51.336    1.750
        115.590    55.081    1.800
    ],
    assets,
)
```

## Solving
```@example portfolio-optimization
using JuMP
using ToQUBO
using DWaveNeal

function solve(
    config!::Function,
    df::DataFrame,
    λ::Float64 = 10.;
    optimizer = DWaveNeal.Optimizer
)
    # Number of assets
    n = size(df, 2)

    # Relative monthly return
    r = diff(Matrix(df); dims = 1) ./ Matrix(df[1:end-1, :])

    # Expected monthly return value for each stock
    μ = vec(Statistics.mean(r; dims = 1))

    # Covariance matrix
    Σ = Statistics.cov(r)

    # Build model
    model = Model(() -> ToQUBO.Optimizer(optimizer))

    @variable(model, 0 <= x[1:n] <= 1)
    @objective(model, Max, μ'x - λ * x' * Σ * x)
    @constraint(model, sum(x) == 1)

    config!(model)

    optimize!(model)

    return value.(x)
end

function solve(df::DataFrame, λ::Float64 = 10.; optimizer = DWaveNeal.Optimizer)
    return solve(identity, df, λ; optimizer)
end
```

```@example portfolio-optimization
solve(df) do model
    JuMP.set_silent(model)
    JuMP.set_optimizer_attribute(model, "num_reads", 2_000)
end
```

## Penalty Analysis
To finish our discussion, we are going to sketch some graphics to help our reasoning on how the penalty factor ``\lambda`` affects our investments.

```@example portfolio-optimization
using Plots; pythonplot()

Λ = collect(0.:5.:50.)
X = Dict{Symbol,Vector{Float64}}(tag => [] for tag in assets)

for λ = Λ
    x = solve(df, λ)

    for (i, tag) in enumerate(assets)
        push!(X[tag], x[i])
    end
end

plt = plot(;
    title="Portfolio Optimization",
    xlabel=raw"penalty factor ($\lambda$)",
    ylabel=raw"investment share ($x$)",
)

for tag in assets
    plot!(plt, Λ, X[tag]; label=string(tag))
end

plt
```