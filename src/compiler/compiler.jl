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
    Base.empty!(model.variables)
    Base.empty!(model.source)
    Base.empty!(model.target)

    # PBF/IR
    Base.empty!(model.f)
    Base.empty!(model.g)
    Base.empty!(model.h)
    Base.empty!(model.ρ)
    Base.empty!(model.θ)

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
