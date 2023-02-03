function toqubo_build!(model::VirtualModel{T}, arch::AbstractArchitecture) where {T}
    #  Assemble Objective Function 
    toqubo_hamiltonian!(model, arch)

    #  Quadratization Step 
    toqubo_quadratize!(model, arch)

    #  Write to MathOptInterface 
    toqubo_output!(model, arch)

    return nothing
end

function toqubo_hamiltonian!(model::VirtualModel{T}, ::AbstractArchitecture) where {T}
    empty!(model.H)

    sizehint!(model.H, MOI.get(model, MOI.NumberOfVariables())^2)

    for (ω, c) in model.f
        model.H[ω] += c
    end

    for (ci, g) in model.g
        ρ = model.ρ[ci]

        for (ω, c) in g
            model.H[ω] += ρ * c
        end
    end

    for (vi, h) in model.h
        θ = model.θ[vi]

        for (ω, c) in h
            model.H[ω] += θ * c
        end
    end

    return nothing
end

function toqubo_aux(model::VirtualModel, ::Nothing, ::AbstractArchitecture)::VI
    target_model = model.target_model

    w = MOI.add_variable(target_model)

    MOI.add_constraint(target_model, w, MOI.ZeroOne())

    return w
end

function toqubo_aux(model::VirtualModel, n::Integer, ::AbstractArchitecture)::Vector{VI}
    target_model = model.target_model

    w = MOI.add_variables(target_model, n)

    MOI.add_constraint.(target_model, w, MOI.ZeroOne())

    return w
end

function toqubo_quadratize!(model::VirtualModel, arch::AbstractArchitecture)
    if MOI.get(model, QUADRATIZE())
        method = MOI.get(model, QUADRATIZATION_METHOD())
        stable = MOI.get(model, STABLE_QUADRATIZATION())

        PBO.quadratize!(
            model.H,
            PBO.Quadratization{method}(stable),
        ) do (n::Union{Integer,Nothing} = nothing)
            return toqubo_aux(model, n, arch)
        end
    end

    return nothing
end

function toqubo_output!(model::VirtualModel{T}, ::AbstractArchitecture) where {T}
    Q = SQT{T}[]
    a = SAT{T}[]
    b = zero(T)

    for (ω, c) in model.H
        if isempty(ω)
            b += c
        elseif length(ω) == 1
            x, = ω

            push!(a, SAT{T}(c, x))
        elseif length(ω) == 2
            x, y = ω

            push!(Q, SQT{T}(c, x, y))
        else
            # NOTE: This should never happen in production.
            # During implementation of new quadratization and constraint reformulation methods
            # higher degree terms might be introduced by mistake. That's why it's important to 
            # have this condition here.
            # HINT: When debugging this, a good place to start is to check if the 'QUADRATIZE'
            # flag is set or not. If missing, it should mean that some constraint might induce
            # PBFs of higher degree without calling 'MOI.set(model, QUADRATIZE(), true)'.     
            throw(QUBOError("Quadratization failed"))
        end
    end

    MOI.set(model.target_model, MOI.ObjectiveFunction{SQF{T}}(), SQF{T}(Q, a, b))

    return nothing
end
