module PBO

# -*- Imports -*-
using LinearAlgebra
using Base: haslength

# -*- Exports -*-
export PBF
export ×, ∂, Δ, δ, ϵ, Θ, ∅

# -*- Variable Terms -*-
×(x::S, y::S) where {S} = Set{S}([x, y])
×(x::Set{S}, y::S) where {S} = union(x, y)
×(x::S, y::Set{S}) where {S} = union(x, y)
×(x::Set{S}, y::Set{S}) where {S} = union(x, y)

# -*- Empty Term -*-
const ∅ = nothing

# -*- Greatest Common Divisor -*-
function Base.gcd(x::T, y::T; tol::T = T(1e-6)) where {T <: AbstractFloat}
    if y == zero(T)
        return x
    elseif x == zero(T)
        return y
    else
        return (x / numerator(rationalize(x / y; tol = tol)))::T
    end    
end

function Base.gcd(a::AbstractArray{T}; tol::T = T(1e-6)) where {T<:AbstractFloat}
    return reduce((x, y) -> gcd(x, y; tol = tol), a)::T
end

@doc raw"""
    PseudoBooleanFunction{S, T}(c::T)
    PseudoBooleanFunction{S, T}(ps::Pair{Vector{S}, T}...)

A Pseudo-Boolean Function ``f \in \mathscr{F}`` over some field ``\mathbb{T}`` takes the form

```math
f(\mathbf{x}) = \sum_{\omega \in \Omega\left[f\right]} c_\omega \prod_{j \in \omega} \mathbb{x}_j
```

where each ``\Omega\left[{f}\right]`` is the multi-linear representation of ``f`` as a set of terms. Each term is given by a unique set of indices ``\omega \subseteq \mathbb{S}`` related to some coefficient ``c_\omega \in \mathbb{T}``. We say that ``\omega \in \Omega\left[{f}\right] \iff c_\omega \neq 0``.
Variables ``\mathbf{x}_i`` are indeed boolean, thus ``f : \mathbb{B}^{n} \to \mathbb{T}``.

## References
 * [1] Endre Boros, Peter L. Hammer, Pseudo-Boolean optimization, Discrete Applied Mathematics, 2002 [{doi}](https://doi.org/10.1016/S0166-218X(01)00341-9)
"""
struct PseudoBooleanFunction{S <: Any, T <: Number} <: AbstractDict{Set{S}, T}
    Ω::Dict{Set{S}, T}

    varmap::Dict{S, Int}
    varinv::Dict{Int, S}

    function PseudoBooleanFunction{S, T}(kv::Any) where {S, T}
        Ω = Dict{Set{S}, T}()
        haslength(kv) && sizehint!(Ω, Int(length(kv))::Int)
        for (η, a) ∈ kv
            ω = Set{S}(η)
            c = get(Ω, ω, zero(T)) + convert(T, a)
            if c == zero(T)
                delete!(Ω, ω)
            else
                Ω[ω] = c
            end
        end
        return new{S, T}(
            Ω,
            Dict{S, Int}(),
            Dict{Int, S}()
        )
    end

    function PseudoBooleanFunction{S, T}(Ω::Dict{Set{S}, T}) where {S, T}
        return new{S, T}(
            Dict{Set{S}, T}(ω => c for (ω, c) in Ω if c != zero(T)),
            Dict{S, Int}(),
            Dict{Int, S}(),
        )
    end

    # -*- Empty -*-
    function PseudoBooleanFunction{S, T}() where {S, T}
        return new{S, T}(
            Dict{Set{S}, T}(),
            Dict{S, Int}(),
            Dict{Int, S}(),
        )
    end

    # -*- Constant -*-
    function PseudoBooleanFunction{S, T}(c::T) where {S, T}
        if c === zero(T)
            return new{S, T}(
                Dict{Set{S}, T}(),
                Dict{S, Int}(),
                Dict{Int, S}(),
            )
        else
            return new{S, T}(
                Dict{Set{S}, T}(Set{S}() => c),
                Dict{S, Int}(),
                Dict{Int, S}(),
            )
        end
    end

    # -*- Terms -*-
    function PseudoBooleanFunction{S, T}(ω::Set{S}) where {S, T}
        return new{S, T}(
            Dict{Set{S}, T}(ω => one(T)),
            Dict{S, Int}(),
            Dict{Int, S}(),
        )
    end

    function PseudoBooleanFunction{S, T}(ω::Vararg{S}) where {S, T}
        return new{S, T}(
            Dict{Set{S}, T}(Set{S}(ω) => one(T)),
            Dict{S, Int}(),
            Dict{Int, S}(),
        )
    end

    # -*- Pairs (Vectors) -*-
    function PseudoBooleanFunction{S, T}(ps::Vararg{Pair{Vector{S}, T}}) where {S, T}
        Ω = Dict{Set{S}, T}()
        haslength(ps) && sizehint!(Ω, Int(length(ps))::Int)

        for (η, a) in ps
            ω = Set{S}(η)
            c = get(Ω, ω, zero(T)) + a

            if c == zero(T)
                delete!(Ω, ω)
            else
                Ω[ω] = c
            end
        end

        return new{S, T}(
            Ω,
            Dict{S, Int}(),
            Dict{Int, S}(),
        )
    end

    # -*- Pairs (Sets) -*-
    function PseudoBooleanFunction{S, T}(ps::Vararg{Pair{Set{S}, T}}) where {S, T}
        Ω = Dict{Set{S}, T}()
        haslength(ps) && sizehint!(Ω, Int(length(ps))::Int)

        for (ω, a) in ps
            c = get(Ω, ω, zero(T)) + a

            if c == zero(T)
                delete!(Ω, ω)
            else
                Ω[ω] = c
            end
        end

        return new{S, T}(
            Ω,
            Dict{S, Int}(),
            Dict{Int, S}(),
        )
    end
