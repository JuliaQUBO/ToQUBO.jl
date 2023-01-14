mutable struct QUBOModel{T} <: MOI.ModelLike
    of::SQF{T}
    os::MOI.OptimizationSense
    vi::Vector{VI}

    function QUBOModel{T}() where {T}
        return new{T}(SQF{T}(SQT{T}[], SAT{T}[], zero(T)), MOI.MIN_SENSE, VI[])
    end
end

QUBOModel() = QUBOTools{Float64}()

# -*- :: MOI :: -*- #
function MOI.add_variable(model::QUBOModel)
    vi, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())

    return vi
end

function MOI.add_constrained_variable(model::QUBOModel, ::MOI.ZeroOne)
    i  = MOI.get(model, MOI.NumberOfVariables()) + 1
    vi = MOI.VariableIndex(i)
    ci = MOI.ConstraintIndex{VI,MOI.ZeroOne}(i)

    push!(model.vi, VI(i))

    return (vi, ci)
end

function MOI.is_empty(model::QUBOModel)
    return isempty(model.vi) &&
           isempty(model.of.quadratic_terms) &&
           isempty(model.of.affine_terms) &&
           iszero(model.of.constant)
end

function MOI.empty!(model::QUBOModel{T}) where {T}
    model.of = SQF{T}(SQT{T}[], SAT{T}[], zero(T))
    model.os = MOI.MIN_SENSE

    empty!(model.vi)

    return nothing
end

# -*- :: Support :: -*-  #
MOI.supports(::QUBOModel{T}, ::MOI.ObjectiveFunction{SQF{T}}) where {T}              = true
MOI.supports_constraint(::QUBOModel{T}, ::Type{VI}, ::Type{MOI.ZeroOne}) where {T}   = true
MOI.supports_add_constrained_variable(::QUBOModel{T}, ::Type{MOI.ZeroOne}) where {T} = true

function MOI.add_constraint(::QUBOModel, vi::VI, ::MOI.ZeroOne)
    return MOI.ConstraintIndex{VI,MOI.ZeroOne}(vi.value)
end

# -*- :: get + set :: -*- #
function MOI.get(model::QUBOModel, ::MOI.ObjectiveSense)
    return model.os
end

function MOI.set(model::QUBOModel, ::MOI.ObjectiveSense, os::MOI.OptimizationSense)
    model.os = os

    return nothing
end

function MOI.get(model::QUBOModel{T}, ::MOI.ObjectiveFunction{SQF{T}}) where {T}
    return model.of
end

function MOI.set(model::QUBOModel{T}, ::MOI.ObjectiveFunction{VI}, vi::VI) where {T}
    model.of = SQF{T}(SQT{T}[], SAT{T}[SAT{T}(one(T), vi)], zero(T))

    return nothing
end

function MOI.set(model::QUBOModel{T}, ::MOI.ObjectiveFunction{SAF{T}}, f::SAF{T}) where {T}
    model.of = SQF{T}(SQT{T}[], copy(f.terms), f.constant)

    return nothing
end

function MOI.set(model::QUBOModel{T}, ::MOI.ObjectiveFunction{SQF{T}}, f::SQF{T}) where {T}
    model.of = SQF{T}(copy(f.quadratic_terms), copy(f.affine_terms), f.constant)

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
    return [MOI.ConstraintIndex{VI,MOI.ZeroOne}(vi.value) for vi in model.vi]
end

function MOI.get(model::QUBOModel, ::MOI.ListOfVariableIndices)
    return model.vi
end

MOI.get(::QUBOModel, ::MOI.ConstraintFunction, ci::MOI.ConstraintIndex{VI,MOI.ZeroOne}) =
    VI(ci.value)

MOI.get(::QUBOModel, ::MOI.ConstraintSet, ::MOI.ConstraintIndex{VI,MOI.ZeroOne}) =
    MOI.ZeroOne()

MOI.get(::QUBOModel, ::MOI.VariableName, vi::VI) = "x[$(vi.value)]"

function MOI.get(::QUBOModel{T}, ::MOI.VariablePrimalStart, ::VI) where {T}
    return nothing
end

MOI.supports(::QUBOModel, ::MOI.VariablePrimalStart, ::MOI.VariableIndex) = true

function MOI.get(model::QUBOModel, ::MOI.NumberOfVariables)
    return length(model.vi)
end
