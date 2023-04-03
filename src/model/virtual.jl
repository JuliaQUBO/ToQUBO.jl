#  Virtual Variable Encoding 
abstract type Encoding end

@doc raw"""
    encode!(model::VirtualModel{T}, v::VirtualVariable{T}) where {T}

Maps newly created virtual variable `v` within the virtual model structure. It follows these steps:
 
 1. Maps `v`'s source to it in the model's `source` mapping.
 2. For every one of `v`'s targets, maps it to itself and adds a binary constraint to it.
 2. Adds `v` to the end of the model's `varvec`.  
""" function encode! end

@doc raw"""
# Variable Expansion methods:
    - Linear
    - Unary
    - Binary
    - One Hot
    - Domain Wall

# References:
 * [1] Chancellor, N. (2019). Domain wall encoding of discrete variables for quantum annealing and QAOA. _Quantum Science and Technology_, _4_(4), 045004. [{doi}](https://doi.org/10.1088/2058-9565/ab33c2)
"""
struct VirtualVariable{T}
    e::Encoding
    x::Union{VI,Nothing}             # Source variable (if there is one)
    y::Vector{VI}                    # Target variables
    ξ::PBO.PBF{VI,T}                 # Expansion function
    h::Union{PBO.PBF{VI,T},Nothing}  # Penalty function (i.e. ‖gᵢ(x)‖ₛ for g(i) ∈ S)

    function VirtualVariable{T}(
        e::Encoding,
        x::Union{VI,Nothing},
        y::Vector{VI},
        ξ::PBO.PBF{VI,T},
        h::Union{PBO.PBF{VI,T},Nothing},
    ) where {T}
        return new{T}(e, x, y, ξ, h)
    end
end

const VV{T} = VirtualVariable{T}

encoding(v::VirtualVariable)  = v.e
source(v::VirtualVariable)    = v.x
target(v::VirtualVariable)    = v.y
is_aux(v::VirtualVariable)    = isnothing(source(v))
expansion(v::VirtualVariable) = v.ξ
penaltyfn(v::VirtualVariable) = v.h

@doc raw"""
    VirtualModel{T}(optimizer::Union{Nothing, Type{<:MOI.AbstractOptimizer}} = nothing) where {T}

This Virtual Model links the final QUBO formulation to the original one, allowing variable value retrieving and other features.
"""
struct VirtualModel{T} <: MOI.AbstractOptimizer
    #  Underlying Optimizer  #
    optimizer::Union{MOI.AbstractOptimizer,Nothing}

    #  MathOptInterface Bridges  #
    bridge_model::MOIB.LazyBridgeOptimizer{PreQUBOModel{T}}

    #  Virtual Model Interface  #
    source_model::PreQUBOModel{T}
    target_model::QUBOModel{T}
    variables::Vector{VV{T}}
    source::Dict{VI,VV{T}}
    target::Dict{VI,VV{T}}

    #  PBO/PBF IR  #
    f::PBO.PBF{VI,T}          # Objective Function
    g::Dict{CI,PBO.PBF{VI,T}} # Constraint Functions
    h::Dict{VI,PBO.PBF{VI,T}} # Variable Functions
    ρ::Dict{CI,T}             # Constraint Penalties
    θ::Dict{VI,T}             # Variable Penalties
    H::PBO.PBF{VI,T}          # Final Hamiltonian

    #  Settings 
    compiler_settings::Dict{Symbol,Any}
    variable_settings::Dict{Symbol,Dict{VI,Any}}
    constraint_settings::Dict{Symbol,Dict{CI,Any}}

    function VirtualModel{T}(
        constructor::Union{Type{O},Function};
        kws...,
    ) where {T,O<:MOI.AbstractOptimizer}
        optimizer = constructor()

        return VirtualModel{T}(optimizer; kws...)
    end

    function VirtualModel{T}(
        optimizer::Union{O,Nothing} = nothing;
        kws...,
    ) where {T,O<:MOI.AbstractOptimizer}
        source_model = PreQUBOModel{T}()
        target_model = QUBOModel{T}()
        bridge_model = MOIB.full_bridge_optimizer(source_model, T)

        new{T}(
            #  Underlying Optimizer  #
            optimizer,

            #  MathOptInterface Bridges  #
            bridge_model,

            #  Virtual Model Interface 
            source_model,
            target_model,
            Vector{VV{T}}(),
            Dict{VI,VV{T}}(),
            Dict{VI,VV{T}}(),

            #  PBO/PBF IR 
            PBO.PBF{VI,T}(),          # Objective Function
            Dict{CI,PBO.PBF{VI,T}}(), # Constraint Functions
            Dict{VI,PBO.PBF{VI,T}}(), # Variable Functions
            Dict{CI,T}(),             # Constraint Penalties
            Dict{VI,T}(),             # Variable Penalties
            PBO.PBF{VI,T}(),          # Final Hamiltonian

            #  Settings 
            Dict{Symbol,Any}(),
            Dict{Symbol,Dict{VI,Any}}(),
            Dict{Symbol,Dict{CI,Any}}(),
        )
    end