end

# -*- Alias -*-
const PBF{S, T} = PseudoBooleanFunction{S, T}

# -*- Default -*-
function PBF()::PBF{Int, Float64}
    return PBF{Int, Float64}()
end

function PBF(c::Float64)::PBF{Int, Float64}
    return PBF{Int, Float64}(c)
end

# -*- Copy -*-
function Base.copy(f::PBF{S, T})::PBF{S, T} where {S, T}
    return PBF{S, T}(copy(f.Ω))
end 

# -*- Iterator & Length -*-
function Base.length(f::PBF)::Int
    return length(f.Ω)
end

function Base.isempty(f::PBF)::Bool
    return isempty(f.Ω)
end

function Base.iterate(f::PBF)
    return iterate(f.Ω)
end

function Base.iterate(f::PBF, i::Int)
    return iterate(f.Ω, i)
end

# -*- Indexing: Get -*-
function Base.getindex(f::PBF{S, T}, ω::Set{S})::T where {S, T}
    return get(f.Ω, ω, zero(T))
end

function Base.getindex(f::PBF{S, T}, η::Vector{S}) where {S, T}
    return getindex(f, Set{S}(η))
end

function Base.getindex(f::PBF{S, T}, ξ::S...) where {S, T}
    return getindex(f, Set{S}(ξ))
end

function Base.getindex(f::PBF{S, T}, ::Nothing) where {S, T}
    return getindex(f, Set{S}())
end

# -*- Indexing: Set -*-
function Base.setindex!(f::PBF{S, T}, c::T, ω::Set{S}) where {S, T}
    if c == zero(T) && haskey(f.Ω, ω)
        delete!(f.Ω, ω)
    else
        f.Ω[ω] = c
    end

    nothing
end

function Base.setindex!(f::PBF{S, T}, c::T, η::Vector{S}) where {S, T}
    setindex!(f, c, Set{S}(η))
end

function Base.setindex!(f::PBF{S, T}, c::T, ξ::S...) where {S, T}
    setindex!(f, c, Set{S}(ξ))
end

function Base.setindex!(f::PBF{S, T}, c::T, ::Nothing) where {S, T}
    setindex!(f, c, Set{S}())
end

# -*- Properties -*-
function Base.size(f::PBF{S, T}) where {S, T}
    return length(f) - haskey(f.Ω, Set{S}())
end

function degree(f::PBF)
    return maximum(length.(keys(f.Ω)))
end

function varset(f::PBF{S, T}) where {S, T}
    if isempty(f)
        return Set{S}()
    else
        return reduce(union, keys(f.Ω))
    end
end

function varmap(f::PBF{S, T}) where {S, T}
    if isempty(f.varmap)
        for (i, x) ∈ enumerate(sort(collect(varset(f))))
            f.varmap[x] = i
            f.varinv[i] = x
        end
    end

    return f.varmap
end

