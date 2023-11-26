function Encoding.encode!(model::Model{T}, v::Variable{T}) where {T}
    x = source(v)
    χ = penaltyfn(v)

    if x isa VI
        model.source[x] = v

        if !isnothing(χ)
            model.h[x] = χ
        end
    elseif x isa CI
        model.slack[x] = v
        
        if !isnothing(χ)
            model.s[x] = χ
        end
    end

    for y in target(v)
        MOI.add_constraint(model.target_model, y, MOI.ZeroOne())
        model.target[y] = v
    end

    # Add variable to collection
    push!(model.variables, v)

    return v
end

function Encoding.encode!(
    model::Model{T},
    x::Union{VI,CI,Nothing},
    e::VariableEncodingMethod,
) where {T}
    y, ξ, χ = Encoding.encode(e) do (nv::Union{Integer,Nothing} = nothing)
        if isnothing(nv)
            return MOI.add_variable(model.target_model)
        else
            return MOI.add_variables(model.target_model, nv)
        end
    end

    v = Variable{T}(e, x, y, ξ, χ)

    return Encoding.encode!(model, v)
end

function Encoding.encode!(
    model::Model{T},
    x::Union{VI,CI,Nothing},
    e::VariableEncodingMethod,
    γ::AbstractVector{T},
) where {T}
    y, ξ, χ = Encoding.encode(e, γ) do (nv::Union{Integer,Nothing} = nothing)
        if isnothing(nv)
            return MOI.add_variable(model.target_model)
        else
            return MOI.add_variables(model.target_model, nv)
        end
    end

    v = Variable{T}(e, x, y, ξ, χ)

    return Encoding.encode!(model, v)
end

function encode!(
    model::Model{T},
    x::Union{VI,CI,Nothing},
    e::VariableEncodingMethod,
    S::Tuple{T,T};
    tol::Union{T,Nothing} = nothing,
) where {T}
    y, ξ, χ = Encoding.encode(e, S; tol) do (nv::Union{Integer,Nothing} = nothing)
        if isnothing(nv)
            return MOI.add_variable(model.target_model)
        else
            return MOI.add_variables(model.target_model, nv)
        end
    end

    v = Variable{T}(e, x, y, ξ, χ)

    return Encoding.encode!(model, v)
end

function Encoding.encode!(
    model::Model{T},
    x::Union{VI,CI,Nothing},
    e::VariableEncodingMethod,
    S::Tuple{T,T},
    n::Integer,
) where {T}
    y, ξ, χ = Encoding.encode(e, S, n) do (nv::Union{Integer,Nothing} = nothing)
        if isnothing(nv)
            return MOI.add_variable(model.target_model)
        else
            return MOI.add_variables(model.target_model, nv)
        end
    end

    v = Variable{T}(e, x, y, ξ, χ)

    return Encoding.encode!(model, v)
end
