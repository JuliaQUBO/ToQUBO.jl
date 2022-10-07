include("architectures.jl")
include("interface.jl")
include("validation.jl")
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
    model = VirtualQUBOModel{T}(optimizer)

    MOI.copy_to(model, source)

    if isnothing(arch)
        arch = infer_architecture(optimizer)
    end

    toqubo!(model, arch)

    return model
end

function toqubo!(
    model::VirtualQUBOModel{T},
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