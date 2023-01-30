function MOI.get(model::VirtualModel, attr::MOI.AbstractOptimizerAttribute)
    if !isnothing(model.optimizer)
        return MOI.get(model.optimizer, attr)
    else
        return nothing
    end
end

function MOI.set(model::VirtualModel, attr::MOI.AbstractOptimizerAttribute, value::Any)
    if !isnothing(model.optimizer)
        MOI.set(model.optimizer, attr, value)
    end

    return nothing
end

function MOI.get(
    model::VirtualModel,
    attr::Union{
        MOI.SolveTimeSec,
        MOI.PrimalStatus,
        MOI.DualStatus,
        MOI.TerminationStatus,
        MOI.RawStatusString,
    },
)
    if !isnothing(model.optimizer)
        return MOI.get(model.optimizer, attr)
    else
        return nothing
    end
end

function MOI.supports(
    model::VirtualModel,
    attr::Union{
        MOI.SolveTimeSec,
        MOI.PrimalStatus,
        MOI.DualStatus,
        MOI.TerminationStatus,
        MOI.RawStatusString,
    },
)
    if !isnothing(model.optimizer)
        return MOI.supports(model.optimizer, attr)
    else
        return false
    end
end

function MOI.get(model::VirtualModel, rc::MOI.ResultCount)
    if isnothing(model.optimizer)
        return 0
    else
        return MOI.get(model.optimizer, rc)
    end
end

MOI.supports(::VirtualModel, ::MOI.ResultCount) = true

function MOI.get(model::VirtualModel{T}, ov::MOI.ObjectiveValue) where {T}
    if isnothing(model.optimizer)
        return zero(T)
    else
        return MOI.get(model.optimizer, ov)
    end
end

function MOI.get(model::VirtualModel{T}, vp::MOI.VariablePrimalStart, x::VI) where {T}
    return MOI.get(model.source_model, vp, x)
end

MOI.supports(::VirtualModel, ::MOI.VariablePrimalStart, ::MOI.VariableIndex) = true

function MOI.get(model::VirtualModel{T}, vp::MOI.VariablePrimal, x::VI) where {T}
    if isnothing(model.optimizer)
        return zero(T)
    else
        s = zero(T)
        v = model.source[x]

        for (ω, c) in expansion(v)
            for y in ω
                c *= MOI.get(model.optimizer, vp, y)
            end

            s += c
        end

        return s
    end
end

function MOI.get(model::VirtualModel, rs::MOI.RawSolver)
    if isnothing(model.optimizer)
        return nothing
    else
        return MOI.get(model.optimizer, rs)
    end
end
