function build!(model::Virtual.Model{T}, arch::AbstractArchitecture) where {T}
    #  Assemble Objective Function 
    objective_function(model, arch)

    #  Quadratization Step 
    quadratize!(model, arch)

    #  Write to MathOptInterface 
    output!(model, arch)

    return nothing
end

function objective_function(model::Virtual.Model{T}, ::AbstractArchitecture) where {T}
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

function aux(model::Virtual.Model{T}, ::Nothing, ::AbstractArchitecture)::VI where {T}
    w = Encoding.encode!(model, nothing, Encoding.Mirror{T}())::Virtual.Variable{T}

    return first(Virtual.target(w))
end

function aux(model::Virtual.Model, n::Integer, arch::AbstractArchitecture)::Vector{VI}
    return VI[aux(model, nothing, arch) for _ = 1:n]
end

function quadratize!(model::Virtual.Model, arch::AbstractArchitecture)
    if MOI.get(model, Attributes.Quadratize())
        method = Attributes.quadratization_method(model)
        stable = Attributes.stable_quadratization(model)

        quad = PBO.Quadratization(method; stable)

        if MOI.get(model, MOI.ObjectiveSense()) === MOI.MAX_SENSE
            # NOTE: Here it is necessary to invert the sign of the
            # Hamiltonian since PBO adopts the minimization sense
            # convention.
            # TODO: Add an in-place version of 'quadratize!' that 
            # provides support for maximization problems.
            let H = PBO.quadratize!(-model.H, quad) do (n::Union{Integer,Nothing} = nothing)
                    return aux(model, n, arch)
                end

                # NOTE: This setup leads to avoidable allocations.
                Base.copy!(model.H, -H)
            end
        else # === MOI.MIN_SENSE || === MOI.FEASIBILITY
            PBO.quadratize!(model.H, quad) do (n::Union{Integer,Nothing} = nothing)
                return aux(model, n, arch)
            end
        end
    end

    return nothing
end

function output!(model::Virtual.Model{T}, ::AbstractArchitecture) where {T}
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
