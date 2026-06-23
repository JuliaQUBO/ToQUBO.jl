@doc raw"""
    VariableEncodingMethod

Abstract type for variable encoding methods.
"""
abstract type VariableEncodingMethod end

Base.broadcastable(e::E) where {E<:VariableEncodingMethod} = Ref(e)

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

Return the number of target binary variables selected by encoding method `e`
for a bounded continuous interval `S` when no explicit variable bit count is
set.

The tolerance `tol` is the upper bound used by the method's representation
error rule. See [Representation Error](@ref) for the derivation and compiler
precedence between explicit bit counts and tolerance-based inference.
"""
function encoding_bits end

@doc raw"""
    SetVariableEncodingMethod

Abstract type for methods that encode variables over an arbitrary set.
"""
abstract type SetVariableEncodingMethod <: VariableEncodingMethod end

@doc raw"""
    encoding_points(e::SetVariableEncodingMethod, S::Tuple{T,T}, tol::T) where {T}

Return the number of discretization points selected by a set encoding method
for a bounded continuous interval `S` and tolerance `tol`.
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
