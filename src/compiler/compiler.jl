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

function _ordered_qubo_pair(x::VI, y::VI)
    return x.value <= y.value ? (x, y) : (y, x)
end

function _add_or_drop!(terms::Dict{K,T}, key::K, value::T) where {K,T}
    new_value = get(terms, key, zero(T)) + value

    if iszero(new_value)
        delete!(terms, key)
    else
        terms[key] = new_value
    end

    return nothing
end

function _qubo_backend_sense(sense::MOI.OptimizationSense)
    return sense === MOI.MIN_SENSE ? :min : :max
end

function _empty_qubo_linear_terms(::Type{T}, variable_map::Dict{VI,VI}) where {T}
    linear_terms = sizehint!(Dict{VI,T}(), length(variable_map))

    for y in values(variable_map)
        linear_terms[y] = zero(T)
    end

    return linear_terms
end

function _cache_qubo_backend!(
    model::Virtual.Model{T},
    linear_terms::Dict{VI,T},
    quadratic_terms::Dict{Tuple{VI,VI},T},
    offset::T,
) where {T}
    model.qubo_backend_cache = QUBOTools.Model{VI,T,Int}(
        linear_terms,
        quadratic_terms;
        offset,
        sense = _qubo_backend_sense(MOI.get(model.target_model, MOI.ObjectiveSense())),
        domain = :bool,
    )

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
    linear_terms = _empty_qubo_linear_terms(T, variable_map)
    quadratic_terms = Dict{Tuple{VI,VI},T}()

    linear_terms[y] += one(T)

    MOI.set(
        model.target_model,
        MOI.ObjectiveFunction{SQF{T}}(),
        SQF{T}(SQT{T}[], affine_terms, zero(T)),
    )
    _cache_qubo_backend!(model, linear_terms, quadratic_terms, zero(T))

    return nothing
end

function _copy_qubo_objective!(
    model::Virtual.Model{T},
    variable_map::Dict{VI,VI},
    obj::SAF{T},
) where {T}
    affine_terms = sizehint!(SAT{T}[], length(obj.terms))
    linear_terms = _empty_qubo_linear_terms(T, variable_map)
    quadratic_terms = Dict{Tuple{VI,VI},T}()

    for term in obj.terms
        y = variable_map[term.variable]
        c = term.coefficient

        push!(affine_terms, SAT{T}(c, y))
        _add_or_drop!(linear_terms, y, c)
    end

    MOI.set(
        model.target_model,
        MOI.ObjectiveFunction{SQF{T}}(),
        SQF{T}(SQT{T}[], affine_terms, obj.constant),
    )
    _cache_qubo_backend!(model, linear_terms, quadratic_terms, obj.constant)

    return nothing
end

function _copy_qubo_objective!(
    model::Virtual.Model{T},
    variable_map::Dict{VI,VI},
    obj::SQF{T},
) where {T}
    quadratic_terms = sizehint!(SQT{T}[], length(obj.quadratic_terms))
    affine_terms = sizehint!(SAT{T}[], length(obj.affine_terms))
    backend_linear_terms = _empty_qubo_linear_terms(T, variable_map)
    backend_quadratic_terms =
        sizehint!(Dict{Tuple{VI,VI},T}(), length(obj.quadratic_terms))

    for term in obj.quadratic_terms
        x = variable_map[term.variable_1]
        y = variable_map[term.variable_2]
        c = term.coefficient

        push!(quadratic_terms, SQT{T}(c, x, y))

        if x == y
            _add_or_drop!(backend_linear_terms, x, c / 2)
        else
            u, v = _ordered_qubo_pair(x, y)
            _add_or_drop!(backend_quadratic_terms, (u, v), c)
        end
    end

    for term in obj.affine_terms
        y = variable_map[term.variable]
        c = term.coefficient

        push!(affine_terms, SAT{T}(c, y))
        _add_or_drop!(backend_linear_terms, y, c)
    end

    MOI.set(
        model.target_model,
        MOI.ObjectiveFunction{SQF{T}}(),
        SQF{T}(quadratic_terms, affine_terms, obj.constant),
    )
    _cache_qubo_backend!(
        model,
        backend_linear_terms,
        backend_quadratic_terms,
        obj.constant,
    )

    return nothing
end

end # module Compiler
