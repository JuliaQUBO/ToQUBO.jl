function PBO.PBF{VI,T}(model::VirtualQUBOModel{T}) where {T}
    Ω = Dict{Set{VI},T}()
    f = MOI.get(
        MOI.get(model, VM.TargetModel()),
        MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{T}}(),
    )

    for q in f.quadratic_terms
        c = q.coefficient
        xi = q.variable_1
        xj = q.variable_2

        Ω[Set{VI}([xi, xj])] = xi == xj ? c / 2 : c
    end

    for a in f.affine_terms
        c = a.coefficient
        x = a.variable

        Ω[Set{VI}([x])] = c
    end

    Ω[Set{VI}()] = f.constant

    return PBO.PBF{VI,T}(Ω)
end

function PBO.qubo(model::VirtualQUBOModel{T}, S::Type = Matrix) where {T}
    return PBO.qubo(PBO.PBF{VI,T}(model), S)
end