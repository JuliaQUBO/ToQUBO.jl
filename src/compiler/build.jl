function build!(model::VirtualModel{T}, arch::AbstractArchitecture) where {T}
    #  Assemble Objective Function 
    hamiltonian!(model, arch)

    #  Quadratization Step 
    quadratize!(model, arch)

    #  Write to MathOptInterface 
    output!(model, arch)

    return nothing
end

function hamiltonian!(model::VirtualModel{T}, ::AbstractArchitecture) where {T}
    empty!(model.H)

    # Calculate an upper bound on the number of terms
    num_terms =
        length(model.f) + sum(length, model.g; init = 0) + sum(length, model.h; init = 0)

    sizehint!(model.H, num_terms)

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

function aux(model::VirtualModel, ::Nothing, ::AbstractArchitecture)::VI
    target_model = model.target_model

    w = MOI.add_variable(target_model)

    MOI.add_constraint(target_model, w, MOI.ZeroOne())

    return w
end

function aux(model::VirtualModel, n::Integer, ::AbstractArchitecture)::Vector{VI}
    target_model = model.target_model

    w = MOI.add_variables(target_model, n)

    MOI.add_constraint.(target_model, w, MOI.ZeroOne())

    return w
end

function quadratize!(model::VirtualModel, arch::AbstractArchitecture)
    if MOI.get(model, Attributes.Quadratize())
        method = MOI.get(model, Attributes.QuadratizationMethod())
        stable = MOI.get(model, Attributes.StableQuadratization())

        PBO.quadratize!(
            model.H,
            PBO.Quadratization{method}(stable),
        ) do (n::Union{Integer,Nothing} = nothing)
            return aux(model, n, arch)
        end
    end

    return nothing
end

function output!(model::VirtualModel{T}, ::AbstractArchitecture) where {T}
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
            # HINT: When debugging this, a good place to start is to check if the 'Quadratize'
            # flag is set or not. If missing, it should mean that some constraint might induce
            # PBFs of higher degree without calling 'MOI.set(model, Quadratize(), true)'.     
            compilation_error("Quadratization failed")
        end
    end

    MOI.set(model.target_model, MOI.ObjectiveFunction{SQF{T}}(), SQF{T}(Q, a, b))

    return nothing
end
