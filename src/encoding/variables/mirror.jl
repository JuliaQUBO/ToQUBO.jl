@doc raw"""
    Mirror()

Simply mirrors a binary variable ``x \in \mathbb{B}`` with a twin variable ``y \in \mathbb{B}``.
"""
struct Mirror{T} <: IntervalVariableEncodingMethod end

Mirror() = Mirror{Float64}()

function encode(var::Function, ::Mirror{T}) where {T}
    y = var()::VI
    f = PBO.PBF{VI,T}(y)

    return (VI[y], f, nothing)
end
