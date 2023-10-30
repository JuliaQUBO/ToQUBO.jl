@doc raw"""
    VariableEncodingMethod

Abstract type for variable encoding methods.
"""
abstract type VariableEncodingMethod end

@doc raw"""
    encode(var, e::VariableEncodingMethod, x::Union{VI,Nothing}, S)
"""
function encode end

@doc raw"""
    encode!(target, source...)
"""
function encode! end

@doc raw"""
    encodes(f::AbstractPBF, S::Tuple{T,T}, tol::T) where {T}
"""
function encodes end

@doc raw"""
    encoding_bits(e::VariableEncodingMethod, S::Tuple{T,T}, tol::T) where {T}
"""
function encoding_bits end

@doc raw"""
    SetVariableEncodingMethod

Abstract type for methods that encode variables over an arbitrary set.
"""
abstract type SetVariableEncodingMethod <: VariableEncodingMethod end

@doc raw"""
    encoding_points(e::SetVariableEncodingMethod, S::Tuple{T,T}, tol::T) where {T}
"""
function encoding_points end

@doc raw"""
    IntervalVariableEncodingMethod

Abstract type for methods that encode variables using a linear function, e.g.,

```math
\xi(\mathbf{y}) = \beta + \sum_{i = 1}^{n} \gamma_{i} y_{i}
```
"""
abstract type IntervalVariableEncodingMethod <: VariableEncodingMethod end
