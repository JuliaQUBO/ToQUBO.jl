raw"""

Let 

```math
\mathbf{A} = \begin{bmatrix}
    -1 &  2 \\
     2 & -1
\end{bmatrix}
```

```math
\begin{array}{rl}
    \max          & \mathbf{x}' \mathbf{A} \mathbf{x}        \\
    \textrm{s.t.} & \mathbf{x}' \mathbf{A} \mathbf{x} \leq 1 \\
                  & \mathbf{x} \in \mathbb{B}^2
\end{array}
```

That is,

```math
\begin{array}{rl}
    \max          & -x_1 + 4 x_1 x_2 - x_2        \\
    \textrm{s.t.} & -x_1 + 4 x_1 x_2 - x_2 \leq 1 \\
                  & x_1, x_2 \in \mathbb{B}
\end{array}
```

Introducing slack variables

```math
\begin{array}{rl}
    \max          & -x_1 + 4 x_1 x_2 - x_2           \\
    \textrm{s.t.} & -x_1 + 4 x_1 x_2 - x_2 + s = 1   \\
                  & x_1, x_2 \in \mathbb{B}          \\
                  & s \in [0, 3] \subset \mathbb{Z}
\end{array}
```

Moving the constraints to the objective function

```math
\begin{array}{rl}
    \max          & -x_1 + 4 x_1 x_2 - x_2 + \rho \left[-x_1 + 4 x_1 x_2 - x_2 + s - 1 \right]^2 \\
    \textrm{s.t.} & x_1, x_2 \in \mathbb{B}                                                      \\
                  & s \in [0, 3] \subset \mathbb{Z}
\end{array}
```

Expanding the objective function

```math
\begin{array}{rl}
    \max          & -x_1 + 4 x_1 x_2 - x_2 + \rho \left[ s^2 - 2 s x_1 + 8 s x_1 x_2 - 2 s x_2 - 2 s + 3 x_1 - 6 x_1 x_2 + 3 x_2 + 1 \right] \\
    \textrm{s.t.} & x_1, x_2 \in \mathbb{B}                                                                                                  \\
                  & s \in [0, 3] \subset \mathbb{Z}
\end{array}
```

Expanding as

```math
s \mapsto 1 s_1 + 2 s_2
```

```math
\begin{array}{rl}
    \max          & -x_1 + 4 x_1 x_2 - x_2 + \rho \left[
        -2 s_1 x_1 + 8 s_1 x_1 x_2 - 2 s_1 x_2 - 4 s_2 x_1 - 4 s_2 x_2 + 16 s_2 x_1 x_2 + s_1 + 4 s_2 s_1 - 2 s_1 + 4 s_2 - 4 s_2 + 3 x_1 - 6 x_1 x_2 + 3 x_2 + 1
    \right] \\
    \textrm{s.t.} & x_1, x_2 \in \mathbb{B}                                                                                                                                                                  \\
                  & s_1, s_2 \in \mathbb{B}
\end{array}
```

That, in matrix form, is

```math
\mathbf{Q} = \begin{bmatrix}
    -1 &  4 &    &    \\
       & -1 &    &    \\
       &    &    &    \\
       &    &    &    \\
\end{bmatrix} + \rho \begin{bmatrix}
     3 & -6 &  -2  &  -4 \\
       &  3 &  -2  &  -4 \\
       &    &  -1  &   4  \\
       &    &      &   4 \\
\end{bmatrix} + \rho \left[8 s_1 x_1 x_2 + 16 s_2 x_1 x_2  \right] + 1
```

Using

```math
b_1 b_2 \dots b_k \mapsto ( \sum_{i=1}^{k-2} b_{a_i} (k − i − 1 + b_i − \sum_{j = i + 1}^{k} bj) ) + b_{k − 1} b_k
```

```math
\begin{align*}
s_1 x_1 x_2 \mapsto 2 w_1 + w_1 s_1 - w_1 x_1 - w_1 x_2 + x_1 x_2 \\
s_2 x_1 x_2 \mapsto 2 w_2 + w_2 s_2 - w_2 x_1 - w_2 x_2 + x_1 x_2
\end{align*}
```

```math
\begin{align*}
  \mathbf{Q} &= \begin{bmatrix}
      -1 &  4 &  \square  &  \square &  \square &  \square \\
       \square & -1 &  \square  &  \square &  \square &  \square \\
       \square &  \square &  \square  &  \square &  \square &  \square \\
       \square &  \square &  \square  &  \square &  \square &  \square \\
       \square &  \square &  \square  &  \square &  \square &  \square \\
       \square &  \square &  \square  &  \square &  \square &  \square
  \end{bmatrix} + \rho \begin{bmatrix}
     3 & -6 &  -2 &  -4 &  \square &  \square \\
     \square &  3 &  -2 &  -4 &  \square &  \square \\
     \square &  \square &  -1 &   4 &  \square &  \square \\
     \square &  \square &  \square  &   4 &  \square &  \square \\
     \square &  \square &  \square  &  \square  &  \square &  \square \\
     \square &  \square &  \square  &  \square  &  \square &  \square 
  \end{bmatrix} + \rho \left[16 w_1 + 8 w_1 s_1 - 8 w_1 x_1 - 8 w_1 x_2 + 32 w_2 + 16 w_2 s_2 - 16 w_2 x_1 - 16 w_2 x_2 + 24 x_1 x_2  \right] (+ 1) \\
  &= \begin{bmatrix}
  -1 &  4 &  \square  &  \square &  \square &  \square \\
   \square & -1 &  \square  &  \square &  \square &  \square \\
   \square &  \square &  \square  &  \square &  \square &  \square \\
   \square &  \square &  \square  &  \square &  \square &  \square \\
   \square &  \square &  \square  &  \square &  \square &  \square \\
   \square &  \square &  \square  &  \square &  \square &  \square
\end{bmatrix} + \rho \begin{bmatrix}
 3 & -6 &  -2 &  -4 &  \square &  \square \\
 \square &  3 &  -2 &  -4 &  \square &  \square \\
 \square &  \square &  -1 &   4 &  \square &  \square \\
 \square &  \square &  \square  &   4 &  \square &  \square \\
 \square &  \square &  \square  &  \square  &  \square &  \square \\
 \square &  \square &  \square  &  \square  &  \square &  \square 
\end{bmatrix} + \rho \begin{bmatrix}
\square &  24 &  \square &  \square &  -8 &  -16 \\
\square &  \square &  \square &  \square &  -8 &  -16 \\
\square &  \square &  \square &  \square &  8 &  \square \\
\square &  \square &  \square &  \square &  \square &  16 \\
\square &  \square &  \square &  \square &  16 &  \square \\
\square &  \square &  \square &  \square &  \square & 32 
\end{bmatrix} (+ 1) \\
&= \begin{bmatrix}
    -1 + 3 \rho & 4 + 18 \rho & -2 \rho & -4 \rho & -8 \rho & -16 \rho \\
    \square & -1 + 3 \rho & -2 \rho & -4 \rho & -8 \rho & -16 \rho \\
    \square & \square & -1 \rho & 4 \rho & 8 \rho & \square \\
    \square & \square & \square & 4 \rho & \square & 16 \rho \\
    \square & \square & \square & \square & 16 \rho & \square \\
    \square & \square & \square & \square & \square & 32 \rho
\end{bmatrix} (+ 1)
\end{align*}
```

```math
\varepsilon = 1, \delta = 4 - (-2) = 6 implies \rho = -(6 + 1) = -7; \beta = 1
```

"""
function test_quadratic_1()
    @testset "2 variables, 1 constraint" begin
        # Problem Data
        A = [
            -1  2
             2 -1
        ]
        b = 1

        # Penalty Choice
        ρ̄ = -7.0

        # Solution
        Q̄ = [
            -1+3ρ̄   4+18ρ̄   -2ρ̄  -4ρ̄  -8ρ̄  -16ρ̄
                0  -1+3ρ̄    -2ρ̄  -4ρ̄  -8ρ̄  -16ρ̄
                0      0    -1ρ̄   4ρ̄   8ρ̄     0
                0      0      0   4ρ̄    0   16ρ̄
                0      0      0    0  16ρ̄     0
                0      0      0    0    0   32ρ̄
        ]

        ᾱ = 1.0
        β̄ = 1ρ̄

        x̄ = [0, 0]
        ȳ = 0.0

        # Model
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, x[1:2], Bin)
        @objective(model, Max, x' * A * x)
        @constraint(model, c1, x' * A * x <= b)

        set_optimizer_attribute(model, Attributes.StableQuadratization(), true)

        optimize!(model)

        # Reformulation
        ρ = get_attribute(c1, Attributes.ConstraintEncodingPenalty())

        n, L, Q, α, β = QUBOTools.qubo(model, :dense)

        Q̂ = Q + diagm(L)

        @test n == 6
        @test ρ ≈ ρ̄
        @test α ≈ ᾱ
        @test β ≈ β̄

        display(collect(unsafe_backend(model).g[c1.index]))

        display(Q̂)
        display(Q̄)

        @test Q̂ ≈ Q̄

        # Solutions
        x̂ = trunc.(Int, value.(x))
        ŷ = objective_value(model)

        @test x̂ == x̄
        @test ŷ ≈ ȳ

        return nothing
    end
end
