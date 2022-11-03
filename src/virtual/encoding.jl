abstract type LinearEncoding <: Encoding end

@doc raw"""
""" struct Mirror <: LinearEncoding end
@doc raw"""
""" struct Linear <: LinearEncoding end
@doc raw"""
""" struct Unary <: LinearEncoding end

@doc raw"""
Binary Expansion within the closed interval ``[\alpha, \beta]``.

For a given variable ``x \in [\alpha, \beta]`` we approximate it by

```math    
x \approx \alpha + \frac{(\beta - \alpha)}{2^{n} - 1} \sum_{i=0}^{n-1} {2^{i}\, y_i}
```

where ``n`` is the number of bits and ``y_i \in \mathbb{B}``.
""" struct Binary <: LinearEncoding end

function VirtualVariable{E, T}(
        x::Union{VI, Nothing},
        y::Vector{VI},
        γ::Vector{T},
        α::T = zero(T),
    ) where {E <: LinearEncoding, T}
    @assert (n = length(y)) == length(γ)
    
    VirtualVariable{E, T}(
        x,
        y,
        (α + PBO.PBF{VI, T}(y[i] => γ[i] for i = 1:n)),
        nothing,
    )
end

@doc raw"""
""" struct OneHot <: LinearEncoding end

function VirtualVariable{OneHot, T}(
        x::Union{VI, Nothing},
        y::Vector{VI},
        γ::Vector{T},
        α::T = zero(T),
    ) where T
    @assert (n = length(y)) == length(γ)

    VirtualVariable{OneHot, T}(
        x,
        y,
        (α + PBO.PBF{VI, T}(y[i] => γ[i] for i = 1:n)),
        (one(T) - PBO.PBF{VI, T}(y)) ^ 2,
    )
end

abstract type SequentialEncoding <: Encoding end

struct DomainWall <: SequentialEncoding end

function VirtualVariable{DomainWall, T}(
        x::Union{VI, Nothing},
        y::Vector{VI},
        γ::Vector{T},
        α::T = zero(T),
    ) where T
    @assert (n = length(y)) == length(γ) - 1

    ξ = PBO.PBF{VI, T}(y[i] => (γ[i] - γ[i+1]) for i = 1:n)
    h = 2.0 * (PBO.PBF{VI, T}(y[2:n]) - PBO.PBF{VI, T}([Set{VI}([y[i], y[i-1]]) for i = 2:n]))

    VirtualVariable{DomainWall, T}(x, y, ξ, h)
end

abstract type ConstantEncoding <: Encoding end

function VirtualVariable{ConstantEncoding, T}(x::Union{VI, Nothing}, β::T) where {T}
    VirtualVariable{ConstantEncoding, T}(
        x,
        VI[],
        PBO.PBF{VI, T}(β),
        nothing,
    )
end

@doc raw"""
    encode!(model::AbstractVirtualModel{T}, v::VirtualVariable{T}) where {T}

Maps newly created virtual variable `v` within the virtual model structure. It follows these steps:
 
 1. Maps `v`'s source to it in the model's `source` mapping.
 2. For every one of `v`'s targets, maps it to itself and adds a binary constraint to it.
 2. Adds `v` to the end of the model's `varvec`.  
"""
function encode! end

function encode!(model::AbstractVirtualModel{T}, v::VirtualVariable{<:Any, T}) where T
    if !isslack(v)
        let x = source(v)
            MOI.set(model, Source(), x, v)
        end
    end

    for y in target(v)
        MOI.add_constraint(MOI.get(model, TargetModel()), y, MOI.ZeroOne())
        MOI.set(model, Target(), y, v)
    end

    # Add variable to collection
    push!(MOI.get(model, Variables()), v)

    return v
end

