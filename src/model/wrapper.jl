function MOI.empty!(model::VirtualQUBOModel)
    # -*- Models -*-
    MOI.empty!(MOI.get(model, SourceModel()))
    MOI.empty!(MOI.get(model, TargetModel()))

    # -*- Virtual Variables -*-
    empty!(MOI.get(model, Variables()))
    empty!(MOI.get(model, Source()))
    empty!(MOI.get(model, Target()))

    # -*- Underlying Optimizer -*-
    if !isnothing(model.optimizer)
        MOI.empty!(model.optimizer)
    end

    # -*- PBF/IR -*-
    empty!(model.f)
    empty!(model.g)
    empty!(model.h)
    empty!(model.ρ)
    empty!(model.θ)

    return nothing
end

# Notes on the optimize! interface
# After `JuMP.optimize!(model)` there are a few layers before reaching
#   1. `MOI.optimize!(::VirtualQUBOModel, ::MOI.ModelLike)`
# Then, 
#   2. `MOI.copy_to(::VirtualQUBOModel, ::MOI.ModelLike)`
#   3. `MOI.optimize!(::VirtualQUBOModel)`
# is called.

function MOI.optimize!(model::VirtualQUBOModel)
    source_model = MOI.get(model, SourceModel())
    target_model = MOI.get(model, TargetModel())
    index_map    = MOIU.identity_index_map(source_model)

    # -*- JuMP to QUBO Compilation -*- #
    ToQUBO.toqubo!(model)

    if !isnothing(model.optimizer)
        MOI.optimize!(model.optimizer, target_model)
    end

    return (index_map, false)
end

function MOI.copy_to(model::VirtualQUBOModel{T}, source::MOI.ModelLike) where {T}
    if !MOI.is_empty(model)
        error("QUBO Model is not empty")
    end

    # -*- Copy to PreQUBOModel + Add Bridges -*- #
    source_model = MOI.get(model, SourceModel())
    bridge_model = MOIB.full_bridge_optimizer(source_model, T)

    # -*- Copy to source using bridges - *- #
    return MOI.copy_to(bridge_model, source) # index_map
end

# -*- :: Objective Function Support :: -*- #
MOI.supports(
    ::VirtualQUBOModel{T},
    ::MOI.ObjectiveFunction{<:Union{VI,SAF{T},SQF{T}}},
) where {T} = true

# -*- :: Constraint Support :: -*- #
MOI.supports_constraint(
    ::VirtualQUBOModel{T},
    ::Type{VI},
    ::Type{
        <:Union{MOI.ZeroOne,MOI.Integer,MOI.Interval{T},MOI.LessThan{T},MOI.GreaterThan{T}},
    },
) where {T} = true

MOI.supports_constraint(
    ::VirtualQUBOModel{T},
    ::Type{<:Union{SAF{T},SQF{T}}},
    ::Type{<:Union{MOI.EqualTo{T},MOI.LessThan{T}}},
) where {T} = true

MOI.supports_constraint(
    ::VirtualQUBOModel{T},
    ::Type{<:MOI.VectorOfVariables},
    ::Type{<:MOI.SOS1},
) where {T} = true

MOI.supports_add_constrained_variable(
    ::VirtualQUBOModel{T},
    ::Type{
        <:Union{MOI.ZeroOne,MOI.Integer,MOI.Interval{T},MOI.LessThan{T},MOI.GreaterThan{T}},
    },
) where {T} = true

function MOI.get(
    model::VirtualQUBOModel,
    attr::Union{
        MOI.SolveTimeSec,
        MOI.PrimalStatus,
        MOI.DualStatus,
        MOI.TerminationStatus,
        MOI.RawStatusString,
    },
)
    if !isnothing(model.optimizer)
        MOI.get(model.optimizer, attr)
    else
        nothing
    end
end

function MOI.set(
    model::VirtualQUBOModel,
    attr::Union{
        MOI.SolveTimeSec,
        MOI.PrimalStatus,
        MOI.DualStatus,
        MOI.TerminationStatus,
        MOI.RawStatusString,
    },
    value::Any,
)
    return MOI.set(model.optimizer, attr, value)
end

MOI.supports(::VirtualQUBOModel, ::MOI.SolveTimeSec) = true

function MOI.get(model::VirtualQUBOModel, rc::MOI.ResultCount)
    if isnothing(model.optimizer)
        return 0
    else
        return MOI.get(model.optimizer, rc)
    end
end

MOI.supports(::VirtualQUBOModel, ::MOI.ResultCount) = true

function MOI.get(model::VirtualQUBOModel{T}, ov::MOI.ObjectiveValue) where {T}
    if isnothing(model.optimizer)
        return zero(T)
    else
        return MOI.get(model.optimizer, ov)
    end
end

function MOI.get(model::VirtualQUBOModel{T}, vp::MOI.VariablePrimal, x::VI) where {T}
    if isnothing(model.optimizer)
        return zero(T)
    else
        v = MOI.get(model, Source(), x)
        s = zero(T)

        for (ω, c) in expansion(v)
            for y in ω
                c *= MOI.get(model.optimizer, vp, y)
            end

            s += c
        end

        return s
    end
end

MOI.get(::VirtualQUBOModel, ::MOI.SolverName)    = "Virtual QUBO Model"
MOI.get(::VirtualQUBOModel, ::MOI.SolverVersion) = PROJECT_VERSION

function MOI.get(model::VirtualQUBOModel, rs::MOI.RawSolver)
    if isnothing(model.optimizer)
        return nothing
    else
        return MOI.get(model.optimizer, rs)
    end
end

PBO.showvar(x::VI) = PBO.showvar(x.value)

PBO.varcmp(x::VI, y::VI) = PBO.varcmp(x.value, y.value)

function PBO.varcmp(x::Set{V}, y::Set{V}) where {V}
    if length(x) == length(y)
        xv = sort!(collect(x); lt = PBO.varcmp)
        yv = sort!(collect(y); lt = PBO.varcmp)

        for (xi, yi) in zip(xv, yv)
            if xi == yi
                continue
            else
                return PBO.varcmp(xi, yi)
            end
        end

        return false
    else
        return length(x) < length(y)
    end
end

const Optimizer{T} = VirtualQUBOModel{T}