function varinv(f::PBF{S, T}) where {S, T}
    if isempty(f.varinv)
        for (i, x) ∈ enumerate(sort(collect(varset(f))))
            f.varmap[x] = i
            f.varinv[i] = x
        end
    end

    return f.varinv
end

# -*- Comparison: (==, !=, ===, !==)
function Base.:(==)(f::PBF{S, T}, g::PBF{S, T}) where {S, T}
    return f.Ω == g.Ω
end

function Base.:(!=)(f::PBF{S, T}, g::PBF{S, T}) where {S, T}
    return f.Ω != g.Ω
end

# -*- Arithmetic: (+) -*-
function Base.:(+)(f::PBF{S, T}, g::PBF{S, T}) where {S, T}
    h = copy(f)
    for (ω, c) in g.Ω
        h[ω] += c
    end
    return h
end

function Base.:(+)(f::PBF{S, T}, c::T) where {S, T}
    g = copy(f)
    g[nothing] += c
    return g
end

function Base.:(+)(c::T, f::PBF{S, T}) where {S, T}
    return +(f, c)
end

# -*- Arithmetic: (-) -*-
function Base.:(-)(f::PBF{S, T}) where {S, T}
    return PBF{S, T}(Dict{Set{S}, T}(ω => -c for (ω, c) in f.Ω))
end

function Base.:(-)(f::PBF{S, T}, g::PBF{S, T})::PBF{S, T} where {S, T}
    h = copy(f)
    for (ω, c) in g.Ω
        h[ω] -= c
    end
    return h
end

function Base.:(-)(f::PBF{S, T}, c::T)::PBF{S, T} where {S, T}
    g = copy(f)
    g[nothing] -= c
    return g
end

function Base.:(-)(c::T, f::PBF{S, T})::PBF{S, T} where {S, T}
    g = -(f)
    g[nothing] += c
    return g
end

# -*- Arithmetic: (*) -*-
function Base.:(*)(f::PBF{S, T}, g::PBF{S, T})::PBF{S, T} where {S, T}
    if isempty(f) || isempty(g)
        return PBF{S, T}()
    end

    h = PBF{S, T}()

    for (ωᵢ, cᵢ) ∈ f.Ω, (ωⱼ, cⱼ) ∈ g.Ω
        h[ωᵢ × ωⱼ] += cᵢ * cⱼ
    end

    return h
end

function Base.:(*)(f::PBF{S, T}, c::T)::PBF{S, T} where {S, T}
    if c == zero(T)
        return PBF{S, T}()
    else
        return PBF{S, T}(
            Dict(ω => a * c for (ω, a) ∈ f.Ω)
        )
    end
end

function Base.:(*)(c::T, f::PBF{S, T})::PBF{S, T} where {S, T}
    return *(f, c)
end

# -*- Arithmetic: (/) -*-
function Base.:(/)(f::PBF{S, T}, c::T)::PBF{S, T} where {S, T}
    if c == zero(T)
        error(DivideError, ": division by zero") 
    else
        return PBF{S, T}(
            Dict(ω => a / c for (ω, a) ∈ f.Ω)
        )
    end
end

# -*- Arithmetic: (^) -*-
function Base.:(^)(f::PBF{S, T}, n::Int)::PBF{S, T} where {S, T}
    if n < 0
        error(DivideError, ": Can't raise Pseudo-boolean function to a negative power")
    elseif n == 0
        return one(PBF{S, T})
    elseif n == 1
        return copy(f)
    else 
        g = PBF{S, T}(one(T))
        for _ = 1:n
            g *= f
        end
        return g
    end
end

# -*- Arithmetic: Evaluation -*-
function (f::PBF{S, T})(x::Dict{S, Int}) where {S, T}
    g = PBF{S, T}()
    
    for (ω, c) in f
        η = Set{S}()
        for j in ω
            if haskey(x, j)
                if !(x[j] > 0)
                    c = zero(T)
                    break
                end
            else
                push!(η, j)
            end
        end
        g[η] += c
    end

    return g
end

function (f::PBF{S, T})(x::Pair{S, Int}...) where {S, T}
    return f(Dict{S, Int}(x...))
end

# -*- Type conversion -*-
function Base.convert(U::Type{<:T}, f::PBF{S, T}) where {S, T}
    if isempty(f)
        return zero(U)
    elseif degree(f) == 0
        return convert(U, f[nothing])
    else
        error("Can't convert non-constant Pseudo-boolean Function to scalar type $U")
    end
