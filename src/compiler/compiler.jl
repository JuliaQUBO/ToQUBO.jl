module Compiler

import ..ToQUBO:
    PBO,
    Attributes,
    VirtualModel,
    AbstractArchitecture,
    GenericArchitecture,
    encode!,
    encoding,
    expansion,
    penaltyfn,
    is_aux,
    Encoding,
    Mirror,
    Unary,
    Binary,
    Arithmetic,
    OneHot,
    DomainWall,
    MOI,
    VI,
    SAT,
    SAF,
    SQT,
    SQF,
    EQ,
    LT,
    GT

include("analysis.jl")
include("interface.jl")
include("parse.jl")
include("variables.jl")
include("objective.jl")
include("constraints.jl")
include("penalties.jl")
include("build.jl")

# toqubo: MOI.ModelLike -> QUBO.Model 
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
    model = VirtualModel{T}(optimizer)

    MOI.copy_to(model, source)

    if isnothing(arch)
        arch = infer_architecture(optimizer)
    end

    toqubo!(model, arch)

    return model
end

function toqubo!(
    model::VirtualModel{T},
    arch::AbstractArchitecture = GenericArchitecture(),
) where {T}
    # Cleanup
    _empty!(model, arch)

    if is_qubo(model.source_model)
        _copy!(model, arch)

        return nothing
    end

    compile!(model, arch)

    return nothing
end

function _copy!(model::VirtualModel{T}, ::AbstractArchitecture) where {T}
    source_model = model.source_model
    target_model = model.target_model

    # Map Variables
    for vi in MOI.get(source_model, MOI.ListOfVariableIndices())
        encode!(model, Mirror(), vi)
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

function compile!(
    model::VirtualModel{T},
    arch::AbstractArchitecture = GenericArchitecture(),
) where {T}
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

function _empty!(model::VirtualModel, ::AbstractArchitecture = GenericArchitecture())
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

end # module Compiler