function qubo_normal_form(::Type{<: AbstractDict}, f::PBF{S, T}) where {S, T}
    # -* QUBO *-
    x = varmap(f)
    Q = Dict{Tuple{Int, Int}, T}()
    c = zero(T)

    sizehint!(Q, size(f))

    for (ω, a) in f.Ω
        η = sort([x[i] for i ∈ ω]; lt = varcmp)
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
    # -* QUBO *-
    x = varmap(f)
    n = length(x)
    Q = zeros(T, n, n)
    c = zero(T)

    for (ω, a) ∈ f.Ω
        η = sort([x[i] for i ∈ ω]; lt = varcmp)
        k = length(η)
        if k == 0
            c += a
        elseif k == 1
            i, = η
            Q[i, i] += a
        elseif k == 2
            i, j = η
            Q[i, j] += a / 2
            Q[j, i] += a / 2
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

function ising_normal_form(::Type{<:AbstractDict}, f::PBF{S, T}) where {S, T}
    # -* QUBO *-
    x, Q, c = qubo_normal_form(Dict, f)

    # -* Ising *-
    h = Dict{Int, T}()
    J = Dict{Tuple{Int, Int}, T}()

    for (ω, a) ∈ Q
        i, j = ω

        if i == j
            α = a / 2

            h[i] = get(h, i, 0) + α

            c += α
        else
            β = a / 4

            J[i, j] = β

            h[i] = get(h, i, 0) + β
            h[j] = get(h, j, 0) + β

            c += β
        end
    end

    return (x, h, J, c)
end

function ising_normal_form(::Type{<:AbstractArray}, f::PBF{S, T}) where {S, T}
    # -* QUBO *-
    x, Q, c = qubo_normal_form(Dict, f)
    
    # -* Ising *-
    n = length(x)
    h = zeros(T, n)
    J = zeros(T, n, n)

    for (ω, a) ∈ Q
        i, j = ω

        if i == j
            α = a / 2

            h[i] += α

            c += α
        else
            β = a / 4

            J[i, j] += β

            h[i] += β
            h[j] += β

            c += β
        end
    end

    return (x, h, UpperTriangular(J), c)
end

# :: Default ::
function ising_normal_form(f::PBF)
    ising_normal_form(Dict, f)
end