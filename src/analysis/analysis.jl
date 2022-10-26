function QUBOTools.backend(model::VirtualQUBOModel{T}) where {T}
    L = Dict{VI,T}()
    Q = Dict{Tuple{VI,VI},T}()
    f = MOI.get(
        MOI.get(model, VM.TargetModel()),
        MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{T}}(),
    )

    for q in f.quadratic_terms
        c  = q.coefficient
        xi = q.variable_1
        xj = q.variable_2

        if xi == xj
            L[xi] = get(L, xi, zero(T)) + c / 2
        else
            Q[(xi, xj)] = get(Q, (xi, xj), zero(T)) + c
        end
    end

    for a in f.affine_terms
        c = a.coefficient
        x = a.variable

        L[x] =  get(L, x, zero(T)) + c
    end

    offset = f.constant

    return QUBOTools.StandardQUBOModel{QUBOTools.𝔹,VI,T,Int}(
        L,
        Q;
        offset=offset,
    )
end