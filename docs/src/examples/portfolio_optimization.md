# Portfolio Optimization

For this example, we will be using the data provided for a tutorial on Portolio Optimization in the [JuMP documentation](https://jump.dev/JuMP.jl/stable/tutorials/nonlinear/portfolio/), where they provide the stock prices for three assets $\texttt{IBM}$, $\texttt{WMT}$ and $\texttt{SEHI}$.

Portfolio Optimization aims to sort out the best asset distribution that maximizes the return and minimizes the financial risk. We will be using the following approach to model this problem:
```math
\begin{array}{r l}
    \max        & \mu'x - \lambda x'Q x\\
    \text{s.t.} & 0.0 \leq x \leq 1.0 \\
                & \sum{x_i} = 1.0
\end{array}
```
where,
- ``\mu`` is the expected return value for each investment
- ``Q`` is the covariance matrix
- ``\lambda`` is a penalization

## Importing the required packages
```@example portfolio-optimization
using JuMP
using DataFrames
using Statistics
using ToQUBO
using DWaveNeal
```

## Stock prices
```@example portfolio-optimization
df = DataFrames.DataFrame(
    [
        93.043     51.826    1.063
        84.585     52.823    0.938
        111.453    56.477    1.000
        99.525     49.805    0.938
        95.819     50.287    1.438
        114.708    51.521    1.700
        111.515    51.531    2.540
        113.211    48.664    2.390
        104.942    55.744    3.120
        99.827     47.916    2.980
        91.607     49.438    1.900
        107.937    51.336    1.750
        115.590    55.081    1.800
    ],
    [:IBM, :WMT, :SEHI],
)
```

## Solving


```@example portfolio-optimization
function solve(df::DataFrame, λ::Float64 = 10.; optimizer = DWaveNeal.Optimizer)
    return solve(identity, df, λ; optimizer)
end

function solve(config!::Function, df::DataFrame, λ::Float64 = 10.; optimizer = DWaveNeal.Optimizer)
    r = diff(Matrix(df); dims = 1) ./ Matrix(df[1:end-1, :])

    # Expected montly return value for each stock
    μ = vec(Statistics.mean(r; dims = 1))

    # Covariance matrix
    Σ = Statistics.cov(r)

    model = Model(() -> ToQUBO.Optimizer(optimizer))

    @variable(model, 0.0 <= x[1:3] <= 1.0)
    @objective(model, Max, μ'x - λ*x'*Σ*x)
    @constraint(model, sum(x) == 1)

    config!(model)

    optimize!(model)

    return value.(x)
end
```


```@example portfolio-optimization
solve(df) do model
    JuMP.set_silent(model)
end
```