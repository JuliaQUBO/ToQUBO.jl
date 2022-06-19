@doc raw"""
    encode!(model::AbstractVirtualModel{T}, v::VirtualVariable{T}) where {T}

Maps newly created virtual variable `v` within the virtual model structure. It follows these steps:
 
 1. Maps `v`'s source to it in the model's `source` mapping.
 2. For every one of `v`'s targets, maps it to itself and adds a binary constraint to it.
 2. Adds `v` to the end of the model's `varvec`.  
"""
function encode! end

function encode!(model::AbstractVirtualModel{T}, v::VirtualVariable{<:Any, T}) where T
    x = source(v)::Union{VI, Nothing}

    if x !== nothing # not a slack variable
        MOI.set(model, Source(), x, v)
    end

    for y in target(v)
        MOI.add_constraint(MOI.get(model, TargetModel()), y, MOI.ZeroOne())
        MOI.set(model, Target(), y, v)
    end

    # Add variable to collection
    push!(MOI.get(model, Variables()), v)
end

function encode!(E::LinearEncoding, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, γ::Vector{T}) where T
    n = length(γ)
    y = MOI.add_variables(MOI.get(model, TargetModel()), n)
    v = VirtualVariable{E, T}(x, y, γ)

    encode!(model, v)
end

function encode!(E::Linear, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, Γ::Function, n::Integer) where T
    encode!(E, model, x, T[Γ(i) for i = 1:n])
end

function encode!(E::Unary, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, a::T, b::T) where T
    α, β = if a < b
        ceil(T, a), floor(T, b)
    else
        ceil(T, b), floor(T, a)
    end

    M = trunc(Int, β - α)

    encode!(E, model, x, ones(T, M), α)
end

function encode!(E::Unary, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, a::T, b::T, n::Integer) where T
    Γ = (b - a) / n
    encode!(E, model, x, Γ * ones(T, n), a) 
end

function encode!(E::Unary, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, a::T, b::T, τ::T) where T
    @warn "The computation method for number of bits is still unverified in this case!"
    n = ceil(Int, log2(1 + abs(b - a) / 4τ))
    encode!(E, model, x, a, b, n) 
end

function encode!(E::Binary, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, a::T, b::T) where T
    α, β = if a < b
        ceil(T, a), floor(T, b)
    else
        ceil(T, b), floor(T, a)
    end

    M = trunc(Int, β - α)
    N = ceil(Int, log2(M + 1))

    encode!(E, model, x, T[[2^(i - 1) for i = 1:N-1];[M - 2^(N-1) + 1]], α)
end

function encode!(E::Binary, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, a::T, b::T, n::Integer) where T
    Γ = (b - a) / (2^n - 1)
    encode!(E, model, x, Γ * T[[2^(i - 1) for i = 1:n]], a)
end


function encode!(E::Binary, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, a::T, b::T, τ::T) where T
    n = ceil(Int, log2(1 + abs(b - a) / 4τ))
    encode!(E, model, x, a, b, n)
end

function encode!(E::OneHot, model::AbstractVirtualModel{T}, x::Union{VI, Nothing}, γ::Vector{T}) where T
    n = length(γ)
    y = MOI.add_variables(MOI.get(model, TargetModel()), n)
    v = VirtualVariable{E, T}(x, y, γ)

    encode!(model, v)
end