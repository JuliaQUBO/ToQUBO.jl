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