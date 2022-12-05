@doc raw"""
    abstract type AbstractVirtualModel{T} <: MOI.AbstractOptimizer end
"""
abstract type AbstractVirtualModel{T} <: MOI.AbstractOptimizer end

# -*- Virtual Variable Encoding -*-
abstract type Encoding end

@doc raw"""
    encode!(model::AbstractVirtualModel{T}, v::VirtualVariable{T}) where {T}

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
struct VirtualVariable{T,E<:Encoding}
    x::Union{VI,Nothing}             # Source variable (if there is one)
    y::Vector{VI}                    # Target variables
    ξ::PBO.PBF{VI,T}                 # Expansion function
    h::Union{PBO.PBF{VI,T},Nothing}  # Penalty function (i.e. ‖gᵢ(x)‖ₛ for g(i) ∈ S)

    function VirtualVariable{T,E}(
        x::Union{VI,Nothing},
        y::Vector{VI},
        ξ::PBO.PBF{VI,T},
        h::Union{PBO.PBF{VI,T},Nothing},
    ) where {T,E<:Encoding}
        return new{T,E}(x, y, ξ, h)
    end
end

# -*- Variable Information -*-
source(v::VirtualVariable)    = v.x
target(v::VirtualVariable)    = v.y
is_aux(v::VirtualVariable)    = isnothing(source(v))
expansion(v::VirtualVariable) = v.ξ
penaltyfn(v::VirtualVariable) = v.h

# ~*~ Alias ~*~
const VV{T,E} = VirtualVariable{T,E}

function encode!(model::AbstractVirtualModel{T}, v::VV{T}) where {T}
    if !is_aux(v)
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

abstract type LinearEncoding <: Encoding end

function VirtualVariable{T,E}(
    x::Union{VI,Nothing},
    y::Vector{VI},
    γ::Vector{T},
    α::T = zero(T),
) where {T,E<:LinearEncoding}
    @assert (n = length(y)) == length(γ)

    ξ = α + PBO.PBF{VI,T}(y[i] => γ[i] for i = 1:n)

    return VirtualVariable{T,E}(x, y, ξ, nothing)
end

function encode!(
    ::E,
    model::AbstractVirtualModel{T},
    x::Union{VI,Nothing},
    γ::Vector{T},
    α::T = zero(T),
) where {T,E<:LinearEncoding}
    n = length(γ)
    y = MOI.add_variables(MOI.get(model, TargetModel()), n)
    v = VirtualVariable{T,E}(x, y, γ, α)

    return encode!(model, v)
end

@doc raw"""
""" struct Mirror <: LinearEncoding end

function encode!(e::Mirror, model::AbstractVirtualModel{T}, x::Union{VI,Nothing}) where {T}
    return encode!(e, model, x, ones(T, 1))
end

@doc raw"""
""" struct Linear <: LinearEncoding end

function encode!(
    e::E,
    model::AbstractVirtualModel{T},
    x::Union{VI,Nothing},
    Γ::Function,
    n::Integer,
) where {T,E<:Linear}
    γ = T[Γ(i) for i = 1:n]

    return encode!(e, model, x, γ, zero(T))
end

@doc raw"""
""" struct Unary <: LinearEncoding end

function encode!(
    e::E,
    model::AbstractVirtualModel{T},
    x::Union{VI,Nothing},
    a::T,
    b::T,
) where {T,E<:Unary}
    α, β = if a < b
        ceil(a), floor(b)
    else
        ceil(b), floor(a)
    end

    # assumes: β - α > 0
    M = trunc(Int, β - α)
    γ = ones(T, M)

    return encode!(e, model, x, γ, α)
end

function encode!(
    e::E,
    model::AbstractVirtualModel{T},
    x::Union{VI,Nothing},
    a::T,
    b::T,
    n::Integer,
) where {T,E<:Unary}
    Γ = (b - a) / n
    γ = Γ * ones(T, n)

    return encode!(e, model, x, γ, a)
end

function encode!(
    e::E,
    model::AbstractVirtualModel{T},
    x::Union{VI,Nothing},
    a::T,
    b::T,
    τ::T,
) where {T,E<:Unary}
    n = ceil(Int, (1 + abs(b - a) / 4τ))

    return encode!(e, model, x, a, b, n)
end

@doc raw"""
Binary Expansion within the closed interval ``[\alpha, \beta]``.

For a given variable ``x \in [\alpha, \beta]`` we approximate it by

```math    
x \approx \alpha + \frac{(\beta - \alpha)}{2^{n} - 1} \sum_{i=0}^{n-1} {2^{i}\, y_i}
```

