function build!(model::Virtual.Model{T}, arch::AbstractArchitecture) where {T}
    #  Assemble Objective Function 
    objective_function(model, arch)

    #  Quadratization Step 
    quadratize!(model, arch)

    #  Write to MathOptInterface 
    output!(model, arch)

    return nothing
end

# Function barrier: concrete per-PBF loop. `factor === nothing` adds coefficients
# unscaled (the objective), exactly as `H[ω] += c`; otherwise `H[ω] += factor * c`.
function _accumulate_scaled!(H::PBO.PBF, p::PBO.PBF, factor)
    for (ω, c) in _term_slots(p)
        H[ω] += isnothing(factor) ? c : factor * c
    end
    return H
end

function objective_function(model::Virtual.Model{T}, ::AbstractArchitecture) where {T}
    Base.empty!(model.H)

    # Calculate an upper bound on the number of terms
    num_terms = +(
        length(model.f),
        sum(length, model.g; init = 0),
        sum(length, model.h; init = 0),
        sum(length, model.s; init = 0),
    )

    sizehint!(model.H, num_terms)

    # `_term_slots` visits terms in the PBFs' own iteration order, so every
    # floating-point accumulation below happens in the same order as before.
    _accumulate_scaled!(model.H, model.f, nothing)

    for (ci, g) in model.g
        ρ = MOI.get(model, Attributes.ConstraintEncodingPenalty(), ci)
        _accumulate_scaled!(model.H, g, ρ)
    end

    for (vi, h) in model.h
        θ = MOI.get(model, Attributes.VariableEncodingPenalty(), vi)
        _accumulate_scaled!(model.H, h, θ)
    end

    for (ci, s) in model.s
        η = MOI.get(model, Attributes.SlackVariableEncodingPenalty(), ci)
        _accumulate_scaled!(model.H, s, η)
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

        sign = MOI.get(model, MOI.ObjectiveSense()) === MOI.MAX_SENSE ? -1 : 1
        quad = PBO.Quadratization(method; stable, sign)

        PBO.quadratize!(model.H, quad) do (n::Union{Integer,Nothing} = nothing)
            return aux(model, n, arch)
        end
    end

    return nothing
end

function output!(model::Virtual.Model{T}, ::AbstractArchitecture) where {T}
    Q = SQT{T}[]
    a = SAT{T}[]
    # Capacity only; terms are pushed in the same order as before.
    sizehint!(Q, length(model.H))

    b, ok = _output_terms!(Q, a, model.H)

    if !ok
        # NOTE: This should never happen in production.
        # During implementation of new quadratization and constraint reformulation methods
        # higher degree terms might be introduced by mistake. That's why it's important to 
        # have this condition here.
        # HINT: When debugging this, a good place to start is to check if the 'Quadratize'
        # flag is set or not. If missing, it should mean that some constraint might induce
        # PBFs of higher degree without calling
        #     MOI.set(model, AttributesQuadratize(), true)
        compilation_error!(
            model,
            "Fatal: Quadratization failed";
            status="Failure in quadratization",
        )
    end

    MOI.set(model.target_model, MOI.ObjectiveFunction{SQF{T}}(), SQF{T}(Q, a, b))

    return nothing
end

# Per-term kernel of `output!`. `model.H` is abstractly typed, so this call is
# the barrier that lets the loop specialize. Returns the constant and `false`
# when a term of degree above two is present.
function _output_terms!(Q::Vector{SQT{T}}, a::Vector{SAT{T}}, H::PBO.PBF) where {T}
    b = zero(T)

    for (ω, c) in _term_slots(H)
        if isempty(ω)
            b += c
        elseif length(ω) == 1
            x, = ω

            push!(a, SAT{T}(c, x))
        elseif length(ω) == 2
            x, y = ω

            push!(Q, SQT{T}(c, x, y))
        else
            return b, false
        end
    end

    return b, true
end
