@doc raw"""
    isqubo(model::MOI.ModelLike)
    
Tells if a given model is ready to be interpreted as a QUBO model.

For it to be true, a few conditions must be met:
 1. All variables must be binary (`MOI.VariableIndex ∈ MOI.ZeroOne`)
 2. No other constraints are allowed
 3. The objective function must be of type `MOI.ScalarQuadraticFunction`, `MOI.ScalarAffineFunction` or `MOI.VariableIndex`
 4. The objective sense must be either `MOI.MIN_SENSE` or `MOI.MAX_SENSE`
""" function isqubo end

@doc raw"""
    toqubo(
        [T=Float64,]
        source::MOI.ModelLike,
        ::AbstractArchitecture;
        optimizer::Union{Nothing, Type{<:MOI.AbstractOptimizer}} = nothing
    )

Low-level interface to create a `::VirtualModel{T}` from `::MOI.ModelLike` instance.
If provided, an `::MOI.AbstractOptimizer` is attached to the model.
""" function toqubo end

@doc raw"""
    toqubo!(model::VirtualModel{T}, ::AbstractArchitecture) where {T}
""" function toqubo! end

@doc raw"""
    toqubo_sense!(model::VirtualModel, ::AbstractArchitecture) where {T}

Copies `MOI.ObjectiveSense` from `model.source_model` to `model.target_model`.
""" function toqubo_sense! end

@doc raw"""
    toqubo_variables!(model::VirtualModel{T}) where {T}
""" function toqubo_variables! end

@doc raw"""
    toqubo_variables(model::VirtualModel{T}) where {T}
""" function toqubo_variable end

@doc raw"""
    toqubo_objective!(model::VirtualModel, ::AbstractArchitecture)
""" function toqubo_objective! end

@doc raw"""
    toqubo_objective(model::VirtualModel, F::VI, ::AbstractArchitecture)
    toqubo_objective(model::VirtualModel{T}, F::SAF{T}, ::AbstractArchitecture) where {T}
    toqubo_objective(model::VirtualModel{T}, F::SQF{T}, ::AbstractArchitecture) where {T}
""" function toqubo_objective end

@doc raw"""
    toqubo_constraints!(model::VirtualModel, ::AbstractArchitecture)
""" function toqubo_constraints! end

@doc raw"""
    toqubo_constraint

Returns the pseudo-boolean function associated to a given constraint from the source model.
""" function toqubo_constraint end

@doc raw"""
    toqubo_parse!(
        model::VirtualModel{T},
        g::PBO.PBF{VI,T},
        f::MOI.AbstractFunction,
        arch::AbstractArchitectur
    ) where {T}

Parses the given MOI function `f` into PBF `g`.
""" function toqubo_parse! end

@doc raw"""
    toqubo_penalties!(model::VirtualModel, ::AbstractArchitecture)
""" function toqubo_penalties! end

@doc raw"""
""" function toqubo_penalty end

@doc raw"""
    toqubo_build!(model::VirtualModel, ::AbstractArchitecture)
""" function toqubo_build! end

@doc raw"""
    toqubo_empty!(model::VirtualModel, ::AbstractArchitecture)
""" function toqubo_empty! end