module Compiler

# Imports
import MathOptInterface as MOI
import MathOptInterface: empty!
import PseudoBooleanOptimization as PBO

import QUBOTools
import QUBOTools: AbstractArchitecture, GenericArchitecture

import ..Attributes
import ..Encoding
import ..Virtual

# Constants
const VI      = MOI.VariableIndex
const CI{F,S} = MOI.ConstraintIndex{F,S}
const SAT{T}  = MOI.ScalarAffineTerm{T}
const SAF{T}  = MOI.ScalarAffineFunction{T}
const SQT{T}  = MOI.ScalarQuadraticTerm{T}
const SQF{T}  = MOI.ScalarQuadraticFunction{T}
const EQ{T}   = MOI.EqualTo{T}
const LT{T}   = MOI.LessThan{T}
const GT{T}   = MOI.GreaterThan{T}

include("error.jl")
include("analysis.jl")
include("interface.jl")
include("parse.jl")
include("setup.jl")
include("variables.jl")
include("objective.jl")
include("constraints.jl")
include("penalties.jl")
include("build.jl")

function compile!(model::Virtual.Model)
    arch = MOI.get(model, Attributes.Architecture())

    compile!(model, arch)

    return nothing
end

function compile!(model::Virtual.Model{T}, arch::AbstractArchitecture) where {T}
    delete!(model.compiler_settings, :qubo_fast_path)

    if is_qubo(model.source_model)
        Compiler.copy!(model, arch)

        return nothing
    end

    # Compiler Settings
    setup!(model, arch)

    # Objective Sense
    sense!(model, arch)

    # Problem Variables
    variables!(model, arch)

    # Objective Analysis
    objective!(model, arch)

    # Add Regular Constraints
    constraints!(model, arch)

    # Compute penalties
    penalties!(model, arch)

    # Build Final Model
    build!(model, arch)

    return nothing
end

function reset!(model::Virtual.Model, ::AbstractArchitecture = GenericArchitecture())
    # Model
    MOI.empty!(model.target_model)

    # Virtual Variables
    Base.empty!(model.variables)
    Base.empty!(model.source)
    Base.empty!(model.target)
    Base.empty!(model.slack)

    # PBF/IR
    Base.empty!(model.f)
    Base.empty!(model.g)
    Base.empty!(model.h)
    Base.empty!(model.ρ)
    Base.empty!(model.θ)
    Base.empty!(model.s)
    Base.empty!(model.η)
    Base.empty!(model.H)
    model.qubo_backend_cache = nothing

    # Optimize-generated status
    MOI.set(model, Attributes.CompilationStatus(), nothing)
    MOI.set(model, Attributes.CompilationTime(), nothing)
    delete!(model.compiler_settings, :qubo_fast_path)
    delete!(model.compiler_settings, :penalty_policy_metadata)
    delete!(model.moi_settings, :raw_status_string)
    delete!(model.moi_settings, :feasibility_report)
    delete!(model.moi_settings, :primal_feasibility)

    return nothing
end

function Compiler.copy!(model::Virtual.Model{T}, arch::AbstractArchitecture) where {T}
    reset!(model, arch)

    variable_map = _copy_qubo_variables!(model)

    MOI.set(
        model.target_model,
        MOI.ObjectiveSense(),
        MOI.get(model.source_model, MOI.ObjectiveSense()),
    )

    _copy_qubo_objective!(model, variable_map)

    model.compiler_settings[:qubo_fast_path] = true

    return nothing
end

function _copy_qubo_variables!(model::Virtual.Model{T}) where {T}
    source_variables = MOI.get(model.source_model, MOI.ListOfVariableIndices())
    variable_map = sizehint!(Dict{VI,VI}(), length(source_variables))

    for x in source_variables
        y, _ = MOI.add_constrained_variable(model.target_model, MOI.ZeroOne())
        variable_map[x] = y

        v = Virtual.Variable{T}(
            Encoding.Mirror{T}(),
            x,
            VI[y],
            PBO.PBF{VI,T}(y),
            nothing,
        )

        model.source[x] = v
        model.target[y] = v
        push!(model.variables, v)
    end

    return variable_map
end

function _qubo_backend_sense(sense::MOI.OptimizationSense)
    return sense === MOI.MIN_SENSE ? :min : :max
end

# Fast-path target variables are created from an empty QUBOModel with contiguous
# values 1:n. Sorting by value makes position i correspond to the variable whose
# value is i, which is the index used when accumulating the sparse coefficient
# data below and the order QUBOTools' public constructor preserves.
function _target_variables(variable_map::Dict{VI,VI})
    return sort!(collect(values(variable_map)); by = y -> y.value)
end

