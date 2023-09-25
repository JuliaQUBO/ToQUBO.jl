# Notes on the optimize! interface
# After `JuMP.optimize!(model)` there are a few layers before reaching
#   1. `MOI.optimize!(::VirtualModel, ::MOI.ModelLike)`
# Then, 
#   2. `MOI.copy_to(::VirtualModel, ::MOI.ModelLike)`
#   3. `MOI.optimize!(::VirtualModel)`
# is called.

function MOI.optimize!(model::VirtualModel)
    index_map = MOIU.identity_index_map(model.source_model)

    # De facto JuMP to QUBO Compilation
    ToQUBO.Compiler.toqubo!(model)

    if !isnothing(model.optimizer)
        MOI.optimize!(model.optimizer, model.target_model)
    end

    return (index_map, false)
end

function MOI.copy_to(model::VirtualModel{T}, source::MOI.ModelLike) where {T}
    if !MOI.is_empty(model)
        error("QUBO Model is not empty")
    end

    # Copy Attributes

    # Copy to PreQUBOModel + Add Bridges
    bridge_model = MOIB.full_bridge_optimizer(model.source_model, T)

    # Copy to source using bridges
    return MOI.copy_to(bridge_model, source) # index_map
end

# Objective Function Support
MOI.supports(
    ::VirtualModel{T},
    ::MOI.ObjectiveFunction{<:Union{VI,SAF{T},SQF{T}}},
) where {T} = true

# Constraint Support
MOI.supports_constraint(
    ::VirtualModel{T},
    ::Type{VI},
    ::Type{
        <:Union{MOI.ZeroOne,MOI.Integer,MOI.Interval{T},MOI.LessThan{T},MOI.GreaterThan{T}},
    },
) where {T} = true

MOI.supports_constraint(
    ::VirtualModel{T},
    ::Type{<:Union{SAF{T},SQF{T}}},
    ::Type{<:Union{MOI.EqualTo{T},MOI.LessThan{T}}},
) where {T} = true

MOI.supports_constraint(
    ::VirtualModel{T},
    ::Type{<:MOI.VectorOfVariables},
    ::Type{<:MOI.SOS1},
) where {T} = true

MOI.supports_add_constrained_variable(
    ::VirtualModel{T},
    ::Type{
        <:Union{MOI.ZeroOne,MOI.Integer,MOI.Interval{T},MOI.LessThan{T},MOI.GreaterThan{T}},
    },
) where {T} = true

const Optimizer{T} = VirtualModel{T}
