using .VirtualMapping: AbstractVirtualModel, SourceModel, TargetModel
using .VirtualMapping: VirtualVariable, Variables, Source, Target

mutable struct VirtualQUBOModelAttributes{T}
    tol::T
    
    function VirtualQUBOModelAttributes{T}(; tol::T = 1e-6) where T
        new{T}(tol)
    end
end

@doc raw"""
    VirtualQUBOModel{T}(optimizer::Union{Nothing, Type{<:MOI.AbstractOptimizer}} = nothing) where {T}

This QUBO Virtual Model links the final QUBO formulation to the original one, allowing variable value retrieving and other features.
"""
struct VirtualQUBOModel{T} <: AbstractVirtualModel{T}
    # - Underlying Optimizer -
    optimizer::Union{Nothing, MOI.AbstractOptimizer}

    # -*- Virtual Model Interface -*-
    source_model::PreQUBOModel{T}
    target_model::QUBOModel{T}

    source::Dict{VI, VirtualVariable{<:Any, T}}
    target::Dict{VI, VirtualVariable{<:Any, T}}
    variables::Vector{VirtualVariable{<:Any, T}}

    # -*- PBO/PBF IR -*-
    f::PBO.PBF{VI, T}           # Objective Function
    g::Dict{CI, PBO.PBF{VI, T}} # Problem Constraints
    h::Dict{VI, PBO.PBF{VI, T}} # Variable Encoding Constraints

    # -*- Attributes -*-
    attrs::VirtualQUBOModelAttributes{T}

    function VirtualQUBOModel{T}(Optimizer::Union{Type{<:MOI.AbstractOptimizer}, Function, Nothing} = nothing) where T
        new{T}(
            # - Underlying Optimizer -
            isnothing(Optimizer) ? nothing : Optimizer(),    
        
            # -*- Virtual Model Interface -*-
            PreQUBOModel{T}(),
            QUBOModel{T}(),

            Dict{VI, VirtualVariable{<:Any, T}}(),
            Dict{VI, VirtualVariable{<:Any, T}}(),
            VirtualVariable{<:Any, T}[],
            
            # -*- PBO/PBF IR -*-
            PBO.PBF{VI, T}(),
            Dict{CI, PBO.PBF{VI, T}}(),
            Dict{VI, PBO.PBF{VI, T}}(),
            
            VirtualQUBOModelAttributes{T}(),
        )
    end

    function VirtualQUBOModel(Optimizer::Union{Type{<:MOI.AbstractOptimizer}, Function, Nothing} = nothing)
        VirtualQUBOModel{Float64}(Optimizer)
    end
end

MOI.get(model::VirtualQUBOModel, ::Source, x::VI) = model.source[x]
MOI.set(model::VirtualQUBOModel{T}, ::Source, x::VI, v::VirtualVariable{<:Any, T}) where T = (model.source[x] = v)
MOI.get(model::VirtualQUBOModel, ::Target, y::VI) = model.target[y]
MOI.set(model::VirtualQUBOModel{T}, ::Target, y::VI, v::VirtualVariable{<:Any, T}) where T = (model.target[y] = v)
MOI.get(model::VirtualQUBOModel, ::Variables) = model.variables
MOI.get(model::VirtualQUBOModel, ::SourceModel) = model.source_model
MOI.get(model::VirtualQUBOModel, ::TargetModel) = model.target_model