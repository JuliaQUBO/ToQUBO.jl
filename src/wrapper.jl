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
        MOI.set(model, MOI.RawStatusString(), MOI.get(model.optimizer, MOI.RawStatusString()))
    else
        MOI.set(model, MOI.RawStatusString(), "Compilation complete without an internal solver")
    end

    return (model.index_map, false)
end

function _copy_constraints!(::Type{F}, ::Type{S}, source, target, index_map) where {F,S}
    for ci in MOI.get(source, MOI.ListOfConstraintIndices{F,S}())
        f = MOI.get(source, MOI.ConstraintFunction(), ci)
        s = MOI.get(source, MOI.ConstraintSet(), ci)

        index_map[ci] = MOI.add_constraint(target, f, s)
    end

    return nothing
end

function _copy_constraint_attributes!(
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

function MOI.copy_to(model::Optimizer{T}, source::MOI.ModelLike) where {T}
    return MOIU.default_copy_to(model, source)
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