where ``n`` is the number of bits and ``y_i \in \mathbb{B}``.
""" struct Binary <: LinearEncoding end

function encode!(
    e::E,
    model::AbstractVirtualModel{T},
    x::Union{VI,Nothing},
    a::T,
    b::T,
) where {T,E<:Binary}
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

    return encode!(e, model, x, γ, α)
end

function encode!(
    e::E,
    model::AbstractVirtualModel{T},
    x::Union{VI,Nothing},
    a::T,
    b::T,
    n::Integer,
) where {T,E<:Binary}
    Γ = (b - a) / (2^n - 1)
    γ = Γ * 2 .^ collect(T, 0:n-1)

    return encode!(e, model, x, γ, a)
end

function encode!(
    e::E,
    model::AbstractVirtualModel{T},
    x::Union{VI,Nothing},
    a::T,
    b::T,
    τ::T,
) where {T,E<:Binary}
    n = ceil(Int, log2(1 + abs(b - a) / 4τ))

    return encode!(e, model, x, a, b, n)
end

@doc raw"""
""" struct Arithmetic <: LinearEncoding end

function encode!(
    e::E,
    model::AbstractVirtualModel{T},
    x::Union{VI,Nothing},
    a::T,
    b::T,
) where {T,E<:Arithmetic}
    α, β = if a < b
        ceil(a), floor(b)
    else
        ceil(b), floor(a)
    end

    # assumes: β - α > 0
    M = trunc(Int, β - α)
    N = ceil(Int, (sqrt(1 + 8M) - 1) / 2)

    γ = T[[i for i = 1:N-1]; [M - N * (N - 1) / 2]]

    return encode!(e, model, x, γ, α)
end

function encode!(
    e::E,
    model::AbstractVirtualModel{T},
    x::Union{VI,Nothing},
    a::T,
    b::T,
    n::Integer,
) where {T,E<:Arithmetic}
    Γ = 2 * (b - a) / (n * (n + 1))
    γ = Γ * collect(1:n)

    return encode!(e, model, x, γ, a)
end

function encode!(
    e::E,
    model::AbstractVirtualModel{T},
    x::Union{VI,Nothing},
    a::T,
    b::T,
    τ::T,
) where {T,E<:Arithmetic}
    n = ceil(Int, (1 + sqrt(3 + (b - a) / 2τ)) / 2)

    return encode!(e, model, x, a, b, n)
end

@doc raw"""
""" struct OneHot <: LinearEncoding end

function VirtualVariable{T,E}(
    x::Union{VI,Nothing},
    y::Vector{VI},
    γ::Vector{T},
    α::T = zero(T),
) where {T,E<:OneHot}
    @assert (n = length(y)) == length(γ)

    ξ = α + PBO.PBF{VI,T}(y[i] => γ[i] for i = 1:n)
    h = (one(T) - PBO.PBF{VI,T}(y))^2

    return VirtualVariable{T,E}(x, y, ξ, h)
end

function encode!(
    e::E,
    model::AbstractVirtualModel{T},
    x::Union{VI,Nothing},
    a::T,
    b::T,
) where {T,E<:OneHot}
    α, β = if a < b
        ceil(a), floor(b)
    else
        ceil(b), floor(a)
    end

    # assumes: β - α > 0
    γ = collect(T, α:β)

    return encode!(e, model, x, γ)
end

function encode!(
    e::E,
    model::AbstractVirtualModel{T},
    x::Union{VI,Nothing},
    a::T,
    b::T,
    n::Integer,
) where {T,E<:OneHot}
    Γ = (b - a) / (n - 1)
    γ = a .+ Γ * collect(T, 0:n-1)

    return encode!(e, model, x, γ)
end

function encode!(
    e::E,
    model::AbstractVirtualModel{T},
    x::Union{VI,Nothing},
    a::T,
    b::T,
    τ::T,
) where {T,E<:OneHot}
    n = ceil(Int, (1 + abs(b - a) / 4τ))

    return encode!(e, model, x, a, b, n)
end

abstract type SequentialEncoding <: Encoding end

function encode!(
    ::E,
    model::AbstractVirtualModel{T},
    x::Union{VI,Nothing},
    γ::Vector{T},
    α::T = zero(T),
) where {T,E<:SequentialEncoding}
    n = length(γ)
    y = MOI.add_variables(MOI.get(model, TargetModel()), n - 1)
    v = VirtualVariable{T,E}(x, y, γ, α)

    return encode!(model, v)
end

struct DomainWall <: SequentialEncoding end

function VirtualVariable{T,E}(
    x::Union{VI,Nothing},
    y::Vector{VI},
    γ::Vector{T},
    α::T = zero(T),
) where {T,E<:DomainWall}
    @assert (n = length(y)) == length(γ) - 1

    ξ = α + PBO.PBF{VI,T}(y[i] => (γ[i] - γ[i+1]) for i = 1:n)
    h = 2 * (PBO.PBF{VI,T}(y[2:n]) - PBO.PBF{VI,T}([Set{VI}([y[i], y[i-1]]) for i = 2:n]))

    return VirtualVariable{T,E}(x, y, ξ, h)
end

function encode!(
    e::E,
    model::AbstractVirtualModel{T},
    x::Union{VI,Nothing},
    a::T,
    b::T,
) where {T,E<:DomainWall}
    α, β = if a < b
        ceil(a), floor(b)
    else
        ceil(b), floor(a)
    end

    # assumes: β - α > 0
    M = trunc(Int, β - α)
    γ = α .+ collect(T, 0:M)

    return encode!(e, model, x, γ)
end

function encode!(
    e::E,
    model::AbstractVirtualModel{T},
    x::Union{VI,Nothing},
    a::T,
    b::T,
    n::Integer,
) where {T,E<:DomainWall}
    Γ = (b - a) / (n - 1)
    γ = a .+ Γ * collect(T, 0:n-1)

    return encode!(e, model, x, γ)
end

mutable struct VirtualQUBOModelSettings{T}
    atol::Dict{Union{VI,Nothing},T}
    bits::Dict{Union{VI,Nothing},Int}
    encoding::Dict{Union{CI,VI,Nothing},Encoding}

    function VirtualQUBOModelSettings{T}(;
        atol::T            = 1E-2,
        bits::Integer      = 3,
        encoding::Encoding = Binary(),
    ) where {T}
        return new{T}(
            Dict{Union{VI,Nothing},T}(nothing => atol),
            Dict{Union{VI,Nothing},Int}(nothing => bits),
            Dict{Union{VI,Nothing},Encoding}(nothing => encoding),
        )
    end
end

@doc raw"""
    VirtualQUBOModel{T}(optimizer::Union{Nothing, Type{<:MOI.AbstractOptimizer}} = nothing) where {T}