end

function Base.zero(::Type{<:PBF{S, T}}) where {S, T}
    return PBF{S, T}()
end

function Base.one(::Type{<:PBF{S, T}}) where {S, T}
    return PBF{S, T}(one(T))
end

# -*- Gap & Penalties -*-
@doc raw"""
    gap(f::PBF{S, T}; bound::Symbol=:loose) where {S, T}

Computes the least upper bound for the greatest variantion possible under some `` f \in \mathscr{F} `` i. e.

```math
\begin{array}{r l}
    \min        & M \\
    \text{s.t.} & \left|{f(\mathbf{x}) - f(\mathbf{y})}\right| \le M ~~ \forall \mathbf{x}, \mathbf{y} \in \mathbb{B}^{n} 
\end{array}
```

A simple approach, avaiable using the `bound=:loose` parameter, is to define
```math
M \triangleq \sum_{\omega \neq \varnothing} \left|{c_\omega}\right|
```
"""
function gap(f::PBF{S, T}; bound::Symbol=:loose) where {S, T}
    if bound === :loose
        return sum(abs(c) for (ω, c) in f if !isempty(ω); init = zero(T))
    elseif bound === :tight
        error("Not Implemented: See [1] sec 5.1.1 Majorization")
    else
        throw(ArgumentError(": Unknown bound thightness $bound"))
    end
end

const δ = gap

"""
"""
function sharpness(f::PBF{S, T}; bound::Symbol=:loose) where {S, T}
    if bound === :none
        return one(T)
    elseif bound === :loose
        return gcd(values(f))::T
    elseif bound === :tight
        error("Not Implemented: thightness $bound")
    else
        throw(ArgumentError(": Unknown bound thightness $bound"))
    end
end

function sharpness(f::PBF{S, T}; bound::Symbol=:loose, tol::T = T(1e-6)) where {S, T<:AbstractFloat}
    if bound === :none
        return one(T)
    elseif bound === :loose
        return gcd([f[ω] for ω ∈ Ω(f) if !isempty(ω)]; tol = tol)::T
    elseif bound === :tight
        error("Not Implemented: thightness $bound")
    else
        throw(ArgumentError(": Unknown bound thightness $bound"))
    end
end

const ϵ = sharpness

# -*- Computations with PBF's -*-
function terms(f::PBF{S, T}) where {S, T}
    return keys(f.Ω)
end

const Ω = terms

@doc raw"""
    derivative(f::PBF{S, T}, i::S) where {S, T}
    derivative(f::PBF{S, T}, i::Int) where {S, T}

The partial derivate of function ``f \in \mathscr{F}`` with respect to the ``i``-th variable.

```math
    \Delta_i f(\mathbf{x}) = \frac{\partial f(\mathbf{x})}{\partial \mathbf{x}_i} =
    \sum_{\omega \in \Omega\left[{f}\right] \setminus \left\{{i}\right\}}
    c_{\omega \cup \left\{{i}\right\}} \prod_{i \in \omega} \mathbf{x}_i
```
"""
function derivative(f::PBF{S, T}, s::S) where {S, T}
    return PBF{S, T}(ω => f[ω × s] for ω ∈ Ω(f) if (s ∉ ω))
end

function derivative(f::PBF{S, T}, i::Int) where {S, T}
    return derivative(f, varinv(f)[i])
end

const Δ = derivative
const ∂ = derivative

@doc raw"""
    gradient(f::PBF)

Computes the gradient of ``f \in \mathscr{F}`` where the ``i``-th derivative is given by [`derivative`](@ref).
"""
function gradient(f::PBF)
    return [derivative(f, s) for (s, _) ∈ varmap(f)]
end

const ∇ = gradient

@doc raw"""
    residual(f::PBF{S, T}, i::S) where {S, T}
    residual(f::PBF{S, T}, i::Int) where {S, T}

The residual of function ``f \in \mathscr{F}`` with respect to the ``i``-th variable.

```math
    \Theta_i f(\mathbf{x}) = f(\mathbf{x}) - \mathbf{x}_i\, \Delta_i f(\mathbf{x}) =
    \sum_{\omega \in \Omega\left[{f}\right] \setminus \left\{{i}\right\}}
    c_{\omega \cup \left\{{i}\right\}} \prod_{i \in \omega} \mathbf{x}_i
```
"""
function residual(f::PBF{S, T}, i::S) where {S, T}
    return PBF{S, T}(ω => c for (ω, c) ∈ Ω(f) if (i ∉ ω))
