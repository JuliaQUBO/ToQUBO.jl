function MOI.get(model::VirtualModel, raw_attr::MOI.RawOptimizerAttribute)
    if !isnothing(model.optimizer) && MOI.supports(model.optimizer, raw_attr)
        return MOI.get(model.optimizer, raw_attr)
    else
        # Error if no underlying optimizer is present
        MOI.get_fallback(model, raw_attr)
    end
end

function MOI.set(model::VirtualModel, raw_attr::MOI.RawOptimizerAttribute, args...)
    if !isnothing(model.optimizer) && MOI.supports(model.optimizer, raw_attr)
        MOI.set(model.optimizer, raw_attr, args...)
    else
        # Error if no underlying optimizer is present
        MOI.throw_set_error_fallback(model, raw_attr, args...)
    end

    return nothing
end

function MOI.supports(model::VirtualModel, raw_attr::MOI.AbstractOptimizerAttribute)
    if !isnothing(model.optimizer)
        return MOI.supports(model.optimizer, raw_attr)
    else
        # ToQUBO.Optimizer doesn't support any raw attributes
        return false
    end
end

function MOI.get(model::VirtualModel, attr::MOI.AbstractOptimizerAttribute)
    if !isnothing(model.optimizer) && MOI.supports(model.optimizer, attr)
        return MOI.get(model.optimizer, attr)
    else
        return MOI.get(model.source_model, attr)
    end
end

function MOI.set(model::VirtualModel, attr::MOI.AbstractOptimizerAttribute, args...)
    if !isnothing(model.optimizer) && MOI.supports(model.optimizer, attr)
        MOI.set(model.optimizer, attr, args...)
    else
        MOI.set(model.source_model, attr, args...)
    end

    return nothing
end

function MOI.supports(model::VirtualModel, attr::MOI.AbstractOptimizerAttribute)
    if !isnothing(model.optimizer)
        return MOI.supports(model.optimizer, attr)
    else
        return MOI.supports(model.source_model, attr)
    end
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
