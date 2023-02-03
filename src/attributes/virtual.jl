function MOI.empty!(model::VirtualModel)
    # Models
    MOI.empty!(model.source_model)
    MOI.empty!(model.target_model)

    # Virtual Variables
    empty!(model.variables)
    empty!(model.source)
    empty!(model.target)

    # Underlying Optimizer
    if !isnothing(model.optimizer)
        MOI.empty!(model.optimizer)
    end

    # PBF/IR
    empty!(model.f)
    empty!(model.g)
    empty!(model.h)
    empty!(model.ρ)
    empty!(model.θ)

    return nothing
end

function MOI.get(::VirtualModel{T}, ::MOIB.ListOfNonstandardBridges{T}) where {T}
    return Type[]
end
