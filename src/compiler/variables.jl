function variables!(model::Virtual.Model{T}, ::AbstractArchitecture) where {T}
    # Set of all source variables
    Ω = Vector{VI}(MOI.get(model, MOI.ListOfVariableIndices()))

    # Variable Sets and Bounds (Boolean, Integer, Real)
    𝔹 = Vector{VI}()
    ℤ = Dict{VI,Tuple{Union{T,Nothing},Union{T,Nothing}}}()
    ℝ = Dict{VI,Tuple{Union{T,Nothing},Union{T,Nothing}}}()
    semiinteger = Dict{VI,Tuple{T,T}}()
    semicontinuous = Dict{VI,Tuple{T,T}}()

    for ci in MOI.get(model, MOI.ListOfConstraintIndices{VI,MOI.ZeroOne}())
        # Binary Variable
        x = MOI.get(model, MOI.ConstraintFunction(), ci)

        # Add to set
        push!(𝔹, x)
    end

    for ci in MOI.get(model, MOI.ListOfConstraintIndices{VI,MOI.Integer}())
        # Integer Variable
        x = MOI.get(model, MOI.ConstraintFunction(), ci)

        # Add to dict as unbounded
        ℤ[x] = (nothing, nothing)
    end

    for ci in MOI.get(model, MOI.ListOfConstraintIndices{VI,MOI.Semiinteger{T}}())
        # Semi-integer Variable
        x = MOI.get(model, MOI.ConstraintFunction(), ci)
        s = MOI.get(model, MOI.ConstraintSet(), ci)

        semiinteger[x] = (s.lower, s.upper)
    end

    for ci in MOI.get(model, MOI.ListOfConstraintIndices{VI,MOI.Semicontinuous{T}}())
        # Semi-continuous Variable
        x = MOI.get(model, MOI.ConstraintFunction(), ci)
        s = MOI.get(model, MOI.ConstraintSet(), ci)

        semicontinuous[x] = (s.lower, s.upper)
    end

    for x in setdiff(Ω, 𝔹, keys(ℤ), keys(semiinteger), keys(semicontinuous))
        # Real Variable
        ℝ[x] = (nothing, nothing)
    end

    for ci in MOI.get(model, MOI.ListOfConstraintIndices{VI,MOI.Interval{T}}())
        # Interval
        x = MOI.get(model, MOI.ConstraintFunction(), ci)
        s = MOI.get(model, MOI.ConstraintSet(), ci)

        a = s.lower
        b = s.upper

        if haskey(ℤ, x)
            ℤ[x] = (a, b)
        elseif haskey(ℝ, x)
            ℝ[x] = (a, b)
        end
    end

    for ci in MOI.get(model, MOI.ListOfConstraintIndices{VI,LT{T}}())
        # Upper Bound
        x = MOI.get(model, MOI.ConstraintFunction(), ci)
        s = MOI.get(model, MOI.ConstraintSet(), ci)

        b = s.upper

        if haskey(ℤ, x)
            ℤ[x] = (first(ℤ[x]), b)
        elseif haskey(ℝ, x)
            ℝ[x] = (first(ℝ[x]), b)
        end
    end

    for ci in MOI.get(model, MOI.ListOfConstraintIndices{VI,GT{T}}())
        # Lower Bound
        x = MOI.get(model, MOI.ConstraintFunction(), ci)
        s = MOI.get(model, MOI.ConstraintSet(), ci)

        a = s.lower

        if haskey(ℤ, x)
            ℤ[x] = (a, last(ℤ[x]))
        elseif haskey(ℝ, x)
            ℝ[x] = (a, last(ℝ[x]))
        end
    end

    if Attributes.stable_compilation(model)
        sort!(Ω; by = x -> x.value)
    end
    
    # Encode Variables
    for x in Ω
        # If variable was already encoded, skip
        if haskey(model.source, x)
            continue
        end

        if haskey(semiinteger, x)
            variable_semiinteger!(model, x, semiinteger[x])
        elseif haskey(semicontinuous, x)
            variable_semicontinuous!(model, x, semicontinuous[x])
        elseif haskey(ℤ, x)
            variable_ℤ!(model, x, ℤ[x])
        elseif haskey(ℝ, x)
            variable_ℝ!(model, x, ℝ[x])
        else # x ∈ 𝔹
            variable_𝔹!(model, x)
        end
    end

    return nothing
end

function variable_𝔹!(model::Virtual.Model{T}, i::Union{VI,CI}) where {T}
    return Encoding.encode!(model, i, Encoding.Mirror{T}())