end

VirtualModel(args...; kws...) = VirtualModel{Float64}(args...; kws...)

function encode!(model::VirtualModel{T}, v::VV{T}) where {T}
    if !is_aux(v)
        let x = source(v)
            model.source[x] = v
        end
    end

    for y in target(v)
        MOI.add_constraint(model.target_model, y, MOI.ZeroOne())
        model.target[y] = v
    end

    # Add variable to collection
    push!(model.variables, v)

    return v
end

@doc raw"""
    LinearEncoding

Every linear encoding ``\xi`` is of the form
```math
\xi(\mathbf{y}) = \alpha + \sum_{i = 1}^{n} \gamma_{i} y_{i}
```

""" abstract type LinearEncoding <: Encoding end

function VirtualVariable{T}(
    e::LinearEncoding,
    x::Union{VI,Nothing},
    y::Vector{VI},
    γ::Vector{T},
    α::T = zero(T),
) where {T}
    @assert (n = length(y)) == length(γ)

    ξ = α + PBO.PBF{VI,T}(y[i] => γ[i] for i = 1:n)

    return VirtualVariable{T}(e, x, y, ξ, nothing)
end

function encode!(
    model::VirtualModel{T},
    e::LinearEncoding,
    x::Union{VI,Nothing},
    γ::Vector{T},
    α::T = zero(T),
) where {T}
    n = length(γ)
    y = MOI.add_variables(model.target_model, n)
    v = VirtualVariable{T}(e, x, y, γ, α)

    return encode!(model, v)
end

@doc raw"""
    Mirror()

Mirrors binary variable ``x \in \mathbb{B}`` with a twin variable ``y \in \mathbb{B}``.
""" struct Mirror <: LinearEncoding end

function encode!(model::VirtualModel{T}, e::Mirror, x::Union{VI,Nothing}) where {T}
    return encode!(model, e, x, ones(T, 1))
end

@doc raw"""
    Linear()
""" struct Linear <: LinearEncoding end

function encode!(
    model::VirtualModel{T},
    e::Linear,
    x::Union{VI,Nothing},
    Γ::Function,
    n::Integer,
) where {T}
    γ = T[Γ(i) for i = 1:n]

    return encode!(model, e, x, γ, zero(T))
end

@doc raw"""
    Unary()

Let ``x \in [a, b] \subset \mathbb{Z}, n = b - a, \mathbf{y} \in \mathbb{B}^{n}``.

```math
x = \xi(\mathbf{y}) = a + \sum_{j = 1}^{b - a} y_{j}
```
""" struct Unary <: LinearEncoding end

function encode!(
    model::VirtualModel{T},
    e::Unary,
    x::Union{VI,Nothing},
    a::T,
    b::T,
) where {T}
    α, β = if a < b
        ceil(a), floor(b)
    else
        ceil(b), floor(a)
    end

    # assumes: β - α > 0
    M = trunc(Int, β - α)
    γ = ones(T, M)

    return encode!(model, e, x, γ, α)
end

function encode!(
    model::VirtualModel{T},
    e::Unary,
    x::Union{VI,Nothing},
    a::T,
    b::T,
    n::Integer,
) where {T}
    Γ = (b - a) / n
    γ = Γ * ones(T, n)

    return encode!(model, e, x, γ, a)
end

