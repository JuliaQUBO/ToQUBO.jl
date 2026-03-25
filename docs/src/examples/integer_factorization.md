# Prime Factorization

A central problem in Number Theory and cryptography is to factor ``R \in \mathbb{N}``, which is known
to be the product of two distinct prime numbers ``p, q \in \mathbb{N}``.
[Shor's Algorithm](https://en.wikipedia.org/wiki/Shor%27s_algorithm), designed to address such task is
often regarded as one of the major theoretical landmarks in Quantum Computing, being responsible for
driving increasingly greater interest to the area.

!!! info "Quantum Computing and Factorization"
    Current hardware is still limited, so in this example the QUBO formulation is best viewed as a way to study how factorization can be encoded for annealing-style and other binary optimization workflows.

## QUBO Formulation

A naïve approach to model this problem can be stated as a quadratically-constrained integer program:

```math
\begin{array}{rl}
\text{s.t.} & p \times q = R \\
            & p, q \ge 0     \\
            & p, q \in \mathbb{Z}
\end{array}
```

This is a constraint satisfaction problem (no objective function) where we seek integer values ``p`` and ``q`` that multiply to give ``R``.

## Variable Bounds

From the definition and the basics of number theory, we are able to retrieve a few assumptions about the problem's variables:

- ``p`` and ``q`` are bounded to the interval ``\left[1, R\right]``
- Moreover, it is fine to assume ``1 < p \le \sqrt{R} \le q \le R \div 2``.

These bounds are crucial for the QUBO encoding, as they determine how many binary variables are needed to represent ``p`` and ``q``.

## Implementation

```@example prime-factorization
using JuMP
using ToQUBO
using PySA

function factor(R::Integer; optimizer = PySA.Optimizer)
    return factor(identity, R; optimizer)
end

function factor(config!::Function, R::Integer; optimizer = PySA.Optimizer)
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

## Solving

```@example prime-factorization
p, q = factor(15) do model
    set_optimizer_attribute(model, "n_reads", 100)
    set_optimizer_attribute(model, "n_sweeps", 200)
end

print("$p, $q")
```

## Scaling Considerations

While this approach works well for small numbers, the number of binary variables required grows with the size of the factors. For a number ``R`` with ``n``-bit factors, approximately ``O(n)`` binary variables are needed for each factor. The quadratic constraint ``p \times q = R`` then introduces ``O(n^2)`` terms in the QUBO, which determines the problem's complexity on quantum hardware.

!!! warning "Practical Limitations"
    Current quantum annealing hardware is limited in the number of qubits and connectivity, restricting the size of numbers that can be factored. This example is primarily educational, demonstrating how factorization can be encoded as a QUBO problem.
