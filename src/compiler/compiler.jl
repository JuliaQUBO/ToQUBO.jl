include("analysis.jl")
include("architectures.jl")
include("interface.jl")
include("validation.jl")
include("parse.jl")
include("variables.jl")
include("objective.jl")
include("constraints.jl")
include("penalties.jl")
include("build.jl")

# -*- toqubo: MOI.ModelLike -> QUBO.Model -*-
toqubo(
    source::MOI.ModelLike,
    arch::Union{AbstractArchitecture,Nothing} = nothing,
    optimizer = nothing,
) = toqubo(Float64, source, arch; optimizer = optimizer)


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
    if is_qubo(model.source_model)
        toqubo_copy!(model, arch)

        return nothing
    end

    toqubo_compile!(model, arch)

    return nothing
end

function toqubo_copy!(
    model::VirtualModel{T},
    ::AbstractArchitecture,
) where {T}
    source_model = model.source_model
    target_model = model.target_model

    # Map Variables
    for vi in MOI.get(source_model, MOI.ListOfVariableIndices())
        encode!(Mirror(), model, vi)
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

function toqubo_compile!(
    model::VirtualModel{T},
    arch::AbstractArchitecture = GenericArchitecture(),
) where {T}
    # :: Objective Sense :: #
    toqubo_sense!(model, arch)

    # :: Problem Variables :: #
    toqubo_variables!(model, arch)

    # :: Objective Analysis :: #
    toqubo_objective!(model, arch)

    # :: Add Regular Constraints :: #
    toqubo_constraints!(model, arch)

    # :: Add Encoding Constraints :: #
    toqubo_encoding_constraints!(model, arch)

    # :: Compute penalties :: #
    toqubo_penalties!(model, arch)

    # :: Build Final Model :: #
    toqubo_build!(model, arch)

    return nothing
end