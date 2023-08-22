mutable struct QUBOModel{T} <: MOI.ModelLike
    objective_function::SQF{T}
    objective_sense::MOI.OptimizationSense
    variables::Vector{VI}

    function QUBOModel{T}() where {T}
        return new{T}(SQF{T}(SQT{T}[], SAT{T}[], zero(T)), MOI.MIN_SENSE, VI[])
    end
end

# MOI Wrapper
function MOI.add_variable(model::QUBOModel)
    vi, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())

    return vi
end

function MOI.add_constrained_variable(model::QUBOModel, ::MOI.ZeroOne)
    i  = MOI.get(model, MOI.NumberOfVariables()) + 1
    vi = MOI.VariableIndex(i)
    ci = MOI.ConstraintIndex{VI,MOI.ZeroOne}(i)

    push!(model.variables, VI(i))

    return (vi, ci)
end

function MOI.is_empty(model::QUBOModel)
    return isempty(model.variables) &&
           isempty(model.objective_function.quadratic_terms) &&
           isempty(model.objective_function.affine_terms) &&
           iszero(model.objective_function.constant)
end

function MOI.empty!(model::QUBOModel{T}) where {T}
    model.objective_function = SQF{T}(SQT{T}[], SAT{T}[], zero(T))
    model.objective_sense = MOI.MIN_SENSE

    empty!(model.variables)

    return nothing
end

# Support
MOI.supports(::QUBOModel{T}, ::MOI.ObjectiveFunction{SQF{T}}) where {T}              = true
MOI.supports_constraint(::QUBOModel{T}, ::Type{VI}, ::Type{MOI.ZeroOne}) where {T}   = true
MOI.supports_add_constrained_variable(::QUBOModel{T}, ::Type{MOI.ZeroOne}) where {T} = true

function MOI.add_constraint(::QUBOModel, vi::VI, ::MOI.ZeroOne)
    return MOI.ConstraintIndex{VI,MOI.ZeroOne}(vi.value)
end

# get & set
function MOI.get(model::QUBOModel, ::MOI.ObjectiveSense)
    return model.objective_sense
end

function MOI.set(
    model::QUBOModel,
    ::MOI.ObjectiveSense,
    objective_sense::MOI.OptimizationSense,
)
    model.objective_sense = objective_sense

    return nothing
end

function MOI.get(model::QUBOModel{T}, ::MOI.ObjectiveFunction{SQF{T}}) where {T}
    return model.objective_function
end

function MOI.set(model::QUBOModel{T}, ::MOI.ObjectiveFunction{VI}, vi::VI) where {T}
    model.objective_function = SQF{T}(SQT{T}[], SAT{T}[SAT{T}(one(T), vi)], zero(T))

    return nothing
end

function MOI.set(model::QUBOModel{T}, ::MOI.ObjectiveFunction{SAF{T}}, f::SAF{T}) where {T}
    model.objective_function = SQF{T}(SQT{T}[], copy(f.terms), f.constant)

    return nothing
end

function MOI.set(model::QUBOModel{T}, ::MOI.ObjectiveFunction{SQF{T}}, f::SQF{T}) where {T}
    model.objective_function = SQF{T}(
        copy(f.quadratic_terms),
        copy(f.affine_terms),
        f.constant
    )

    return nothing
end

MOI.get(::QUBOModel{T}, ::MOI.ObjectiveFunctionType) where {T} = SQF{T}

function MOI.get(model::QUBOModel, ::MOI.ListOfConstraintTypesPresent)
    if MOI.is_empty(model)
        return []
    else
        return [(VI, MOI.ZeroOne)]
    end
end

function MOI.get(
    model::QUBOModel,
    ::MOI.ListOfConstraintIndices{MOI.VariableIndex,MOI.ZeroOne},
)
    return [MOI.ConstraintIndex{VI,MOI.ZeroOne}(vi.value) for vi in model.variables]
end

function MOI.get(model::QUBOModel, ::MOI.ListOfVariableIndices)
    return model.variables
end

function MOI.get(
    ::QUBOModel,
    ::MOI.ConstraintFunction,
    ci::MOI.ConstraintIndex{VI,MOI.ZeroOne},
)
    return VI(ci.value)
end

function MOI.get(::QUBOModel, ::MOI.ConstraintSet, ::MOI.ConstraintIndex{VI,MOI.ZeroOne})
    return MOI.ZeroOne()
end

function MOI.get(::QUBOModel, ::MOI.VariableName, vi::VI)
    return "x[$(vi.value)]"
end

function MOI.get(::QUBOModel{T}, ::MOI.VariablePrimalStart, ::VI) where {T}
    return nothing
end

MOI.supports(::QUBOModel, ::MOI.VariablePrimalStart, ::MOI.VariableIndex) = true

function MOI.get(model::QUBOModel, ::MOI.NumberOfVariables)
    return length(model.variables)
end