function encode!(
    model::VirtualModel{T},
    e::Unary,
    x::Union{VI,Nothing},
    a::T,
    b::T,
    τ::T,
) where {T}
    n = ceil(Int, (1 + abs(b - a) / 4τ))

    return encode!(model, e, x, a, b, n)
end

@doc raw"""
    Binary()

Binary Expansion within the closed interval ``[\alpha, \beta]``.

For a given variable ``x \in [\alpha, \beta]`` we approximate it by

```math    
x \approx \alpha + \frac{(\beta - \alpha)}{2^{n} - 1} \sum_{i=0}^{n-1} {2^{i}\, y_i}
```

where ``n`` is the number of bits and ``y_i \in \mathbb{B}``.
""" struct Binary <: LinearEncoding end

function encode!(
    model::VirtualModel{T},
    e::Binary,
    x::Union{VI,Nothing},
    a::T,
    b::T,
) where {T}
    α, β = if a < b
        ceil(a), floor(b)
    else
        ceil(b), floor(a)
    end

    # assumes: β - α > 0
    M = trunc(Int, β - α)
    N = ceil(Int, log2(M + 1))

    γ = if N == 0
        T[M+1/2]
    else
        T[[2^i for i = 0:N-2]; [M - 2^(N - 1) + 1]]
    end

    return encode!(model, e, x, γ, α)
end

function encode!(
    model::VirtualModel{T},
    e::Binary,
    x::Union{VI,Nothing},
    a::T,
    b::T,
    n::Integer,
) where {T}
    Γ = (b - a) / (2^n - 1)
    γ = Γ * 2 .^ collect(T, 0:n-1)

    return encode!(model, e, x, γ, a)
end

function encode!(
    model::VirtualModel{T},
    e::Binary,
    x::Union{VI,Nothing},
    a::T,
    b::T,
    τ::T,
) where {T}
    n = ceil(Int, log2(1 + abs(b - a) / 4τ))

    return encode!(model, e, x, a, b, n)
end

@doc raw"""
    Arithmetic()


""" struct Arithmetic <: LinearEncoding end

function encode!(
    model::VirtualModel{T},
    e::Arithmetic,
    x::Union{VI,Nothing},
    a::T,
    b::T,
) where {T}
    α, β = if a < b
        ceil(a), floor(b)
    else
        ceil(b), floor(a)
    end

    # assumes: β - α > 0
    M = trunc(Int, β - α)
    N = ceil(Int, (sqrt(1 + 8M) - 1) / 2)

    γ = T[[i for i = 1:N-1]; [M - N * (N - 1) / 2]]

    return encode!(model, e, x, γ, α)
end

function encode!(
    model::VirtualModel{T},
    e::Arithmetic,
    x::Union{VI,Nothing},
    a::T,
    b::T,
    n::Integer,
) where {T}
    Γ = 2 * (b - a) / (n * (n + 1))
    γ = Γ * collect(1:n)

    return encode!(model, e, x, γ, a)
end

function encode!(
    model::VirtualModel{T},
    e::Arithmetic,
    x::Union{VI,Nothing},
    a::T,
    b::T,
    τ::T,
) where {T}
    n = ceil(Int, (1 + sqrt(3 + (b - a) / 2τ)) / 2)

    return encode!(model, e, x, a, b, n)
end

@doc raw"""
    OneHot()

The one-hot encoding is a linear technique used to represent a variable
``x \in \{ \gamma_{j} \}_{j \in [n]}``.

The encoding function is combined with a constraint assuring that only
one and exactly one of the expansion's variables ``y_{j}`` is activated
at a time.

```math
\begin{array}{rl}
x = \xi(\mathbf{y}) = &  \sum_{j = 1}^{n} \gamma_{j} y_{j} \\
        \mathrm{s.t.} & \sum_{j = 1}^{n} y_{j} = 1
\end{array}
```

""" struct OneHot <: LinearEncoding end

function VirtualVariable{T}(
    e::OneHot,
    x::Union{VI,Nothing},
    y::Vector{VI},
    γ::Vector{T},
    α::T = zero(T),
) where {T}
    @assert (n = length(y)) == length(γ)

    ξ = α + PBO.PBF{VI,T}(y[i] => γ[i] for i = 1:n)
    h = (one(T) - PBO.PBF{VI,T}(y))^2

    return VirtualVariable{T}(e, x, y, ξ, h)