end

function variable_semiinteger!(
    model::Virtual.Model{T},
    vi::VI,
    S::Tuple{T,T},
) where {T}
    e = Attributes.variable_encoding_method(model, vi)

    MOI.set(model, Attributes.Quadratize(), true)

    return Encoding.encode!(model, vi, Encoding.Semi(e), S)
end

function variable_semicontinuous!(
    model::Virtual.Model{T},
    vi::VI,
    S::Tuple{T,T},
) where {T}
    e = Attributes.variable_encoding_method(model, vi)
    n = Attributes.variable_encoding_bits(model, vi)

    MOI.set(model, Attributes.Quadratize(), true)

    if !isnothing(n)
        return Encoding.encode!(model, vi, Encoding.Semi(e), S, n)
    else
        tol = Attributes.variable_encoding_atol(model, vi)

        return Encoding.encode!(model, vi, Encoding.Semi(e), S; tol)
    end
end

function variable_ℤ!(model::Virtual.Model{T}, vi::VI, (a, b)::Tuple{A,B}) where {T,A<:Union{T,Nothing},B<:Union{T,Nothing}}
    if !isnothing(a) && !isnothing(b)
        let e = Attributes.variable_encoding_method(model, vi)
            S = (a, b)

            return Encoding.encode!(model, vi, e, S)
        end
    elseif !isnothing(b)
        error("Unbounded variable $(vi) ∈ (-∞, $(b)] ⊂ ℤ ")
    elseif !isnothing(a)
        error("Unbounded variable $(vi) ∈ [$(a), +∞) ⊂ ℤ")
    else
        error("Unbounded variable $(vi) ∈ ℤ")
    end
end

function variable_ℤ!(model::Virtual.Model{T}, ci::CI, (a, b)::Tuple{T,T}) where {T}
    if isnothing(a) || isnothing(b)
        error("Unbounded variable $(ci) ∈ ℤ")
    else
        let e = Attributes.slack_variable_encoding_method(model, ci)
            S = (a, b)

            return Encoding.encode!(model, ci, e, S)
        end
    end
end

function variable_ℝ!(model::Virtual.Model{T}, vi::VI, (a, b)::Tuple{A,B}) where {T,A<:Union{T,Nothing},B<:Union{T,Nothing}}
    if !isnothing(a) && !isnothing(b)
        # TODO: Solve this bit-guessing magic??? (DONE)
        # IDEA: 
        #     Let x̂ ~ U[a, b], K = 2ᴺ, γ = [a, b]
        #       𝔼[|xᵢ - x̂|] = ∫ᵧ |xᵢ - x̂| f(x̂) dx̂
        #                   = 1 / |b - a| ∫ᵧ |xᵢ - x̂| dx̂
        #                   = |b - a| / 4 (K - 1)
        #
        #     For 𝔼[|xᵢ - x̂|] ≤ τ we have
        #       N ≥ log₂(1 + |b - a| / 4τ)
        # 
        # where τ is the (absolute) tolerance
        # TODO: Add τ as parameter (DONE)
        # TODO: Move this comment to the documentation
        let e = Attributes.variable_encoding_method(model, vi)
            n = Attributes.variable_encoding_bits(model, vi)
            S = (a, b)

            if !isnothing(n)
                return Encoding.encode!(model, vi, e, S, n)
            else
                tol = Attributes.variable_encoding_atol(model, vi)

                return Encoding.encode!(model, vi, e, S; tol)
            end
        end
    elseif !isnothing(b)
        error("Unbounded variable $(vi) ∈ (-∞, $(b)]")
    elseif !isnothing(a)
        error("Unbounded variable $(vi) ∈ [$(a), +∞)")
    else
        error("Unbounded variable $(vi) ∈ ℝ")
    end
end

function variable_ℝ!(model::Virtual.Model{T}, ci::CI, (a, b)::Tuple{T,T}) where {T}
    if isnothing(a) || isnothing(b)
        error("Unbounded slack variable $(ci) ∈ ℝ")
    else
        let e = Attributes.slack_variable_encoding_method(model, ci)
            n = Attributes.slack_variable_encoding_bits(model, ci)
            S = (a, b)

            if !isnothing(n)
                return Encoding.encode!(model, ci, e, S, n)
            else
                tol = Attributes.slack_variable_encoding_atol(model, ci)

                return Encoding.encode!(model, ci, e, S; tol)
            end
        end
    end
end
