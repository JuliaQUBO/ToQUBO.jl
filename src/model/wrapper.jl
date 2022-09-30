function MOI.empty!(model::VirtualQUBOModel)
    # -*- Models -*-
    MOI.empty!(MOI.get(model, VM.SourceModel()))
    MOI.empty!(MOI.get(model, VM.TargetModel()))

    # -*- Virtual Variables -*-
    empty!(MOI.get(model, VM.Variables()))
    empty!(MOI.get(model, VM.Source()))
    empty!(MOI.get(model, VM.Target()))

    # -*- Underlying Optimizer -*-
    isnothing(model.optimizer) || MOI.empty!(model.optimizer)

    # -*- PBF/IR -*-
    empty!(model.f)
    empty!(model.g)
    empty!(model.h)

    # -*- Attributes -*-
    empty!(model.attrs)

    nothing
end

function MOI.optimize!(model::VirtualQUBOModel)
    if isnothing(model.optimizer)
        error("No optimizer attached")
    end

    source_model = MOI.get(model, VM.SourceModel())
    target_model = MOI.get(model, VM.TargetModel())

    MOI.optimize!(model.optimizer, target_model)

    index_map = MOIU.identity_index_map(source_model)

    return (index_map, false)
end

function MOI.copy_to(model::VirtualQUBOModel{T}, source::MOI.ModelLike) where {T}
    if !MOI.is_empty(model)
        error("QUBO Model is not empty")
    end

    # -*- Copy to PreQUBOModel + Trigger Bridges -*-
    source_model = MOI.get(model, VM.SourceModel())

    index_map = MOI.copy_to(
        MOIB.full_bridge_optimizer(source_model, T),
        source,
    )

    ToQUBO.toqubo!(model)

    return index_map
end

# -*- :: Objective Function Support :: -*- #
MOI.supports(
    ::VirtualQUBOModel{T},
    ::MOI.ObjectiveFunction{<:Union{VI,SAF{T},SQF{T}}},
) where {T} = true

# -*- :: Constraint Support :: -*- #
MOI.supports_constraint(
    ::VirtualQUBOModel{T},
    ::Type{<:VI},
    ::Type{<:Union{MOI.ZeroOne,MOI.Integer,MOI.Interval{T}}},
) where {T} = true

MOI.supports_constraint(
    ::VirtualQUBOModel{T},
    ::Type{<:Union{VI,SAF{T},SQF{T}}},
    ::Type{<:Union{MOI.EqualTo{T},MOI.LessThan{T}}},
) where {T} = true

MOI.supports_add_constrained_variable(
    ::VirtualQUBOModel{T},
    ::Type{<:Union{MOI.ZeroOne,MOI.Integer,MOI.Interval{T}}},
) where {T} = true

function MOI.get(
    model::VirtualQUBOModel,
    attr::Union{
        MOI.SolveTimeSec,
        MOI.PrimalStatus,
        MOI.DualStatus,
        MOI.TerminationStatus,
        MOI.RawStatusString,
    }
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
        s = zero(T)
        
        for (ω, c) in VM.expansion(MOI.get(model, VM.Source(), x))
            for y in ω
                c *= MOI.get(model.optimizer, vp, y)
            end
            
            s += c
        end
        
        return s
    end
end

MOI.get(::VirtualQUBOModel, ::MOI.SolverName) = "Virtual QUBO Model"
MOI.get(::VirtualQUBOModel, ::MOI.SolverVersion) = v"0.1.2"
MOI.get(model::VirtualQUBOModel, rs::MOI.RawSolver) = MOI.get(model.optimizer, rs)

PBO.showvar(x::VI) = PBO.showvar(x.value)
PBO.varcmp(x::VI, y::VI) = PBO.varcmp(x.value, y.value)

const Optimizer{T} = VirtualQUBOModel{T}