end

function residual(f::PBF{S, T}, i::Int) where {S, T}
    return Θ(f, varinv(f)[i])
end

const Θ = residual

# -*- Output -*-
function qubo_normal_form(::Type{<: AbstractDict}, f::PBF{S, T}) where {S, T}
    # -* QUBO *-
    x = varmap(f)
    Q = Dict{Tuple{Int, Int}, T}()
    c = zero(T)

    sizehint!(Q, size(f))

    for (ω, a) ∈ f.Ω
        η = sort([x[i] for i ∈ ω])
        k = length(η)

        if k == 0
            c += a
        elseif k == 1
            i, = η
            Q[i, i] = a
        elseif k == 2
            i, j = η
            Q[i, j] = a
        else
            error(DomainError, ": Can't convert Pseudo-boolean function with degree greater than 2 to QUBO format.\nTry using 'quadratize' before conversion.")
        end
    end

    return (x, Q, c)
end

function qubo_normal_form(::Type{<: AbstractArray}, f::PBF{S, T}) where {S, T}
    # -* Constants *-
    𝟐 = convert(T, 2)

    # -* QUBO *-
    x = varmap(f)
    n = length(x)
    Q = zeros(T, n, n)
    c = zero(T)

    for (ω, a) ∈ f.Ω
        η = sort([x[i] for i ∈ ω])
        k = length(η)
        if k == 0
            c += a
        elseif k == 1
            i, = η
            Q[i, i] += a
        elseif k == 2
            i, j = η
            Q[i, j] += a / 𝟐
            Q[j, i] += a / 𝟐
        else
            error(DomainError, ": Can't convert Pseudo-boolean function with degree greater than 2 to QUBO format.\nTry using 'quadratize' before conversion.")
        end
    end

    return (x, Symmetric(Q), c)
end

# -*- Output: Default Behavior -*-
function qubo_normal_form(f::PBF{S, T}) where {S, T}
    return qubo_normal_form(Dict, f)
end

function ising_normal_form(::Type{<: AbstractDict}, f::PBF{S, T}) where {S, T}
    # -* Constants *-
    𝟎 = zero(T)
    𝟐 = convert(T, 2)
    𝟒 = convert(T, 4)

    # -* QUBO *-
    x, Q, c = qubo(Dict, f)

    # -* Ising *-
    h = Dict{Int, T}()
    J = Dict{Tuple{Int, Int}, T}()

    for (ω, a) ∈ Q
        i, j = ω

        if i == j
            α = a / 𝟐

            h[i] = get(h, i, 𝟎) + α

            c += α
        else
            β = a / 𝟒

            J[i, j] = β

            h[i] = get(h, i, 𝟎) + β
            h[j] = get(h, j, 𝟎) + β

            c += β
        end
    end

    return (x, h, J, c)
end

function ising_normal_form(::Type{<:AbstractArray}, f::PBF{S, T}) where {S, T}
    # -* Constants *-
    𝟐 = convert(T, 2)
    𝟒 = convert(T, 4)

    # -* QUBO *-
    x, Q, c = qubo(Dict, f)
    
    # -* Ising *-
    n = length(x)
    h = zeros(T, n)
    J = zeros(T, n, n)

    for (ω, a) ∈ Q
        i, j = ω

        if i == j
            α = a / 𝟐

            h[i] += α

            c += α
        else
            β = a / 𝟒

            J[i, j] += β

            h[i] += β
            h[j] += β

            c += β
        end
    end

    return (x, h, UpperTriangular(J), c)
end

# :: Default ::
function ising_normal_form(f::PBF{S, T}) where {S, T}
    return ising_normal_form(Dict, f)
end

# -*- Integer Coefficients -*-
@doc raw"""
    discretize(f::PBF{S, T}; tol::T) where {S, T}

For a given function ``f \in \mathscr{F}`` written as

```math
    f\left({\mathbf{x}}\right) = \sum_{\omega \in \Omega\left[{f}\right]} c_\omega \prod_{i \in \omega} \mathbf{x}_i
```

computes an approximate function  ``g : \mathbb{B}^{n} \to \mathbb{Z}`` such that

```math
    \argmin_{\mathbf{x} \in \mathbb{B}^{n}} g\left({\mathbf{x}}\right) = \argmin_{\mathbf{x} \in \mathbb{B}^{n}} f\left({\mathbf{x}}\right)
```

This is done by rationalizing every coefficient ``c_\omega`` according to some tolerance `tol`.

"""
function discretize(f::PBF{S, T}; tol::T = T(1e-6)) where {S, T}
    return f / ϵ(f; bound = :loose, tol = tol)
