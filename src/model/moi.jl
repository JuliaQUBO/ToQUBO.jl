# :: Input Model Support ::

# :: QUBO Error ::
include("../lib/error.jl")

# -*- Objective Support -*-
function supported_objective(model::MOI.ModelLike)
    F = MOI.get(model, MOI.ObjectiveFunctionType())
    if !__qubo_supported_objective(F)
        error("Objective functions of type ", F, " are not implemented")
    end
    return
end

__qubo_supported_objective(::Type) = false
__qubo_supported_objective(::Type{<: VI}) = true
__qubo_supported_objective(::Type{<: SAF{T}}) where {T} = true
__qubo_supported_objective(::Type{<: SQF{T}}) where {T} = true

# -*- Constraint Support -*-
function supported_constraints(model::MOI.ModelLike)
    for (F, S) in MOI.get(model, MOI.ListOfConstraints())
        if !__qubo_supported_constraint(F, S)
            error(
                "Constraints of function ",
                F,
                " in the Set ",
                S,
                " are not implemented",
            )
        end
    end
    return
end

__qubo_supported_constraint(::Type, ::Type) = false
__qubo_supported_constraint(::Type{<: VI}, ::Type{<: ZO}) = true
__qubo_supported_constraint(::Type{<: SAF{T}}, ::Type{<: EQ{T}}) where T = true
__qubo_supported_constraint(::Type{<: SAF{T}}, ::Type{<: LT{T}}) where T = true
__qubo_supported_constraint(::Type{<: SAF{T}}, ::Type{<: GT{T}}) where T = true

# -*- Optimize! -*-
function MOI.optimize!(model::QUBOModel)
    if model.sampler === missing
        error("QUBO Model 'sampler' is missing.")
    end

    x, Q, c = qubo(model.ℍ)

    sample!(model.sampler, x, Q, c)
end

# -*- Get: VariablePrimal -*-
function MOI.get(model::QUBOModel{T}, ::MOI.VariablePrimal, xᵢ::MOI.VariableIndex) where {T}
    return sum(
        (MOI.get(model.model, MOI.VariablePrimal(), yᵢⱼ) * cᵢⱼ for (yᵢⱼ, cᵢⱼ) in model.source[xᵢ]);
        init=zero(T)
    )
end

# -*- The copy_to interface -*-
function MOI.copy_to(sampler::AbstractAnnealer, model::MOI.ModelLike)
    if isqubo(model)
        MOI.copy_to(sampler, toqubo(model))
    else
        throw(QUBOError("Model is not QUBO."))
    end
end

# -*- Variable Ordering -*-
Base.isless(u::MOI.VariableIndex, v::MOI.VariableIndex) = isless(u.value, v.value)

function MOI.optimize!(annealer::AbstractAnnealer, model::MOI.ModelLike)
    qubo_model = toqubo(model)

    
    

end