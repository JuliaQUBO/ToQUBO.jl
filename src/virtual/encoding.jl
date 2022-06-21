@doc raw"""
    encode!(model::AbstractVirtualModel{T}, v::VirtualVariable{T}) where {T}

Maps newly created virtual variable `v` within the virtual model structure. It follows these steps:
 
 1. Maps `v`'s source to it in the model's `source` mapping.
 2. For every one of `v`'s targets, maps it to itself and adds a binary constraint to it.
 2. Adds `v` to the end of the model's `varvec`.  
"""
function encode! end

function encode!(model::AbstractVirtualModel{T}, v::VV{<:Any, T}) where T
    if !isslack(v)
        x = source(v)
        MOI.set(model, Source(), x, v)
    end

    for y in target(v)
        MOI.add_constraint(MOI.get(model, TargetModel()), y, MOI.ZeroOne())
        MOI.set(model, Target(), y, v)
    end

    # Add variable to collection
    push!(MOI.get(model, Variables()), v)

    return v
end

function encode!(E::Type{<:Encoding}, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, γ::Vector{T}, α::T=zero(T)) where T
    n = length(γ)
    y = MOI.add_variables(MOI.get(model, TargetModel()), n)
    v = VirtualVariable{E, T}(x, y, γ, α)

    encode!(model, v)
end

function encode!(E::Type{<:Linear}, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, Γ::Function, n::Integer) where T
    encode!(E, model, x, T[Γ(i) for i = 1:n])
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
    @warn "The computation method for number of bits is still unverified in this case!"
    n = ceil(Int, log2(1 + abs(b - a) / 4τ))
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

    encode!(E, model, x, T[[2^(i - 1) for i = 1:N-1];[M - 2^(N-1) + 1]], α)
end

function encode!(E::Type{<:Binary}, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, a::T, b::T, n::Integer) where T
    Γ = (b - a) / (2^n - 1)
    encode!(E, model, x, Γ * T[[2^(i - 1) for i = 1:n]], a)
end


function encode!(E::Type{<:Binary}, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, a::T, b::T, τ::T) where T
    n = ceil(Int, log2(1 + abs(b - a) / 4τ))
    encode!(E, model, x, a, b, n)
end