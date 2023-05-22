@doc raw"""
    isqubo(model::MOI.ModelLike)
    
Tells if a given model is ready to be interpreted as a QUBO model.

For it to be true, a few conditions must be met:
 1. All variables must be binary (`MOI.VariableIndex ∈ MOI.ZeroOne`)
 2. No other constraints are allowed
 3. The objective function must be of type `MOI.ScalarQuadraticFunction`, `MOI.ScalarAffineFunction` or `MOI.VariableIndex`
 4. The objective sense must be either `MOI.MIN_SENSE` or `MOI.MAX_SENSE`
"""
function isqubo end

@doc raw"""
    toqubo(
        [T=Float64,]
        source::MOI.ModelLike,
        ::AbstractArchitecture;
        optimizer::Union{Nothing, Type{<:MOI.AbstractOptimizer}} = nothing
    )

Low-level interface to create a `::VirtualModel{T}` from `::MOI.ModelLike` instance.
If provided, an `::MOI.AbstractOptimizer` is attached to the model.
"""
function toqubo end

@doc raw"""
    toqubo!(model::VirtualModel{T}, ::AbstractArchitecture) where {T}
"""
function toqubo! end

@doc raw"""
    setup!(model::VirtualModel, ::AbstractArchitecture)


"""
function setup! end

@doc raw"""
    sense!(model::VirtualModel, ::AbstractArchitecture)

Copies `MOI.ObjectiveSense` from `model.source_model` to `model.target_model`.
"""
function sense! end

@doc raw"""
    variables!(model::VirtualModel{T}) where {T}
"""
function variables! end

@doc raw"""
    variable!(model::VirtualModel{T}) where {T}
"""
function variable! end

@doc raw"""
    objective!(model::VirtualModel, ::AbstractArchitecture)
"""
function objective! end

@doc raw"""
    objective(model::VirtualModel, F::VI, ::AbstractArchitecture)
    objective(model::VirtualModel{T}, F::SAF{T}, ::AbstractArchitecture) where {T}
    objective(model::VirtualModel{T}, F::SQF{T}, ::AbstractArchitecture) where {T}
"""
function objective end

@doc raw"""
    constraints!(model::VirtualModel, ::AbstractArchitecture)
"""
function constraints! end

@doc raw"""
    constraint

Returns the pseudo-boolean function associated to a given constraint from the source model.
"""
function constraint end

@doc raw"""
"""
function _parse end

@doc raw"""
    parse!(
        model::VirtualModel{T},
        g::PBO.PBF{VI,T},
        f::MOI.AbstractFunction,
        arch::AbstractArchitecture
    ) where {T}

Parses the given MOI function `f` into PBF `g`.
"""
function parse! end

@doc raw"""
    penalties!(model::VirtualModel, arch::AbstractArchitecture)
"""
function penalties! end

@doc raw"""
"""
function penalty end

@doc raw"""
    build!(model::VirtualModel, arch::AbstractArchitecture)
"""
function build! end

@doc raw"""
    quadratize!(model::VirtualModel, arch::AbstractArchitecture)

Quadratizes the objective function from a model.
"""
function quadratize! end

@doc raw"""
    _empty!(model::VirtualModel, arch::AbstractArchitecture)

"""
function _empty! end

@doc raw"""
    _copy!(model::VirtualModel, arch::AbstractArchitecture)

"""
function _copy! end
