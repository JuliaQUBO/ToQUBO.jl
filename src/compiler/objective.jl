function toqubo_sense!(model::VirtualQUBOModel, ::AbstractArchitecture)
    if MOI.get(model, MOI.ObjectiveSense()) === MOI.MAX_SENSE
        MOI.set(model.target_model, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    else
        # Feasibility is interpreted as minimization
        MOI.set(model.target_model, MOI.ObjectiveSense(), MOI.MIN_SENSE)
    end

    return nothing
end

function toqubo_objective!(model::VirtualQUBOModel, arch::AbstractArchitecture)
    F = MOI.get(model, MOI.ObjectiveFunctionType())
    f = MOI.get(model, MOI.ObjectiveFunction{F}())

    copy!(model.f, toqubo_objective(model, f, arch))

    return nothing
end

function toqubo_objective(
    model::VirtualQUBOModel{T},
    vi::VI,
    ::AbstractArchitecture,
) where {T}
    f = PBO.PBF{VI,T}()

    for (ω, c) in expansion(MOI.get(model, Source(), vi))
        f[ω] += c
    end

    return f
end

function toqubo_objective(
    model::VirtualQUBOModel{T},
    f::SAF{T},
    arch::AbstractArchitecture,
) where {T}
    return toqubo_parse(model, f, arch)
end

function toqubo_objective(
    model::VirtualQUBOModel{T},
    f::SQF{T},
    arch::AbstractArchitecture,
) where {T}
    return toqubo_parse(model, f, arch)
end