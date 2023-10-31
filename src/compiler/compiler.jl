module Compiler

# Imports
using MathOptInterface
const MOI = MathOptInterface

import QUBOTools: PBO
import QUBOTools: AbstractArchitecture, GenericArchitecture

import ..Encoding:
    Encoding, VariableEncodingMethod, Mirror, Unary, Binary, Arithmetic, OneHot, DomainWall

import ..Virtual: Virtual, encoding, expansion, penaltyfn

import ..Attributes

# Constants
const VI     = MOI.VariableIndex
const SAT{T} = MOI.ScalarAffineTerm{T}
const SAF{T} = MOI.ScalarAffineFunction{T}
const SQT{T} = MOI.ScalarQuadraticTerm{T}
const SQF{T} = MOI.ScalarQuadraticFunction{T}
const EQ{T}  = MOI.EqualTo{T}
const LT{T}  = MOI.LessThan{T}
const GT{T}  = MOI.GreaterThan{T}

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

    # Add Encoding Constraints
    encoding_constraints!(model, arch)

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
    empty!(model.variables)
    empty!(model.source)
    empty!(model.target)

    # PBF/IR
    empty!(model.f)
    empty!(model.g)
    empty!(model.h)
    empty!(model.ρ)
    empty!(model.θ)

    return nothing
end

function Compiler.copy!(model::Virtual.Model{T}, ::AbstractArchitecture) where {T}
    # Map Variables
    for vi in MOI.get(model.source_model, MOI.ListOfVariableIndices())
        Encoding.encode!(model, vi, Encoding.Mirror{T}())
    end

    # Copy Objective Sense
    let s = MOI.get(model.source_model, MOI.ObjectiveSense())
        MOI.set(model.target_model, MOI.ObjectiveSense(), s)
    end

    # Copy Objective Function
    let F = MOI.get(model.source_model, MOI.ObjectiveFunctionType())
        f = MOI.get(model.source_model, MOI.ObjectiveFunction{F}())

        MOI.set(model.target_model, MOI.ObjectiveFunction{F}(), f)
    end

    return nothing
end

end # module Compiler