end

# -*- :: Quadratization :: -*-

abstract type QuadratizationType end

nsv(::Type{<:QuadratizationType}, ::Int) = 0
nst(::Type{<:QuadratizationType}, ::Int) = 0

struct Quadratization{T<:QuadratizationType}
    deg::Int # Initial Degree
    nsv::Int # New Slack Variables
    nst::Int # Non-Submodular Terms

    function Quadratization{T}(deg::Int) where {T<:QuadratizationType}
        return new{T}(
            deg,
            nsv(T, deg),
            nst(T, deg),
        )
    end
end

@doc raw"""
    @quadratization(name, nsv, nst)

Defines a new quadratization technique.
"""
macro quadratization(name, nsv, nst)
    return :(
        struct $(esc(name)) <: QuadratizationType end;

        function nsv(::Type{$(esc(name))}, k::Int)
            return $(esc(nsv))
        end;

        function nst(::Type{$(esc(name))}, k::Int)
            return $(esc(nst))
        end;
    )
end

@doc raw"""
    TBT_QUAD(::Int)

Term-by-term quadratization
"""

@quadratization TBT_QUAD 0 0

@doc raw"""
    NTR_KZFD(::Int)

NTR-KZFD (Kolmogorov & Zabih, 2004; Freedman & Drineas, 2005)
"""

@quadratization NTR_KZFD 1 0

function quadratize(::Quadratization{NTR_KZFD}, ω::Set{S}, c::T; slack::Any) where {S, T}
    # -* Degree *-
    k = length(ω)

    s = slack()::S

    return PBF{S, T}(Set{S}([s]) => -c * convert(T, k - 1), (i × s => c for i ∈ ω)...)
end

@doc raw"""
    PTR_BG(::Int)

PTR-BG (Boros & Gruber, 2014)
"""

@quadratization PTR_BG k - 2 k - 1

function quadratize(::Quadratization{PTR_BG}, ω::Set{S}, c::T; slack::Any) where {S, T}
    # -* Degree *-
    k = length(ω)

    # -* Variables *-
    s = slack(k - 2)::Vector{S}
    b = sort(collect(ω))::Vector{S}

    # -*- PBF & Quadratization -*-
    f = PBF{S, T}(b[k] × b[k - 1] => c)

    for i = 1:(k - 2)
        f[s[i]] += c * convert(T, k - i - 1)

        f[s[i] × b[i]] += c

        for j = (i + 1):k
            f[s[i] × b[j]] -= c
        end
    end    

    return f
end

function quadratize(ω::Set{S}, c::T; slack::Any) where {S, T}
    if c < zero(T)
        return quadratize(
            Quadratization{NTR_KZFD}(length(ω)),
            ω,
            c;
            slack=slack,
        )
    else
        return quadratize(
            Quadratization{PTR_BG}(length(ω)),    
            ω,
            c;
            slack=slack,
        )
    end
end

function quadratize(::Quadratization{TBT_QUAD}, f::PBF{S, T}; slack::Any) where {S, T}
    g = PBF{S, T}()

    for (ω, c) ∈ f.Ω
        if length(ω) <= 2
            g[ω] += c
        else
            for (η, a) ∈ quadratize(
                    Quadratization{PTR_BG}(length(ω)),
                    ω,
                    c;
                    slack=slack,
                )
                g[η] += a
            end
        end
    end

    return g
end

@doc raw"""
    quadratize(f::PBF{S, T}; slack::Any) where {S, T}

Quadratizes a given PBF, i.e. creates a function ``g \in \mathscr{F}^{2}`` from ``f \in \mathscr{F}^{k}, k \ge 3``.

f(X ∪ Y) + f(X ∩ Y) ≤ f(X) + f(Y)  X, Y ⊂ S ⟹ Submodular
"""
function quadratize(f::PBF{S, T}; slack::Any) where {S, T}
    return quadratize(
        Quadratization{TBT_QUAD}(degree(f)),
        f;
        slack=slack,
    )
end

end # module