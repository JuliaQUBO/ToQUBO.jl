# Prime Factorization

A central problem in Number Theory and cryptography is to factor ``R \in \mathbb{N}``, which is known
to be the product of two distinct prime numbers ``p, q \in \mathbb{N}``.
[Shor's Algorithm](https://en.wikipedia.org/wiki/Shor%27s_algorithm), designed to address such task is
often regarded as one of the major theoretical landmarks in Quantum Computing, being responsible for
driving increasingly greater interest to the area.

A naïve approach to model this problem can be stated as a quadratically-constrained integer program:
```math
\begin{array}{rl}
\text{s.t.} & p \times q = R \\
            & p, q \ge 0     \\
            & p, q \in \mathbb{Z}
\end{array}
```

From the definition and the basics of number theory, we are able to retrieve a few assumptions about the problem's variables:
- ``p`` and ``q`` are bounded to the interval ``\left[1, R\right]``
- Moreover, it is fine to assume ``1 < p \le \sqrt{R} \le q \le R \div 2``.

```@example prime-factorization
using JuMP
using ToQUBO
using DWaveNeal

function factor(R::Integer; optimizer = DWaveNeal.Optimizer)
    return factor(identity, R; optimizer)
end

function factor(config!::Function, R::Integer; optimizer = DWaveNeal.Optimizer)
    model = Model(() -> ToQUBO.Optimizer(optimizer))

    @variable(model,  1 <= p <= √R, Int)
    @variable(model, √R <= q <= R ÷ 2, Int)

    @constraint(model, p * q == R)

    config!(model)

    optimize!(model)

    p = round(Int, value(model[:p]))
    q = round(Int, value(model[:q]))

    return (p, q)
end
```

```@example prime-factorization
p, q = factor(15) do model
    set_optimizer_attribute(model, "num_reads", 1_000)
    set_optimizer_attribute(model, "num_sweeps", 2_000)
end

print("$p, $q")
```