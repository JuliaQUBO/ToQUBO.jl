mutable struct VirtualQUBOModelAttributes{T}
    tol::T
    
    function VirtualQUBOModelAttributes{T}(; tol::T = 1e-6) where T
        new{T}(tol)
    end
end

function Base.empty!(attrs::VirtualQUBOModelAttributes{T}) where T
    attrs.tol = convert(T, 1e-6)
end

@doc raw"""
    VirtualQUBOModel{T}(optimizer::Union{Nothing, Type{<:MOI.AbstractOptimizer}} = nothing) where {T}

This QUBO Virtual Model links the final QUBO formulation to the original one, allowing variable value retrieving and other features.
"""
struct VirtualQUBOModel{T} <: VM.AbstractVirtualModel{T}
    # - Underlying Optimizer -
    optimizer::Union{Nothing, MOI.AbstractOptimizer}

    # -*- Virtual Model Interface -*-
    source_model::PreQUBOModel{T}
    target_model::QUBOModel{T}
    variables::Vector{VM.VV{<:Any, T}}
    source::Dict{VI, VM.VV{<:Any, T}}
    target::Dict{VI, VM.VV{<:Any, T}}

    # -*- PBO/PBF IR -*-
    f::PBO.PBF{VI, T}           # Objective Function
    g::Dict{CI, PBO.PBF{VI, T}} # Problem Constraints
    h::Dict{VI, PBO.PBF{VI, T}} # Variable Encoding Constraints
    ρ::Dict{Union{CI, VI}, T}   # Penalties

    # -*- Attributes -*-
    attrs::VirtualQUBOModelAttributes{T}
    flags::Dict{Symbol, Bool}

    function VirtualQUBOModel{T}(Optimizer::Union{Type{<:MOI.AbstractOptimizer}, Function, Nothing} = nothing) where T
        new{T}(
            # - Underlying Optimizer -
            isnothing(Optimizer) ? nothing : Optimizer(),    
        
            # -*- Virtual Model Interface -*-
            PreQUBOModel{T}(),
            QUBOModel{T}(),
            VM.VV{<:Any, T}[],
            Dict{VI, VM.VV{<:Any, T}}(),
            Dict{VI, VM.VV{<:Any, T}}(),
            
            # -*- PBO/PBF IR -*-
            PBO.PBF{VI, T}(),
            Dict{CI, PBO.PBF{VI, T}}(),
            Dict{VI, PBO.PBF{VI, T}}(),
            Dict{Union{CI, VI}, T}(),
            
            VirtualQUBOModelAttributes{T}(),
            Dict{Symbol, Bool}(),
        )
    end

    function VirtualQUBOModel(Optimizer::Union{Type{<:MOI.AbstractOptimizer}, Function, Nothing} = nothing)
        VirtualQUBOModel{Float64}(Optimizer)
    end
end

MOI.get(model::VirtualQUBOModel, ::VM.Source) = model.source
MOI.get(model::VirtualQUBOModel, ::VM.Source, x::VI) = model.source[x]
MOI.set(model::VirtualQUBOModel{T}, ::VM.Source, x::VI, v::VM.VV{<:Any, T}) where T = (model.source[x] = v)

MOI.get(model::VirtualQUBOModel, ::VM.Target) = model.target
MOI.get(model::VirtualQUBOModel, ::VM.Target, y::VI) = model.target[y]
MOI.set(model::VirtualQUBOModel{T}, ::VM.Target, y::VI, v::VM.VV{<:Any, T}) where T = (model.target[y] = v)

MOI.get(model::VirtualQUBOModel, ::VM.Variables)   = model.variables
MOI.get(model::VirtualQUBOModel, ::VM.SourceModel) = model.source_model
MOI.get(model::VirtualQUBOModel, ::VM.TargetModel) = model.target_model