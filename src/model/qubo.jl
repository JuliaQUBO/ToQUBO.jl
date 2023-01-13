mutable struct QUBOModel{T} <: MOI.ModelLike
    model::QUBOTools.Model{VI,T,Int}

    function QUBOModel{T}() where {T}
        model = QUBOTools.Model{VI,T,Int}(
            sense  = QUBOTools.Sense(:min),
            domain = QUBOTools.Domain(:bool),
        )

        return new{T}(model)
    end
end

QUBOModel(args...; kw...) = QUBOTools{Float64}(args...; kw...)

QUBOTools.backend(model::QUBOModel) = model.model

# -*- :: MOI :: -*- #
function MOI.add_variable(model::QUBOModel)
    v, _ = MOI.add_constrained_variable(model, MOI.ZeroOne())

    return v
end

function MOI.add_constrained_variable(model::QUBOModel, ::MOI.ZeroOne)
    i = QUBOTools.domain_size(model) + 1
    v = MOI.VariableIndex(i)
    c = MOI.ConstraintIndex{VI,MOI.ZeroOne}(v.value)

    push!(QUBOTools.variable_map(model), v => i)
    push!(QUBOTools.variable_inv(model), i => v)

    return (v, c)
end

MOI.is_empty(model::QUBOModel) = isempty(model.model)

function MOI.empty!(model::QUBOModel{T}) where {T}
    model.model = QUBOTools.Model{VI,T,Int}(
        sense  = QUBOTools.Sense(:min),
        domain = QUBOTools.Domain(:bool),
    )

    return nothing
end

# -*- :: Support :: -*-  #
MOI.supports(::QUBOModel{T}, ::MOI.ObjectiveFunction{SQF{T}}) where {T}              = true
MOI.supports_constraint(::QUBOModel{T}, ::Type{VI}, ::Type{MOI.ZeroOne}) where {T}   = true
MOI.supports_add_constrained_variable(::QUBOModel{T}, ::Type{MOI.ZeroOne}) where {T} = true

function MOI.add_constraint(::QUBOModel, vi::VI, ::MOI.ZeroOne)
    MOI.ConstraintIndex{VI,MOI.ZeroOne}(vi.value)
end

# -*- :: get + set :: -*- #
function MOI.get(model::QUBOModel, ::MOI.ObjectiveSense)
    sense = QUBOTools.sense(model.model)

    if sense === QUBOTools.Max
        return MOI.MAX_SENSE
    else
        return MOI.MIN_SENSE
    end
end

function MOI.set(model::QUBOModel, ::MOI.ObjectiveSense, os::MOI.OptimizationSense)
    if os ===  MOI.MAX_SENSE
        model.model.sense = QUBOTools.Max
    else
        model.model.sense = QUBOTools.Min
    end
end

function MOI.get(
    model::QUBOModel{T},
    ::MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{T}},
) where {T}
    b = QUBOTools.offset(model)
    a = MOI.ScalarAffineTerm{T}[]
    Q = MOI.ScalarQuadraticTerm{T}[]

    for (i, c) in QUBOTools.linear_terms(model)
        xi = QUBOTools.variable_inv(model, i)

        push!(a, MOI.ScalarAffineTerm{T}(c, xi))
    end

    for ((i, j), c) in QUBOTools.quadratic_terms(model)
        xi = QUBOTools.variable_inv(model, i)
        xj = QUBOTools.variable_inv(model, j)

        push!(Q, MOI.ScalarQuadraticTerm{T}(c, xi, xj))
    end

    return MOI.ScalarQuadraticFunction{T}(Q, a, b)
end

function MOI.set(
    model::QUBOModel{T},
    ::MOI.ObjectiveFunction{VI},
    vi::VI,
) where {T}
    linear_terms    = Dict{VI,T}(vi => one(T))
    quadratic_terms = Dict{Tuple{VI,VI},T}()

    model.model = QUBOTools.Model{VI,T,Int}(
        linear_terms,
        quadratic_terms;
        sense  = QUBOTools.sense(model.model),
        domain = QUBOTools.Domain(:bool),
    )

    return nothing
end

function MOI.set(
    model::QUBOModel{T},
    ::MOI.ObjectiveFunction{SAF{T}},
    f::SAF{T},
) where {T}
    linear_terms    = Dict{VI,T}()
    quadratic_terms = Dict{Tuple{VI,VI},T}()

    for a in f.terms
        c = a.coefficient
        x = a.variable

        linear_terms[x] = get(linear_terms, x, zero(T)) + c
    end

    offset = f.constant

    model.model = QUBOTools.Model{VI,T,Int}(
        linear_terms,
        quadratic_terms;
        offset = offset,
        sense  = QUBOTools.sense(model.model),
        domain = QUBOTools.Domain(:bool),
    )

    return nothing
end

function MOI.set(
    model::QUBOModel{T},
    ::MOI.ObjectiveFunction{SQF{T}},
    f::SQF{T},
) where {T}
    linear_terms    = Dict{VI,T}()
    quadratic_terms = Dict{Tuple{VI,VI},T}()

    for a in f.affine_terms
        c = a.coefficient
        x = a.variable

        linear_terms[x] = get(linear_terms, x, zero(T)) + c
    end

    for q in f.quadratic_terms
        c  = q.coefficient
        xi = q.variable_1
        xj = q.variable_2

        if xi == xj
            linear_terms[xi] = get(linear_terms, xi, zero(T)) + c / 2
        else
            quadratic_terms[(xi, xj)] = get(quadratic_terms, (xi, xj), zero(T)) + c
        end
    end

    offset = f.constant

    model.model = QUBOTools.Model{VI,T,Int}(
        linear_terms,
        quadratic_terms;
        offset = offset,
        sense  = QUBOTools.sense(model.model),
        domain = QUBOTools.Domain(:bool),
    )

    return nothing
end

function MOI.get(::QUBOModel{T}, ::MOI.ObjectiveFunctionType) where {T}
    return MOI.ScalarQuadraticFunction{T}
end

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
    v = MOI.get(model, MOI.ListOfVariableIndices())

    return [MOI.ConstraintIndex{VI,MOI.ZeroOne}(vi.value) for vi in v]
end

function MOI.get(
    model::QUBOModel,
    ::MOI.ListOfVariableIndices
)
    return QUBOTools.variables(model)
end

MOI.get(
    ::QUBOModel,
    ::MOI.ConstraintFunction,
    ci::MOI.ConstraintIndex{VI,MOI.ZeroOne},
) = VI(ci.value)

MOI.get(
    ::QUBOModel,
    ::MOI.ConstraintSet,
    ::MOI.ConstraintIndex{VI,MOI.ZeroOne},
) = MOI.ZeroOne()

MOI.get(::QUBOModel, ::MOI.VariableName, vi::VI) = "x[$(vi.value)]"

function MOI.get(model::QUBOModel{T}, vp::MOI.VariablePrimalStart, x::VI) where {T}
    return nothing
end

MOI.supports(::QUBOModel, ::MOI.VariablePrimalStart, ::MOI.VariableIndex) = true