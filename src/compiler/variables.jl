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

    _sos1_domain_wall_variables!(model, Set(𝔹))

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
    _reject_value_set!(model, i, "binary")

    return Encoding.encode!(model, i, Encoding.Mirror{T}())
end

function _reject_value_set!(model::Virtual.Model, i::Union{VI,CI}, kind::String)
    if i isa VI && !isnothing(Attributes.variable_encoding_set(model, i))
        compilation_error!(
            model,
            "Value sets are not supported for $(kind) variables; found one on variable '$(i)'";
            status = "Value set on $(kind) variable",
        )
    end

    return nothing
end

# Encodes a variable over an explicit finite value set through a set encoding
# method (one-hot, domain-wall). The set replaces the bounds-derived domain;
# explicit bounds, when present, must contain every entry.
function variable_set!(
    model::Virtual.Model{T},
    vi::VI,
    γ::Vector{T},
    (a, b)::Tuple{A,B};
    integer::Bool,
) where {T,A<:Union{T,Nothing},B<:Union{T,Nothing}}
    e = Attributes.variable_encoding_method(model, vi)

    if !(e isa Encoding.SetVariableEncodingMethod)
        compilation_error!(
            model,
            "Variable encoding method '$(nameof(typeof(e)))' does not support value sets; " *
            "choose a set encoding such as 'Encoding.OneHot' or 'Encoding.DomainWall' " *
            "for variable '$(vi)'";
            status = "Value set requires a set encoding method",
        )
    elseif isempty(γ)
        compilation_error!(
            model,
            "Value set for variable '$(vi)' is empty";
            status = "Empty value set",
        )
    elseif !all(isfinite, γ)
        compilation_error!(
            model,
            "Value set for variable '$(vi)' contains non-finite entries";
            status = "Non-finite value set",
        )
    elseif !allunique(γ)
        compilation_error!(
            model,
            "Value set for variable '$(vi)' contains duplicate entries";
            status = "Duplicate value set entries",
        )
    elseif integer && !all(isinteger, γ)
        compilation_error!(
            model,
            "Value set for integer variable '$(vi)' must contain only integer values";
            status = "Non-integer value set entries",
        )
    elseif (!isnothing(a) && any(v -> v < a, γ)) || (!isnothing(b) && any(v -> v > b, γ))
        compilation_error!(
            model,
            "Value set for variable '$(vi)' has entries outside its declared bounds " *
            "[$(isnothing(a) ? "-∞" : a), $(isnothing(b) ? "+∞" : b)]";
            status = "Value set outside variable bounds",
        )
    end

    return Encoding.encode!(model, vi, e, γ)
end

function _sos1_variable_counts(model::Virtual.Model{T}) where {T}
    counts = Dict{VI,Int}()

    for ci in MOI.get(
        model,
        MOI.ListOfConstraintIndices{MOI.VectorOfVariables,MOI.SOS1{T}}(),
    )
        x = MOI.get(model, MOI.ConstraintFunction(), ci)

        for xi in x.variables
            counts[xi] = get(counts, xi, 0) + 1
        end
    end

    return counts
end

function _sos1_domain_wall_penalty(::Type{T}, y::Vector{VI}) where {T}
    two = T(2)

    return PBO.PBF{VI,T}(
        [
            [y[i] => two for i = 2:length(y)]
            [(y[i], y[i+1]) => -two for i = 1:(length(y)-1)]
        ],
    )
end

function _sos1_domain_wall_expansion(::Type{T}, y::Vector{VI}, i::Integer) where {T}
    if i == length(y)
        return PBO.PBF{VI,T}(y[i] => one(T))
    else
        return PBO.PBF{VI,T}([y[i] => one(T), y[i+1] => -one(T)])
    end
end

function _encode_sos1_domain_wall!(
    model::Virtual.Model{T},
    ci::CI{MOI.VectorOfVariables,MOI.SOS1{T}},
    x::Vector{VI},
) where {T}
    y = MOI.add_variables(model.target_model, length(x))
    e = Encoding.DomainWall{T}()
    v = Virtual.Variable{T}(e, ci, y, PBO.PBF{VI,T}(), nothing)

    Encoding.encode!(model, v)

    for i in eachindex(x)
        ξ = _sos1_domain_wall_expansion(T, y, i)
        v = Virtual.Variable{T}(e, x[i], VI[], ξ, nothing)

        Encoding.encode!(model, v)
    end

    return nothing
end

function _sos1_domain_wall_variables!(
    model::Virtual.Model{T},
    binary_variables::Set{VI},
) where {T}
    counts = _sos1_variable_counts(model)

    for ci in MOI.get(
        model,
        MOI.ListOfConstraintIndices{MOI.VectorOfVariables,MOI.SOS1{T}}(),
    )
        x = MOI.get(model, MOI.ConstraintFunction(), ci)

        if length(x.variables) <= 1
            continue
        end

        if all(
            xi -> xi in binary_variables && !haskey(model.source, xi) && counts[xi] == 1,
            x.variables,
        )
            _encode_sos1_domain_wall!(model, ci, x.variables)
        end
    end

    return nothing
end

function variable_semiinteger!(
    model::Virtual.Model{T},
    vi::VI,
    S::Tuple{T,T},
) where {T}
    _reject_value_set!(model, vi, "semi-integer")

    e = Attributes.variable_encoding_method(model, vi)

    MOI.set(model, Attributes.Quadratize(), true)

    return Encoding.encode!(model, vi, Encoding.Semi(e), S)
end

function variable_semicontinuous!(
    model::Virtual.Model{T},
    vi::VI,
    S::Tuple{T,T},
) where {T}
    _reject_value_set!(model, vi, "semi-continuous")

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
    let γ = Attributes.variable_encoding_set(model, vi)
        if !isnothing(γ)
            return variable_set!(model, vi, γ, (a, b); integer = true)
        end
    end

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
    let γ = Attributes.variable_encoding_set(model, vi)
        if !isnothing(γ)
            return variable_set!(model, vi, γ, (a, b); integer = false)
        end
    end

    if !isnothing(a) && !isnothing(b)
        # Tolerance-based bit inference is documented in the Representation
        # Error section of the encoding booklet.
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
