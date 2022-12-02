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
    saf::SAF{T},
    ::AbstractArchitecture,
) where {T}
    f = PBO.PBF{VI,T}()

    for t in saf.terms
        c = t.coefficient
        x = t.variable

        for (ω, d) in expansion(MOI.get(model, Source(), x))
            f[ω] += c * d
        end
    end

    f[nothing] += saf.constant

    return f
end

function toqubo_objective(
    model::VirtualQUBOModel{T},
    sqf::SQF{T},
    ::AbstractArchitecture,
) where {T}
    f = PBO.PBF{VI,T}()

    for q in sqf.quadratic_terms
        c = q.coefficient
        xi = q.variable_1
        xj = q.variable_2

        # MOI convetion is to write ScalarQuadraticFunction as
        #     ½ x' Q x + a x + b
        # ∴ every coefficient in the main diagonal is doubled
        if xi === xj
            c /= 2
        end

        for (ωᵢ, dᵢ) in expansion(MOI.get(model, Source(), xi))
            for (ωⱼ, dⱼ) in expansion(MOI.get(model, Source(), xj))
                f[union(ωᵢ, ωⱼ)] += c * dᵢ * dⱼ
            end
        end
    end

    for a in sqf.affine_terms
        c = a.coefficient
        x = a.variable

        for (ω, d) in expansion(MOI.get(model, Source(), x))
            f[ω] += c * d
        end
    end

    f[nothing] += sqf.constant

    return f
end