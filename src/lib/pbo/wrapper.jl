qubo(f::PBF) = qubo(f, Dict)

function qubo(f::PBF{S,T}, ::Type{Dict}) where {S,T}
    x = variable_map(f)
    Q = Dict{Tuple{Int,Int},T}()
    α = one(T)
    β = zero(T)

    sizehint!(Q, length(f))

    for (ω, a) in f
        η = sort([x[i] for i ∈ ω]; lt = varlt)
        k = length(η)

        if k == 0
            β += a
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
    x = variable_map(f)
    n = length(x)
    Q = zeros(T, n, n)
    α = one(T)
    β = zero(T)

    for (ω, a) ∈ f
        η = sort([x[i] for i ∈ ω]; lt = varlt)
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

variable_map(f::PBF{S}) where {S} = Dict{S,Int}(v => i for (i, v) in enumerate(variables(f)))
variable_inv(f::PBF{S}) where {S} = Dict{Int,S}(i => v for (i, v) in enumerate(variables(f)))
variable_set(f::PBF{S}) where {S} = reduce(union!, keys(f); init = Set{S}())
variables(f::PBF)                 = sort(collect(variable_set(f)); lt = varlt)
