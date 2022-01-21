# -*- QUBO Validation -*-
@doc raw"""
    isqubo(T::Type{<: Any}, model::MOI.ModelLike)

Tells if `model` is ready as QUBO Model. A few conditions must be met:
    1. All variables must be binary (VariableIndex-in-ZeroOne)
    2. No other constraints are allowed
    3. The objective function must be either ScalarQuadratic, ScalarAffine or VariableIndex
"""

function isqubo(T::Type{<: Any}, model::MOI.ModelLike)
    F = MOI.get(model, MOI.ObjectiveFunctionType()) 
    
    if !(F === SQF{T} || F === SAF{T} || F === VI)
        return false
    end

    # List of Variables
    v = Set{VI}(MOI.get(model, MOI.ListOfVariableIndices()))

    for (F, S) in MOI.get(model, MOI.ListOfConstraints())
        if !(F === VI && S === ZO)
            # Non VariableIndex-in-ZeroOne Constraint
            return false
        else
            for cᵢ in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
                vᵢ = MOI.get(model, MOI.ConstraintFunction(), cᵢ)
                
                # Account for variable as binary
                delete!(v, vᵢ)
            end

            if !isempty(v)
                # Some variable is not covered by binary constraints
                return false
            end
        end
    end

    return true
end

function isqubo(model::MOI.ModelLike)
    return isqubo(Float64, model)
end

isqubo(::Model) = true
isqubo(::QUBOModel) = true

# -*- toqubo: MOI.ModelLike -> QUBO.Model -*-
function toqubo(T::Type{<: Any}, model::MOI.ModelLike)
    qubo_model = Model{T}()

    # -*- Copy To: PreQUBOModel + Trigger Bridges -*-
    MOI.copy_to(qubo_model.preq_model, model)

    return qubo_model
end

function toqubo(model::MOI.ModelLike)
    return toqubo(Float64, model)
end