function encode!(E::Type{<:LinearEncoding}, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, γ::Vector{T}, α::T=zero(T)) where T
    n = length(γ)
    y = MOI.add_variables(MOI.get(model, TargetModel()), n)
    v = VirtualVariable{E, T}(x, y, γ, α)

    encode!(model, v)
end

function encode!(E::Type{<:Linear}, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, Γ::Function, n::Integer) where T
    encode!(E, model, x, T[Γ(i) for i = 1:n], zero(T))
end

function encode!(E::Type{<:Mirror}, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}) where T
    encode!(E, model, x, ones(T, 1))
end

function encode!(E::Type{<:Unary}, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, a::T, b::T) where T
    α, β = if a < b
        ceil(a), floor(b)
    else
        ceil(b), floor(a)
    end

    # assumes: β - α > 0
    M = trunc(Int, β - α)

    encode!(E, model, x, ones(T, M), α)
end

function encode!(E::Type{<:Unary}, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, a::T, b::T, n::Integer) where T
    Γ = (b - a) / n
    encode!(E, model, x, Γ * ones(T, n), a) 
end

function encode!(E::Type{<:Unary}, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, a::T, b::T, τ::T) where T
    @warn "The computation method the for number of bits is still unverified in this case!"
    n = ceil(Int, (1 + abs(b - a) / 4τ))
    encode!(E, model, x, a, b, n) 
end

function encode!(E::Type{<:Binary}, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, a::T, b::T) where T
    α, β = if a < b
        ceil(a), floor(b)
    else
        ceil(b), floor(a)
    end

    # assumes: β - α > 0
    M = trunc(Int, β - α)
    N = ceil(Int, log2(M + 1))

    γ = if N == 0
        T[M + 1/2]
    else
        T[[2^i for i = 0:N-2];[M - 2^(N-1) + 1]]
    end

    encode!(E, model, x, γ, α)
end

function encode!(E::Type{<:Binary}, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, a::T, b::T, n::Integer) where T
    Γ = (b - a) / (2^n - 1)
    encode!(E, model, x, Γ * 2 .^ collect(T, 0:n-1), a)
end


function encode!(E::Type{<:Binary}, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, a::T, b::T, τ::T) where T
    n = ceil(Int, log2(1 + abs(b - a) / 4τ))
    encode!(E, model, x, a, b, n)
end

function encode!(E::Type{<:OneHot}, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, a::T, b::T) where T
    α, β = if a < b
        ceil(a), floor(b)
    else
        ceil(b), floor(a)
    end

    # assumes: β - α > 0
    encode!(E, model, x, collect(T, α:β), zero(T))
end

function encode!(E::Type{<:OneHot}, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, a::T, b::T, n::Integer) where T
    Γ = (b - a) / (n - 1)
    encode!(E, model, x, a .+ Γ * collect(T, 0:n-1), zero(T))
end

function encode!(E::Type{<:OneHot}, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, a::T, b::T, τ::T) where T
    @warn "The computation method for the number of bits is still unverified in this case!"
    n = ceil(Int, (1 + abs(b - a) / 4τ))
    encode!(E, model, x, a, b, n) 
end


function encode!(E::Type{<:SequentialEncoding}, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, γ::Vector{T}, α::T=zero(T)) where T
    n = length(γ)
    y = MOI.add_variables(MOI.get(model, TargetModel()), n - 1)
    v = VirtualVariable{E, T}(x, y, γ, α)

    encode!(model, v)
end

function encode!(E::Type{<:DomainWall}, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, a::T, b::T) where T
    α, β = if a < b
        ceil(a), floor(b)
    else
        ceil(b), floor(a)
    end

    # assumes: β - α > 0
    M = trunc(Int, β - α)

    encode!(E, model, x, α .+ T[i for i = 0:M], zero(T))
end

function encode!(E::Type{<:DomainWall}, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, a::T, b::T, n::Integer) where T
    Γ = (b - a) / (n - 1)
    encode!(E, model, x, a .+ Γ * collect(T, 0:n-1), zero(T))
end