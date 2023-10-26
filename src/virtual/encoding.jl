function encode!(model::Model{T}, v::Variable{T}) where {T}
    x = source(v)

    if !isnothing(x)
        model.source[x] = v
    end

    for y in target(v)
        MOI.add_constraint(model.target_model, y, MOI.ZeroOne())
        model.target[y] = v
    end

    # Add variable to collection
    push!(model.variables, v)

    return v
end

function encode!(model::Model{T}, x::Union{VI,Nothing}, e::VariableEncodingMethod) where {T}
    y, ξ, χ = encode(e) do (nv::Union{Integer,Nothing} = nothing)
        if isnothing(nv)
            return MOI.add_variable(model.target_model)
        else
            return MOI.add_variables(model.target_model, nv)
        end
    end

    v = Variable{T}(e, x, y, ξ, χ)

    return encode!(model, v)
end

function encode!(
    model::Model{T},
    x::Union{VI,Nothing},
    e::VariableEncodingMethod,
    γ::AbstractVector{T},
) where {T}
    y, ξ, χ = encode(e, γ) do (nv::Union{Integer,Nothing} = nothing)
        if isnothing(nv)
            return MOI.add_variable(model.target_model)
        else
            return MOI.add_variables(model.target_model, nv)
        end
    end

    v = Variable{T}(e, x, y, ξ, χ)

    return encode!(model, v)
end

function encode!(
    model::Model{T},
    x::Union{VI,Nothing},
    e::VariableEncodingMethod,
    S::Tuple{T,T};
    tol::Union{T,Nothing} = nothing,
) where {T}
    y, ξ, χ = encode(e, S; tol) do (nv::Union{Integer,Nothing} = nothing)
        if isnothing(nv)
            return MOI.add_variable(model.target_model)
        else
            return MOI.add_variables(model.target_model, nv)
        end
    end

    v = Variable{T}(e, x, y, ξ, χ)

    return encode!(model, v)
end

function encode!(
    model::Model{T},
    x::Union{VI,Nothing},
    e::VariableEncodingMethod,
    S::Tuple{T,T},
    n::Integer,
) where {T}
    y, ξ, χ = encode(e, S, n) do (nv::Union{Integer,Nothing} = nothing)
        if isnothing(nv)
            return MOI.add_variable(model.target_model)
        else
            return MOI.add_variables(model.target_model, nv)
        end
    end

    v = Variable{T}(e, x, y, ξ, χ)

    return encode!(model, v)
end
