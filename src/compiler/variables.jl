function variables!(model::Virtual.Model{T}, ::AbstractArchitecture) where {T}
    # Set of all source variables
    Ω = Vector{VI}(MOI.get(model, MOI.ListOfVariableIndices()))

    # Variable Sets and Bounds (Boolean, Integer, Real)
    𝔹 = Vector{VI}()
    ℤ = Dict{VI,Tuple{Union{T,Nothing},Union{T,Nothing}}}()
    ℝ = Dict{VI,Tuple{Union{T,Nothing},Union{T,Nothing}}}()

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

    for x in setdiff(Ω, 𝔹, keys(ℤ))
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

    # Encode Variables
    if Attributes.stable_compilation(model)
        sort!(Ω; by = x -> x.value)
    end

    for x in Ω
        if haskey(ℤ, x)
            variable_ℤ!(model, x, ℤ[x])
        elseif haskey(ℝ, x)
            variable_ℝ!(model, x, ℝ[x])
        else # x ∈ 𝔹
            variable_𝔹!(model, x)
        end
    end

    return nothing
end

function variable_𝔹!(model::Virtual.Model{T}, x::VI) where {T}
    Encoding.encode!(model, x, Mirror{T}())

    return nothing
end

function variable_ℤ!(model::Virtual.Model{T}, x::VI, (a, b)::Tuple{A,B}) where {T,A<:Union{T,Nothing},B<:Union{T,Nothing}}
    if !isnothing(a) && !isnothing(b)
        let e = Attributes.variable_encoding_method(model, x)
            S = (a, b)

            Encoding.encode!(model, x, e, S)
        end
    elseif !isnothing(b)
        error("Unbounded variable $(x) ∈ (-∞, $(b)] ⊂ ℤ ")
    elseif !isnothing(a)
        error("Unbounded variable $(x) ∈ [$(a), +∞) ⊂ ℤ")
    else
        error("Unbounded variable $(x) ∈ ℤ")
    end

    return nothing
end

function variable_ℝ!(model::Virtual.Model{T}, x::VI, (a, b)::Tuple{A,B}) where {T,A<:Union{T,Nothing},B<:Union{T,Nothing}}
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
        let e = Attributes.variable_encoding_method(model, x)
            n = Attributes.variable_encoding_bits(model, x)
            S = (a, b)

            if !isnothing(n)
                Encoding.encode!(model, x, e, S, n)
            else
                tol = Attributes.variable_encoding_atol(model, x)

                Encoding.encode!(model, x, e, S; tol)
            end
        end
    elseif !isnothing(b)
        error("Unbounded variable $(x) ∈ (-∞, $(b)]")
    elseif !isnothing(a)
        error("Unbounded variable $(x) ∈ [$(a), +∞)")
    else
        @info "Source Model:"
        println(model.source_model)
        
        error("Unbounded variable $(x) ∈ ℝ")
    end

    return nothing
end
