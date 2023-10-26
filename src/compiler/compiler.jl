module Compiler

# Imports
using MathOptInterface
const MOI = MathOptInterface

import QUBOTools: PBO
import QUBOTools: AbstractArchitecture, GenericArchitecture

import ..Encoding:
    Encoding,
    VariableEncodingMethod,
    Mirror,
    Unary,
    Binary,
    Arithmetic,
    OneHot,
    DomainWall

import ..Virtual:
    Virtual,
    encoding,
    expansion,
    penaltyfn

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

function toqubo!(model::Virtual.Model)
    arch = MOI.get(model, Attributes.Architecture())

    toqubo!(model, arch)

    return nothing
end

function toqubo!(model::Virtual.Model, arch::AbstractArchitecture)
    # reset!(model, arch) # Cleanup

    if is_qubo(model.source_model)
        _copy!(model, arch)
    else
        compile!(model, arch)
    end

    return nothing
end

toqubo(
    source::MOI.ModelLike,
    arch::Union{AbstractArchitecture,Nothing} = nothing,
    optimizer = nothing,
) = toqubo(Float64, source, arch; optimizer)

function toqubo(
    ::Type{T},
    source::MOI.ModelLike,
    arch::Union{AbstractArchitecture,Nothing} = nothing;
    optimizer = nothing,
) where {T}
    model = Virtual.Model{T}(optimizer)

    MOI.copy_to(model, source)

    if isnothing(arch)
        arch = infer_architecture(optimizer)
    end

    toqubo!(model, arch)

    return model
end

function compile!(
    model::Virtual.Model{T},
    arch::AbstractArchitecture = GenericArchitecture(),
) where {T}
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

function _copy!(model::Virtual.Model{T}, ::AbstractArchitecture) where {T}
    source_model = model.source_model
    target_model = model.target_model

    # Map Variables
    for vi in MOI.get(source_model, MOI.ListOfVariableIndices())
        Encoding.encode!(model, vi, Encoding.Mirror{T}())
    end

    # Copy Objective Sense
    s = MOI.get(source_model, MOI.ObjectiveSense())

    MOI.set(target_model, MOI.ObjectiveSense(), s)

    # Copy Objective Function
    F = MOI.get(source_model, MOI.ObjectiveFunctionType())
    f = MOI.get(source_model, MOI.ObjectiveFunction{F}())

    MOI.set(target_model, MOI.ObjectiveFunction{F}(), f)

    return nothing
end

end # module Compiler
