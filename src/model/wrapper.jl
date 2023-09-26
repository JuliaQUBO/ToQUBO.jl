# Notes on the optimize! interface
# After `JuMP.optimize!(model)` there are a few layers before reaching
#   1. `MOI.optimize!(::VirtualModel, ::MOI.ModelLike)`
# Then, 
#   2. `MOI.copy_to(::VirtualModel, ::MOI.ModelLike)`
#   3. `MOI.optimize!(::VirtualModel)`
# is called.

function MOI.is_empty(model::VirtualModel)
    return MOI.is_empty(model.source_model)
end

function MOI.empty!(model::VirtualModel)
    MOI.empty!(model.source_model)

    Compiler.reset!(model)

    # Underlying Optimizer
    if !isnothing(model.optimizer)
        MOI.empty!(model.optimizer)
    end

    return nothing
end

function MOI.optimize!(model::VirtualModel)
    index_map = MOIU.identity_index_map(model.source_model)

    # De facto JuMP to QUBO Compilation
    ToQUBO.Compiler.toqubo!(model)

    if !isnothing(model.optimizer)
        MOI.optimize!(model.optimizer, model.target_model)
    end

    return (index_map, false)
end

function _copy_constraints!(::Type{F}, ::Type{S}, source, target, index_map) where {F,S}
    for ci in MOI.get(source, MOI.ListOfConstraintIndices{F,S}())
        f = MOI.get(source, MOI.ConstraintFunction(), ci)
        s = MOI.get(source, MOI.ConstraintSet(), ci)

        index_map[ci] = MOI.add_constraint(target, f, s)
    end

    return nothing
end

function _copy_constraint_attributes(
    ::Type{F},
    ::Type{S},
    source,
    target,
    index_map,
) where {F,S}
    for attr in MOI.get(source, MOI.ListOfConstraintAttributesSet{F,S}())
        for ci in MOI.get(source, MOI.ListOfConstraintIndices{F,S}())
            MOI.set(target, attr, index_map[ci], MOI.get(source, attr, ci))
        end
    end

    return nothing
end

function MOI.copy_to(model::VirtualModel{T}, source::MOI.ModelLike) where {T}
    if !MOI.is_empty(model)
        error("QUBO Model is not empty")
    end

    # Build Index Map
    index_map = MOIU.IndexMap()

    # Copy to PreQUBOModel + Add Bridges
    bridge_model = MOIB.full_bridge_optimizer(model.source_model, T)

    # Copy Objective Function
    let F = MOI.get(source, MOI.ObjectiveFunctionType())
        MOI.set(
            bridge_model,
            MOI.ObjectiveFunction{F}(),
            MOI.get(source, MOI.ObjectiveFunction{F}()),
        )
    end

    # Copy Objective Sense
    MOI.set(bridge_model, MOI.ObjectiveSense(), MOI.get(source, MOI.ObjectiveSense()))

    # Copy Variables
    for vi in MOI.get(source, MOI.ListOfVariableIndices())
        index_map[vi] = MOI.add_variable(bridge_model)
    end

    # Copy Constraints
    for (F, S) in MOI.get(source, MOI.ListOfConstraintTypesPresent())
        _copy_constraints!(F, S, source, bridge_model, index_map)
    end

    # Copy Attributes
    for attr in MOI.get(source, MOI.ListOfModelAttributesSet())
        MOI.set(model, attr, MOI.get(source, attr))
    end

    for attr in MOI.get(source, MOI.ListOfVariableAttributesSet())
        for vi in MOI.get(source, MOI.ListOfVariableIndices())
            MOI.set(model, attr, index_map[vi], MOI.get(source, attr, vi))
        end
    end

    for (F, S) in MOI.get(source, MOI.ListOfConstraintTypesPresent())
        _copy_constraint_attributes(F, S, source, model, index_map)
    end

    return index_map
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

function Base.show(io::IO, model::VirtualModel)
    print(
        io,
        """
        $(MOI.get(model, MOI.SolverName()))
        $(model.source_model)
        """,
    )
end

function QUBOTools.backend(model::Optimizer{T}) where {T}
    return QUBOTools.Model{T}(model.target_model)
end
