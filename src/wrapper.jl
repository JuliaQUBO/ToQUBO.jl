# Notes on the optimize! interface
# After `JuMP.optimize!(model)` there are a few layers before reaching
#   1. `MOI.optimize!(::Optimizer, ::MOI.ModelLike)`
# Then, 
#   2. `MOI.copy_to(::Optimizer, ::MOI.ModelLike)`
#   3. `MOI.optimize!(::Optimizer)`
# is called.
const Optimizer{T} = Virtual.Model{T}

function MOI.is_empty(model::Optimizer)
    return MOI.is_empty(model.source_model)
end

function MOI.empty!(model::Optimizer)
    MOI.empty!(model.source_model)

    Compiler.reset!(model)

    # Underlying Optimizer
    if !isnothing(model.optimizer)
        MOI.empty!(model.optimizer)
    end

    return nothing
end

function MOI.optimize!(model::Optimizer)
    # De facto JuMP to QUBO Compilation
    let t = @elapsed ToQUBO.Compiler.compile!(model)
        MOI.set(model, Attributes.CompilationStatus(), MOI.LOCALLY_SOLVED)
        MOI.set(model, Attributes.CompilationTime(), t)
    end

    if !isnothing(model.optimizer)
        MOI.optimize!(model.optimizer, model.target_model)
        MOI.set(
            model,
            MOI.RawStatusString(),
            MOI.get(model.optimizer, MOI.RawStatusString()),
        )
    else
        MOI.set(
            model,
            MOI.RawStatusString(),
            "Compilation complete without an internal solver",
        )
    end

    return (model.index_map, false)
end

function _copy_variables!(
    model::Optimizer{T},
    source::MOI.ModelLike,
    index_map::MOIU.IndexMap,
) where {T}
    for vi in MOI.get(source, MOI.ListOfVariableIndices())
        index_map[vi] = MOI.add_variable(model)
    end

    _copy_variable_attributes!(model, source, index_map)

    return nothing
end

function _copy_variable_attributes!(
    model::Optimizer{T},
    source::MOI.ModelLike,
    index_map::MOIU.IndexMap,
) where {T}
    for attr in MOI.get(source, MOI.ListOfVariableAttributesSet())
        MOI.supports(model, attr, VI) || continue

        for vi in MOI.get(source, MOI.ListOfVariablesWithAttributeSet(attr))
            MOI.set(model, attr, index_map[vi], MOI.get(source, attr, vi))
        end
    end

    return nothing
end

function _copy_objective!(model::Optimizer{T}, source::MOI.ModelLike) where {T}
    let F = MOI.get(source, MOI.ObjectiveFunctionType())
        f = MOI.ObjectiveFunction{F}()
        s = MOI.ObjectiveSense()

        MOI.set(model, f, MOI.get(source, f))
        MOI.set(model, s, MOI.get(source, s))
    end

    return nothing
end

function _copy_constraints!(
    model::Optimizer{T},
    source::MOI.ModelLike,
    index_map::MOIU.IndexMap,
    ::Type{F},
    ::Type{S},
) where {T,F,S}
    for ci in MOI.get(source, MOI.ListOfConstraintIndices{F,S}())
        f = MOI.get(source, MOI.ConstraintFunction(), ci)
        s = MOI.get(source, MOI.ConstraintSet(), ci)

        index_map[ci] = MOI.add_constraint(model, f, s)
    end

    _copy_constraint_attributes!(model, source, index_map, F, S)

    return nothing
end

function _copy_constraints!(
    model::Optimizer{T},
    source::MOI.ModelLike,
    index_map::MOIU.IndexMap,
) where {T}
    for (F, S) in MOI.get(source, MOI.ListOfConstraintTypesPresent())
        _copy_constraints!(model, source, index_map, F, S)
    end

    return nothing
end

function _copy_constraint_attributes!(
    model::Optimizer{T},
    source::MOI.ModelLike,
    index_map,
    ::Type{F},
    ::Type{S},
) where {T,F,S}
    for attr in MOI.get(source, MOI.ListOfConstraintAttributesSet{F,S}())
        MOI.supports(model, attr, CI{F,S}) || continue

        for ci in MOI.get(source, MOI.ListOfConstraintsWithAttributeSet{F,S}(attr))
            MOI.set(model, attr, index_map[ci], MOI.get(source, attr, ci))
        end
    end

    return nothing
end

function MOI.copy_to(model::Optimizer{T}, source::MOI.ModelLike) where {T}
    index_map = MOIU.IndexMap()

    _copy_variables!(model, source, index_map)
    _copy_objective!(model, source)
    _copy_constraints!(model, source, index_map)

    # _copy_model_attributes!(source, target)

    return index_map
end

# function _copy_model_attributes!(source::MOI.ModelLike, target::MOI.ModelLike)
#     # TODO: Implement this
#     for attr in MOI.get(source, MOI.ListOfModelAttributesSet())
#         @show attr
#     end

#     return nothing
# end

# Attribute Access
function MOI.supports(model::Optimizer{T}, attr::MOI.AbstractModelAttribute) where {T}
    return MOI.supports(model.source_model, attr)
end

function MOI.get(model::Optimizer{T}, attr::MOI.AbstractModelAttribute) where {T}
    return MOI.get(model.source_model, attr)
end

function MOI.set(model::Optimizer{T}, attr::MOI.AbstractModelAttribute, value) where {T}
    return MOI.set(model.source_model, attr, value)
end


function MOI.supports(model::Optimizer{T}, attr::MOI.AbstractVariableAttribute, ::Type{VI}) where {T}
    return MOI.supports(model.source_model, attr, VI)
end

function MOI.get(model::Optimizer{T}, attr::MOI.AbstractVariableAttribute, vi::VI) where {T}
    return MOI.get(model.source_model, attr, vi)
end

function MOI.set(model::Optimizer{T}, attr::MOI.AbstractVariableAttribute, vi::VI, value) where {T}
    return MOI.set(model.source_model, attr, vi, value)
end


function MOI.supports(model::Optimizer{T}, attr::MOI.AbstractConstraintAttribute, ::Type{CI{F,S}}) where {T,F,S}
    return MOI.supports(model.source_model, attr, CI{F,S})
end

function MOI.get(model::Optimizer{T}, attr::MOI.AbstractConstraintAttribute, ci::CI{F,S}) where {T,F,S}
    return MOI.get(model.source_model, attr, ci)
end

function MOI.set(model::Optimizer{T}, attr::MOI.AbstractConstraintAttribute, ci::CI{F,S}, value) where {T,F,S}
    return MOI.set(model.source_model, attr, ci, value)
end

# Constraint Support
function MOI.supports_constraint(
    model::Optimizer,
    ::Type{F},
    ::Type{S},
) where {F<:MOI.AbstractFunction,S<:MOI.AbstractSet}
    return MOI.supports_constraint(model.source_model, F, S)
end

function MOI.supports_add_constrained_variable(
    model::Optimizer,
    ::Type{S},
) where {S<:MOI.AbstractScalarSet}
    return MOI.supports_add_constrained_variable(model.source_model, S)
end

function MOI.add_constraint(
    model::Optimizer,
    f::F,
    s::S,
) where {F<:MOI.AbstractFunction,S<:MOI.AbstractSet}
    return MOI.add_constraint(model.source_model, f, s)
end

function MOI.add_variable(model::Optimizer)
    return MOI.add_variable(model.source_model)
end

function Base.show(io::IO, model::Optimizer)
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