end

function encode!(
    model::VirtualModel{T},
    e::OneHot,
    x::Union{VI,Nothing},
    a::T,
    b::T,
) where {T}
    α, β = if a < b
        ceil(a), floor(b)
    else
        ceil(b), floor(a)
    end

    # assumes: β - α > 0
    γ = collect(T, α:β)

    return encode!(model, e, x, γ)
end

function encode!(
    model::VirtualModel{T},
    e::OneHot,
    x::Union{VI,Nothing},
    a::T,
    b::T,
    n::Integer,
) where {T}
    Γ = (b - a) / (n - 1)
    γ = a .+ Γ * collect(T, 0:n-1)

    return encode!(model, e, x, γ)
end

function encode!(
    model::VirtualModel{T},
    e::OneHot,
    x::Union{VI,Nothing},
    a::T,
    b::T,
    τ::T,
) where {T}
    n = ceil(Int, (1 + abs(b - a) / 4τ))

    return encode!(model, e, x, a, b, n)
end

@doc raw"""
    SequentialEncoding

A *sequential encoding* is one of the form

```math
\xi(\mathbf{y}) = \sum_{i = 1}^{n} \gamma_{i} \left({y_{i + 1} \circast y_{i}}\right)
```

where ``\mathbf{y} \in \mathbb{B}^{n + 1}`` and ``\circast`` is a binary operator.
""" abstract type SequentialEncoding <: Encoding end

function encode!(
    model::VirtualModel{T},
    e::SequentialEncoding,
    x::Union{VI,Nothing},
    γ::Vector{T},
    α::T = zero(T),
) where {T}
    n = length(γ)
    y = MOI.add_variables(model.target_model, n - 1)
    v = VirtualVariable{T}(e, x, y, γ, α)

    return encode!(model, v)
end

@doc raw"""
    DomainWall()

The Domain Wall[^Chancellor2019] encoding method is a sequential approach that requires only
``n - 1`` bits to represent ``n`` distinct values.

!!! table "Encoding Analysis"
    |             | bits      | linear | quadratic | ``\Delta`` |
    | :-:         | :--:      | :----: | :-------: | :--------: |
    | Domain Wall | ``n - 1`` | ``n``  |           | ``O(n)``   |

[^Chancellor2019]:
    Nicholas Chancellor, **Domain wall encoding of discrete variables for quantum annealing and QAOA**, *Quantum Science Technology 4*, 2019.
""" struct DomainWall <: SequentialEncoding end

function VirtualVariable{T}(
    e::DomainWall,
    x::Union{VI,Nothing},
    y::Vector{VI},
    γ::Vector{T},
    α::T = zero(T),
) where {T}
    @assert (n = length(y)) == length(γ) - 1

    ξ = α + PBO.PBF{VI,T}(y[i] => (γ[i] - γ[i+1]) for i = 1:n)
    h = 2 * (PBO.PBF{VI,T}(y[2:n]) - PBO.PBF{VI,T}([Set{VI}([y[i], y[i-1]]) for i = 2:n]))

    return VirtualVariable{T}(e, x, y, ξ, h)
end

function encode!(
    model::VirtualModel{T},
    e::DomainWall,
    x::Union{VI,Nothing},
    a::T,
    b::T,
) where {T}
    α, β = if a < b
        ceil(a), floor(b)
    else
        ceil(b), floor(a)
    end

    # assumes: β - α > 0
    M = trunc(Int, β - α)
    γ = α .+ collect(T, 0:M)

    return encode!(model, e, x, γ)
end

function encode!(
    model::VirtualModel{T},
    e::DomainWall,
    x::Union{VI,Nothing},
    a::T,
    b::T,
    n::Integer,
) where {T}
    Γ = (b - a) / (n - 1)
    γ = a .+ Γ * collect(T, 0:n-1)

    return encode!(model, e, x, γ)
end

