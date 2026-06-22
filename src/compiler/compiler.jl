module Compiler

# Imports
import MathOptInterface as MOI
import MathOptInterface: empty!
import PseudoBooleanOptimization as PBO

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
    _copy_qubo_hamiltonian!(model)
    _output_qubo_objective!(model)

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

function _qubo_term(x::VI)
    return PBO.Term{VI}(VI[x])
end

function _qubo_term(x::VI, y::VI)
    if x.value <= y.value
        return PBO.Term{VI}(VI[x, y])
    else
        return PBO.Term{VI}(VI[y, x])
    end
end

function _add_qubo_affine_term!(f::PBO.PBF{VI,T}, variable_map, a::SAT{T}) where {T}
    f[_qubo_term(variable_map[a.variable])] += a.coefficient

    return nothing
end

function _add_qubo_quadratic_term!(f::PBO.PBF{VI,T}, variable_map, q::SQT{T}) where {T}
    x = variable_map[q.variable_1]
    y = variable_map[q.variable_2]
    c = q.coefficient

    if x == y
        # MOI stores diagonal quadratic terms with doubled coefficients for
        # pseudo-boolean variables because x^2 == x.
        f[_qubo_term(x)] += c / 2
    else
        f[_qubo_term(x, y)] += c
    end

    return nothing
end

function _copy_qubo_function!(
    f::PBO.PBF{VI,T},
    variable_map,
    vi::VI,
) where {T}
    f[_qubo_term(variable_map[vi])] += one(T)

    return nothing
end

function _copy_qubo_function!(
    f::PBO.PBF{VI,T},
    variable_map,
    obj::SAF{T},
) where {T}
    sizehint!(f, length(obj.terms) + 1)

    for a in obj.terms
        _add_qubo_affine_term!(f, variable_map, a)
    end

    f[nothing] += obj.constant

    return nothing
end

function _copy_qubo_function!(
    f::PBO.PBF{VI,T},
    variable_map,
    obj::SQF{T},
) where {T}
    sizehint!(f, length(obj.quadratic_terms) + length(obj.affine_terms) + 1)

    for q in obj.quadratic_terms
        _add_qubo_quadratic_term!(f, variable_map, q)
    end

    for a in obj.affine_terms
        _add_qubo_affine_term!(f, variable_map, a)
    end

    f[nothing] += obj.constant

    return nothing
end

function _copy_qubo_objective!(model::Virtual.Model{T}, variable_map) where {T}
    F = MOI.get(model.source_model, MOI.ObjectiveFunctionType())
    f = MOI.get(model.source_model, MOI.ObjectiveFunction{F}())

    _copy_qubo_function!(model.f, variable_map, f)

    return nothing
end

function _copy_qubo_hamiltonian!(model::Virtual.Model)
    Base.copy!(model.H, model.f)

    return nothing
end

function _output_qubo_objective!(model::Virtual.Model{T}) where {T}
    Q = SQT{T}[]
    a = SAT{T}[]
    b = zero(T)

    for (ω, c) in model.H
        if isempty(ω)
            b += c
        elseif length(ω) == 1
            x, = ω

            push!(a, SAT{T}(c, x))
        elseif length(ω) == 2
            x, y = ω

            push!(Q, SQT{T}(c, x, y))
        else
            compilation_error!(
                model,
                "Fatal: QUBO fast path produced a higher-order term";
                status="Failure in QUBO fast path",
            )
        end
    end

    MOI.set(model.target_model, MOI.ObjectiveFunction{SQF{T}}(), SQF{T}(Q, a, b))

    return nothing
end

end # module Compiler