This QUBO Virtual Model links the final QUBO formulation to the original one, allowing variable value retrieving and other features.
"""
struct VirtualQUBOModel{T} <: AbstractVirtualModel{T}
    # -*- Underlying Optimizer -*- #
    optimizer::Union{MOI.AbstractOptimizer,Nothing}
    
    # -*- MathOptInterface Bridges -*- #
    bridge_model::MOIB.LazyBridgeOptimizer{PreQUBOModel{T}}
    
    # -*- Virtual Model Interface -*- #
    source_model::PreQUBOModel{T}
    target_model::QUBOModel{T}
    variables::Vector{VV{T}}
    source::Dict{VI,VV{T}}
    target::Dict{VI,VV{T}}

    # -*- PBO/PBF IR -*- #
    f::PBO.PBF{VI,T}          # Objective Function
    g::Dict{CI,PBO.PBF{VI,T}} # Constraint Functions
    h::Dict{VI,PBO.PBF{VI,T}} # Variable Functions
    ρ::Dict{CI,T}             # Constraint Penalties
    θ::Dict{VI,T}             # Variable Penalties
    H::PBO.PBF{VI,T}          # Final Hamiltonian

    # -*- Settings -*-
    settings::VirtualQUBOModelSettings{T}

    function VirtualQUBOModel{T}(
        constructor::Union{Type{O},Function};
        kws...,
    ) where {T,O<:MOI.AbstractOptimizer}
        optimizer = constructor()

        return VirtualQUBOModel{T}(optimizer; kws...)
    end

    function VirtualQUBOModel{T}(
        optimizer::Union{O,Nothing} = nothing;
        kws...,
    ) where {T,O<:MOI.AbstractOptimizer}
        source_model = PreQUBOModel{T}()
        target_model = QUBOModel{T}()
        bridge_model = MOIB.full_bridge_optimizer(source_model, T)

        new{T}(
            # -*- Underlying Optimizer -*- #
            optimizer,

            # -*- MathOptInterface Bridges -*- #
            bridge_model,

            # -*- Virtual Model Interface -*-
            source_model,
            target_model,
            Vector{VV{T}}(),
            Dict{VI,VV{T}}(),
            Dict{VI,VV{T}}(),

            # -*- PBO/PBF IR -*-
            PBO.PBF{VI,T}(),          # Objective Function
            Dict{CI,PBO.PBF{VI,T}}(), # Constraint Functions
            Dict{VI,PBO.PBF{VI,T}}(), # Variable Functions
            Dict{CI,T}(),             # Constraint Penalties
            Dict{VI,T}(),             # Variable Penalties
            PBO.PBF{VI,T}(),          # Final Hamiltonian

            # -*- Settings -*-
            VirtualQUBOModelSettings{T}(; kws...),
        )
    end

    VirtualQUBOModel(args...; kws...) = VirtualQUBOModel{Float64}(args...; kws...)
end

QUBOTools.backend(model::VirtualQUBOModel) = QUBOTools.backend(model.target_model)

struct Source <: MOI.AbstractModelAttribute end
function MOI.get(::AbstractVirtualModel, ::Source) end
function MOI.get(::AbstractVirtualModel, ::Source, ::VI) end
function MOI.set(::AbstractVirtualModel, ::Source, ::VI, ::VV) end

struct Target <: MOI.AbstractModelAttribute end
function MOI.get(::AbstractVirtualModel, ::Target) end
function MOI.get(::AbstractVirtualModel, ::Target, ::VI) end
function MOI.set(::AbstractVirtualModel, ::Target, ::VI, ::VV) end

struct Variables <: MOI.AbstractModelAttribute end
function MOI.get(::AbstractVirtualModel, ::Variables) end

struct SourceModel <: MOI.AbstractModelAttribute end
function MOI.get(::AbstractVirtualModel, ::SourceModel) end

struct TargetModel <: MOI.AbstractModelAttribute end
function MOI.get(::AbstractVirtualModel, ::TargetModel) end

function MOI.is_empty(model::AbstractVirtualModel)
    return all([
        MOI.is_empty(MOI.get(model, SourceModel())),
        MOI.is_empty(MOI.get(model, TargetModel())),
    ])
end

function MOI.empty!(model::AbstractVirtualModel)
    MOI.empty!(MOI.get(model, SourceModel()))
    MOI.empty!(MOI.get(model, TargetModel()))
    empty!(MOI.get(model, Variables()))

    return nothing
end

function MOI.get(
    model::AbstractVirtualModel,
    attr::Union{
        MOI.ListOfConstraintAttributesSet,
        MOI.ListOfConstraintIndices,
        MOI.ListOfConstraintTypesPresent,
        MOI.ListOfModelAttributesSet,
        MOI.ListOfVariableAttributesSet,
        MOI.ListOfVariableIndices,
        MOI.NumberOfConstraints,
        MOI.NumberOfVariables,
        MOI.Name,
        MOI.ObjectiveFunction,
        MOI.ObjectiveFunctionType,
        MOI.ObjectiveSense,
    },
)

    return MOI.get(MOI.get(model, SourceModel()), attr)
end

function MOI.get(
    model::AbstractVirtualModel,
    attr::Union{MOI.ConstraintFunction,MOI.ConstraintSet},
    ci::MOI.ConstraintIndex,
)

    return MOI.get(MOI.get(model, SourceModel()), attr, ci)
end

function MOI.set(
    model::AbstractVirtualModel,
    attr::Union{MOI.ObjectiveFunction,MOI.ObjectiveSense},
    value::Any,
)

    return MOI.get(MOI.get(model, SourceModel()), attr, value)
end

function MOI.get(model::AbstractVirtualModel, attr::MOI.VariableName, x::VI)
    return MOI.get(MOI.get(model, SourceModel()), attr, x)
end

MOI.get(model::VirtualQUBOModel, ::Source)        = model.source
MOI.get(model::VirtualQUBOModel, ::Source, x::VI) = model.source[x]

function MOI.set(model::VirtualQUBOModel{T}, ::Source, x::VI, v::VV{T}) where {T}
    model.source[x] = v
end

MOI.get(model::VirtualQUBOModel, ::Target)        = model.target
MOI.get(model::VirtualQUBOModel, ::Target, y::VI) = model.target[y]

function MOI.set(model::VirtualQUBOModel{T}, ::Target, y::VI, v::VV{T}) where {T}
    model.target[y] = v
end

MOI.get(model::VirtualQUBOModel, ::Variables)   = model.variables
MOI.get(model::VirtualQUBOModel, ::SourceModel) = model.source_model
MOI.get(model::VirtualQUBOModel, ::TargetModel) = model.target_model

function Base.show(io::IO, model::AbstractVirtualModel)
    print(
        io,
        """
        Virtual Model
        with source:
        $(MOI.get(model, SourceModel()))
        with target:
        $(MOI.get(model, TargetModel()))
        """,
    )
end

function MOI.add_variable(model::VirtualQUBOModel)
    source_model = MOI.get(model, SourceModel())

    return MOI.add_variable(source_model)
end

function MOI.add_constraint(
    model::VirtualQUBOModel,
    f::MOI.AbstractFunction,
    s::MOI.AbstractSet,
)
    source_model = MOI.get(model, SourceModel())
    
    return MOI.add_constraint(source_model, f, s)
end

function MOI.set(model::VirtualQUBOModel, os::MOI.ObjectiveSense, s::MOI.OptimizationSense)
    source_model = MOI.get(model, SourceModel())

    MOI.set(source_model, os, s)
end

function MOI.set(model::VirtualQUBOModel, of::MOI.ObjectiveFunction, f::MOI.AbstractFunction)
    source_model = MOI.get(model, SourceModel())

    MOI.set(source_model, of, f)
end
