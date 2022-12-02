function toqubo_build!(model::VirtualQUBOModel{T}, ::AbstractArchitecture) where {T}
    # -*- Assemble Objective Function -*-
    H = sum(
        [
            model.f
            [model.ρ[ci] * g for (ci, g) in model.g]
            [model.θ[vi] * h for (vi, h) in model.h]
        ];
        init = zero(PBO.PBF{VI,T}),
    )

    # -*- Quadratization Step -*-
    H = PBO.quadratize(H) do n::Integer
        m = MOI.get(model, TargetModel())
        w = MOI.add_variables(m, n)

        MOI.add_constraint.(m, w, MOI.ZeroOne())

        return w
    end

    # -*- Write to MathOptInterface -*-
    Q = SQT{T}[]
    a = SAT{T}[]
    b = zero(T)

    for (ω, c) in H
        if isempty(ω)
            b += c
        elseif length(ω) == 1
            push!(a, SAT{T}(c, ω...))
        elseif length(ω) == 2
            push!(Q, SQT{T}(c, ω...))
        else
            # NOTE: This should never happen in production.
            # During implementation of new quadratization and constraint reformulation methods
            # higher degree terms might be introduced by mistake. That's why it's important to 
            # have this condition here.
            throw(QUBOError("Quadratization failed"))
        end
    end

    MOI.set(
        MOI.get(model, TargetModel()),
        MOI.ObjectiveFunction{SQF{T}}(),
        SQF{T}(Q, a, b),
    )

    return nothing
end