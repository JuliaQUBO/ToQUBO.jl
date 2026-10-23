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
    MOI.empty!(model.bridge_model)
    MOI.empty!(model.source_model)
    delete!(model.constraint_settings, :soft_constraint)

    Compiler.reset!(model)

    return nothing
end

function MOI.optimize!(model::Optimizer)
    index_map = MOIU.identity_index_map(model.source_model)

    _reset_feasibility_caches!(model)

    # De facto JuMP to QUBO Compilation
    let t = @elapsed ToQUBO.Compiler.compile!(model)
        MOI.set(model, Attributes.CompilationStatus(), MOI.LOCALLY_SOLVED)
        MOI.set(model, Attributes.CompilationTime(), t)
    end

    if !isnothing(model.optimizer)
        MOI.optimize!(model.optimizer, model.target_model)
        MOI.set(model, MOI.RawStatusString(), MOI.get(model.optimizer, MOI.RawStatusString()))

        _refine_penalties!(model)
        _auto_feasibility_report!(model)
    else
        MOI.set(model, MOI.RawStatusString(), "Compilation complete without an internal solver")
    end

    return (index_map, false)
end

function _copy_constraints!(::Type{F}, ::Type{S}, source, target, index_map) where {F,S}
    for ci in MOI.get(source, MOI.ListOfConstraintIndices{F,S}())
        f = MOI.get(source, MOI.ConstraintFunction(), ci)
        s = MOI.get(source, MOI.ConstraintSet(), ci)

        index_map[ci] = MOI.add_constraint(target, MOIU.map_indices(index_map, f), s)
    end

    return nothing
end

function _set_copied_constraint_attribute!(
    model::Optimizer,
    bridge_model::MOIB.AbstractBridgeOptimizer,
    attr::MOI.AbstractConstraintAttribute,
    ci::MOI.ConstraintIndex,
    value,
)
    if MOIB.is_bridged(bridge_model, ci)
        br = MOIB.bridge(bridge_model, ci)
        for (BF, BS) in MOIB.added_constraint_types(typeof(br))
            for bci in MOI.get(br, MOI.ListOfConstraintIndices{BF,BS}())
                _set_copied_constraint_attribute!(model, bridge_model, attr, bci, value)
            end
        end
    else
        MOI.set(model, attr, ci, value)
    end

    return nothing
end

function _copy_constraint_attributes(
    ::Type{F},
    ::Type{S},
    source,
    target,
    bridge_model,
    index_map,
) where {F,S}
    for attr in MOI.get(source, MOI.ListOfConstraintAttributesSet{F,S}())
        for ci in MOI.get(source, MOI.ListOfConstraintIndices{F,S}())
            _set_copied_constraint_attribute!(
                target,
                bridge_model,
                attr,
                index_map[ci],
                MOI.get(source, attr, ci),
            )
        end
    end

    return nothing
end

function MOI.copy_to(model::Optimizer{T}, source::MOI.ModelLike) where {T}
    if !MOI.is_empty(model)
        error("QUBO Model is not empty")
    end

    variable_indices = MOI.get(source, MOI.ListOfVariableIndices())
    constraint_types = MOI.get(source, MOI.ListOfConstraintTypesPresent())

    # Build Index Map
    index_map = MOIU.IndexMap()

    # Copy to PreQUBOModel + Add Bridges
    bridge_model = MOIB.full_bridge_optimizer(model.source_model, T)

    # Copy Variables
    for vi in variable_indices
        index_map[vi] = MOI.add_variable(bridge_model)
    end

    # Copy Objective Function
    let F = MOI.get(source, MOI.ObjectiveFunctionType())
        MOI.set(
            bridge_model,
            MOI.ObjectiveFunction{F}(),
            MOIU.map_indices(index_map, MOI.get(source, MOI.ObjectiveFunction{F}())),
        )
    end

    # Copy Objective Sense
    MOI.set(bridge_model, MOI.ObjectiveSense(), MOI.get(source, MOI.ObjectiveSense()))

    # Copy Constraints
    for (F, S) in constraint_types
        _copy_constraints!(F, S, source, bridge_model, index_map)
    end

    # Copy Attributes
    for attr in MOI.get(source, MOI.ListOfModelAttributesSet())
        if attr isa MOI.ObjectiveFunction || attr isa MOI.ObjectiveSense
            continue
        end
        MOI.set(model, attr, MOIU.map_indices(index_map, attr, MOI.get(source, attr)))
    end

    for attr in MOI.get(source, MOI.ListOfVariableAttributesSet())
        for vi in variable_indices
            MOI.set(model, attr, index_map[vi], MOI.get(source, attr, vi))
        end
    end

    for (F, S) in constraint_types
        _copy_constraint_attributes(F, S, source, model, bridge_model, index_map)
    end

    remapped_incumbent = false
    remapped_policy = false
    for attr in MOI.get(source, MOI.ListOfOptimizerAttributesSet())
        if attr isa Attributes.PenaltyIncumbent
            MOI.set(
                model,
                attr,
                MOIU.map_indices(index_map, attr, MOI.get(source, attr)),
            )
            remapped_incumbent = true
        elseif attr isa Attributes.PenaltyPolicy
            MOI.set(
                model,
                attr,
                MOIU.map_indices(index_map, attr, MOI.get(source, attr)),
            )
            remapped_policy = true
        end
    end

    if !remapped_incumbent
        inc = MOI.get(model, Attributes.PenaltyIncumbent())
        if !isnothing(inc)
            MOI.set(
                model,
                Attributes.PenaltyIncumbent(),
                MOIU.map_indices(index_map, Attributes.PenaltyIncumbent(), inc),
            )
        end
    end

    if !remapped_policy && haskey(model.compiler_settings, :penalty_policy)
        pol = MOI.get(model, Attributes.PenaltyPolicy())
        MOI.set(
            model,
            Attributes.PenaltyPolicy(),
            MOIU.map_indices(index_map, Attributes.PenaltyPolicy(), pol),
        )
    end

    model.bridge_model = bridge_model

    return index_map
end

function MOI.copy_to(
    dest::MOIB.LazyBridgeOptimizer{<:MOIU.CachingOptimizer{<:Optimizer}},
    src::MOI.ModelLike,
)
    index_map = MOIU.default_copy_to(dest, src)

    for attr in MOI.get(src, MOI.ListOfOptimizerAttributesSet())
        if attr isa Attributes.PenaltyIncumbent || attr isa Attributes.PenaltyPolicy
            mapped = MOIU.map_indices(index_map, attr, MOI.get(src, attr))
            MOI.set(dest.model.model_cache, attr, mapped)

            if dest.model.optimizer !== nothing
                MOI.set(dest.model.optimizer, attr, mapped)
            end
        end
    end

    return index_map
end

# Objective Function Support
function MOI.supports(model::Optimizer, f::MOI.ObjectiveFunction{F}) where {F}
    return MOI.supports(model.source_model, f)
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

function Base.show(io::IO, model::Optimizer)
    print(
        io,
        """
        $(MOI.get(model, MOI.SolverName()))
        $(model.source_model)
        """,
    )
end

function QUBOTools.backend(model::Optimizer{T}; full_metadata::Bool = false) where {T}
    qubo_model = if isnothing(model.qubo_backend_cache)
        QUBOTools.Model{T}(model.target_model)
    else
        copy(model.qubo_backend_cache)
    end

    if full_metadata
        _attach_reformulation_metadata!(qubo_model, model)
    end

    return qubo_model
end