function _cache_qubo_backend!(
    model::Virtual.Model{T},
    variable_map::Dict{VI,VI},
    linear_indices::Vector{Int},
    linear_values::Vector{T},
    quadratic_rows::Vector{Int},
    quadratic_cols::Vector{Int},
    quadratic_values::Vector{T},
    offset::T,
) where {T}
    # Build the cached backend through QUBOTools' public COO constructor
    # (QUBOTools v0.16). It performs the strict upper-triangular split, duplicate
    # summation, and zero dropping internally; the copy tests guard parity with
    # parsing the target MOI model.
    model.qubo_backend_cache = QUBOTools.Model{VI,T,Int}(
        _target_variables(variable_map),
        linear_indices,
        linear_values,
        quadratic_rows,
        quadratic_cols,
        quadratic_values;
        offset,
        sense = _qubo_backend_sense(MOI.get(model.target_model, MOI.ObjectiveSense())),
        domain = :bool,
    )

    return nothing
end

function _set_target_qubo_objective!(model::Virtual.Model{T}, f::SQF{T}) where {T}
    model.target_model.objective_function = f

    return nothing
end

function _copy_qubo_objective!(model::Virtual.Model{T}, variable_map) where {T}
    F = MOI.get(model.source_model, MOI.ObjectiveFunctionType())
    f = MOI.get(model.source_model, MOI.ObjectiveFunction{F}())

    _copy_qubo_objective!(model, variable_map, f)

    return nothing
end

function _copy_qubo_objective!(
    model::Virtual.Model{T},
    variable_map::Dict{VI,VI},
    vi::VI,
) where {T}
    y = variable_map[vi]
    affine_terms = SAT{T}[SAT{T}(one(T), y)]
    linear_indices = Int[y.value]
    linear_values = T[one(T)]

    _set_target_qubo_objective!(model, SQF{T}(SQT{T}[], affine_terms, zero(T)))
    _cache_qubo_backend!(
        model,
        variable_map,
        linear_indices,
        linear_values,
        Int[],
        Int[],
        T[],
        zero(T),
    )

    return nothing
end

function _copy_qubo_objective!(
    model::Virtual.Model{T},
    variable_map::Dict{VI,VI},
    obj::SAF{T},
) where {T}
    affine_terms = sizehint!(SAT{T}[], length(obj.terms))
    linear_indices = sizehint!(Int[], length(obj.terms))
    linear_values = sizehint!(T[], length(obj.terms))

    for term in obj.terms
        y = variable_map[term.variable]
        c = term.coefficient

        push!(affine_terms, SAT{T}(c, y))
        push!(linear_indices, y.value)
        push!(linear_values, c)
    end

    _set_target_qubo_objective!(model, SQF{T}(SQT{T}[], affine_terms, obj.constant))
    _cache_qubo_backend!(
        model,
        variable_map,
        linear_indices,
        linear_values,
        Int[],
        Int[],
        T[],
        obj.constant,
    )

    return nothing
end

function _copy_qubo_objective!(
    model::Virtual.Model{T},
    variable_map::Dict{VI,VI},
    obj::SQF{T},
) where {T}
    quadratic_terms = sizehint!(SQT{T}[], length(obj.quadratic_terms))
    affine_terms = sizehint!(SAT{T}[], length(obj.affine_terms))
    linear_indices = sizehint!(Int[], length(obj.affine_terms))
    linear_values = sizehint!(T[], length(obj.affine_terms))
    quadratic_rows = sizehint!(Int[], length(obj.quadratic_terms))
    quadratic_cols = sizehint!(Int[], length(obj.quadratic_terms))
    quadratic_values = sizehint!(T[], length(obj.quadratic_terms))

    for term in obj.quadratic_terms
        x = variable_map[term.variable_1]
        y = variable_map[term.variable_2]
        c = term.coefficient

        push!(quadratic_terms, SQT{T}(c, x, y))

        if x == y
            push!(linear_indices, x.value)
            push!(linear_values, c / 2)
        else
            i = x.value
            j = y.value

            if i < j
                push!(quadratic_rows, i)
                push!(quadratic_cols, j)
            else
                push!(quadratic_rows, j)
                push!(quadratic_cols, i)
            end

            push!(quadratic_values, c)
        end
    end

    for term in obj.affine_terms
        y = variable_map[term.variable]
        c = term.coefficient

        push!(affine_terms, SAT{T}(c, y))
        push!(linear_indices, y.value)
        push!(linear_values, c)
    end

    _set_target_qubo_objective!(
        model,
        SQF{T}(quadratic_terms, affine_terms, obj.constant),
    )
    _cache_qubo_backend!(
        model,
        variable_map,
        linear_indices,
        linear_values,
        quadratic_rows,
        quadratic_cols,
        quadratic_values,
        obj.constant,
    )

    return nothing
end

end # module Compiler
