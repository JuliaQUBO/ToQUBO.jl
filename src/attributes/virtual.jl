function MOI.is_empty(model::VirtualModel)
    return MOI.is_empty(model.source_model)
end

function MOI.empty!(model::VirtualModel)
    # Source Model
    MOI.empty!(model.source_model)

    # Underlying Optimizer
    if !isnothing(model.optimizer)
        MOI.empty!(model.optimizer)
    end

    return nothing
end

function MOI.get(::VirtualModel{T}, ::MOIB.ListOfNonstandardBridges{T}) where {T}
    return Type[]
end
