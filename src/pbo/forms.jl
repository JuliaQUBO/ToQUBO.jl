qubo(f::PBF) = qubo(f, Dict)

function qubo(f::PBF{S,T}, ::Type{Dict}) where {S,T}
    x = varmap(f)
    Q = Dict{Tuple{Int,Int},T}()
    α = one(T)
    β = zero(T)

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
            error(
                DomainError,
                ": Can't convert Pseudo-boolean function with degree greater than 2 to QUBO format.\nTry using 'quadratize' before conversion.",
            )
        end
    end

    return (Q, α, β)
end

function qubo(f::PBF{S,T}, ::Type{Matrix}) where {S,T}
    x = varmap(f)
    n = length(x)
    Q = zeros(T, n, n)
    α = one(T)
    β = zero(T)

    for (ω, a) ∈ f.Ω
        η = sort([x[i] for i ∈ ω]; lt = varcmp)
        k = length(η)
        if k == 0
            β += a
        elseif k == 1
            i, = η
            Q[i, i] += a
        elseif k == 2
            i, j = η
            Q[i, j] += a / 2
            Q[j, i] += a / 2
        else
            error(
                DomainError,
                ": Can't convert Pseudo-boolean function with degree greater than 2 to QUBO format.\nTry using 'quadratize' before conversion.",
            )
        end
    end

    return (Q, α, β)
end