@doc raw"""
    Bounded{E,T}(μ::T) where {E<:Encoding,T}

The bounded-coefficient encoding method[^Karimi2019] consists in limiting the magnitude of the
coefficients in the encoding expansion to a parameter ``\mu``.

[^Karimi2019]:
    Karimi, S. & Ronagh, P. **Practical integer-to-binary mapping for quantum annealers**. *Quantum Inf Process 18, 94* (2019). [{doi}](https://doi.org/10.1007/s11128-019-2213-x)

    Bounded{Binary,T}(μ::T) where {T}

## Rationale
Let ``x \in [a, b] \subset \mathbb{Z}`` and ``n = b - a``.

First,

```math
\begin{align*}
         2^{k - 1}  &\le \mu \\
\implies k          &=   \left\lfloor\log_{2} \mu + 1 \right\rfloor
\end{align*}
```

Since

```math
\sum_{j = 1}^{k} 2^{j - 1} = \sum_{j = 0}^{k - 1} 2^{j} = 2^{k} - 1
```

then, for ``r \in \mathbb{N}``

```math
n = 2^{k} - 1 + r \times \mu + \epsilon \implies r = \left\lfloor \frac{n - 2^{k} + 1}{\mu} \right\rfloor
```

and

```math
\epsilon = n - 2^{k} + 1 - r \times \mu
```

```math
\gamma_{j} = \left\lbrace\begin{array}{cl}
    2^{j} & \text{if } 1 \le j \le k   \\
    \mu   & \text{if } k < j < r + k   \\
    n - 2^k + 1 - r \times \mu & \text{otherwise}
\end{array}\right.
```

    Bounded{Unary,T}(μ::T) where {T}

Let ``x \in [a, b] \subset \mathbb{Z}`` and ``n = b - a``.


""" struct Bounded{E<:LinearEncoding,T} <: LinearEncoding
    μ::T

    function Bounded{E,T}(μ::T) where {E,T}
        @assert !iszero(μ)

        return new{E,T}(μ)
    end
end

function Bounded{E}(μ::T) where {E,T}
    return Bounded{E,T}(μ)
end

function encode!(
    model::VirtualModel{T},
    e::Bounded{Binary,T},
    x::Union{VI,Nothing},
    a::T,
    b::T,
) where {T}
    if a < b
        a = ceil(a)
        b = floor(b)
    else
        a = ceil(b)
        b = floor(a)
    end

    n = round(Int, b - a)
    k = floor(Int, log2(e.μ) + 1)
    m = 2^k - 1
    r = floor(Int, (n - m) / e.μ)
    ϵ = n - m - r * e.μ

    if iszero(ϵ)
        γ = T[[2^(j - 1) for j = 1:k]; [e.μ for _ = 1:r]]
    else
        γ = T[[2^(j - 1) for j = 1:k]; [e.μ for _ = 1:r]; [ϵ]]
    end

    return encode!(model, e, x, γ, a)
end

function encode!(
    model::VirtualModel{T},
    e::Bounded{Unary,T},
    x::Union{VI,Nothing},
    a::T,
    b::T,
) where {T}
    if a < b
        a = ceil(a)
        b = floor(b)
    else
        a = ceil(b)
        b = floor(a)
    end

    n = round(Int, b - a)
    k = ceil(Int, e.μ - 1)
    r = floor(Int, (n - k) / e.μ)
    ϵ = n - k + - r * e.μ

    if iszero(ϵ)
        γ = T[ones(T, k); [e.μ for _ = 1:r]]
    else
        γ = T[ones(T, k); [e.μ for _ = 1:r]; [ϵ]]
    end

    return encode!(model, e, x, γ, a)
end

function encode!(
    model::VirtualModel{T},
    e::Bounded{Arithmetic,T},
    x::Union{VI,Nothing},
    a::T,
    b::T,
) where {T}
    if a < b
        a = ceil(a)
    else
        b = floor(b)
        a = ceil(b)
        b = floor(a)
    end

    n = round(Int, b - a)
    k = floor(Int, e.μ)
    m = (k * (k + 1)) ÷ 2
    r = floor(Int, (n - m) / e.μ)
    ϵ = n - m + - r * e.μ

    if iszero(ϵ)
        γ = T[collect(T,1:k); [e.μ for _ = 1:r]]
    else
        γ = T[collect(T,1:k); [e.μ for _ = 1:r]; [ϵ]]
    end

    return encode!(model, e, x, γ, a)
end
