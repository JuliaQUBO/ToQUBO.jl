@testset "PBO" begin

    # -*- Definitions -*-
S = Symbol
T = Float64

∅ = nothing

p = PBO.PBF{S, T}(∅ => 0.5, [:x] => 1.0, [:x, :y] => -2.0)
q = PBO.PBF{S, T}(∅ => 0.5, [:y] => 1.0, [:x, :y] =>  2.0)
r = PBO.PBF{S, T}(∅ => 1.0, [:z] => -1.0)
s = PBO.PBF{S, T}(∅ => 0.0, [:x, :y, :z] => 3.0)

# -*- Arithmetic: (+) -*-
@test (p + q) == (q + p) == PBO.PBF{S, T}(
    ∅ => 1.0, [:x] => 1.0, [:y] => 1.0
)

@test (p + q + r) == (r + q + p) == PBO.PBF{S, T}(
    ∅ => 2.0, [:x] => 1.0, [:y] => 1.0, [:z] => -1.0
)

@test (s + 3.0) == (3.0 + s) == PBO.PBF{S, T}(
    ∅ => 3.0, [:x, :y, :z] => 3.0
)

# -*- Arithmetic: (-) -*-
@test (p - q) == PBO.PBF{S, T}(
    [:x] => 1.0, [:y] => -1.0, [:x, :y] => -4.0
)

@test (p - p) == (q - q) == (r - r) == (s - s) == PBO.PBF{S, T}()

@test (s - 3.0) == PBO.PBF{S, T}(
    ∅ => -3.0, [:x, :y, :z] => 3.0
)

@test (3.0 - s) == PBO.PBF{S, T}(
    ∅ => 3.0, [:x, :y, :z] => -3.0
)

# -*- Arithmetic: (*) -*-
@test (p * q) == (q * p) == PBO.PBF{S, T}(
    ∅ => 0.25, [:x] => 0.5, [:y] => 0.5, [:x, :y] => -3.0
)

@test (p * (-0.5)) == ((-0.5) * p) == PBO.PBF{S, T}(
    ∅ => -0.25, [:x] => -0.5, [:x, :y] => 1.0
)

@test (0.25 * p + 0.75 * q) == PBO.PBF{S, T}(
    ∅ => 0.5, [:x] => 0.25, [:y] => 0.75, [:x, :y] => 1.0
)

@test ((p * q * r) - s) == PBO.PBF{S, T}(
    ∅ => 0.25,
    [:x] => 0.5,
    [:y] => 0.5,
    [:z] => -0.25,
    [:x, :y] => -3.0,
    [:x, :z] => -0.5,
    [:y, :z] => -0.5
)

# -*- Arithmetic: (^) -*-
@test (p ^ 0) == (q ^ 0) == (r ^ 0) == (s ^ 0) == PBO.PBF{S, T}(1.0)

@test (p == (p ^ 1)) && (q == (q ^ 1)) && (r == (r ^ 1)) && (s == (s ^ 1))

@test (p ^ 2) == PBO.PBF{S, T}(
    ∅ => 0.25, [:x] => 2.0, [:x, :y] => -2.0
)

@test (q ^ 2) == PBO.PBF{S, T}(
    ∅ => 0.25, [:y] => 2.0, [:x, :y] => 10.0
)

@test (r ^ 2) == PBO.PBF{S, T}(
    ∅ => 1.0, [:z] => -1.0
)

@test (s ^ 2) == PBO.PBF{S, T}(
    [:x, :y, :z] => 9.0
)

@test (r ^ 3) == PBO.PBF{S, T}(
    ∅ => 1.0, [:z] => -1.0
)


@test (s ^ 3) == PBO.PBF{S, T}(
    [:x, :y, :z] => 27.0
)

@test (r ^ 4) == PBO.PBF{S, T}(
    ∅ => 1.0, [:z] => -1.0
)

# -*- Test: qubo -*-
x, Q, c = ToQUBO.PBO.qubo_normal_form(Dict, p)
@test Q == Dict{Tuple{Int, Int}, T}(
    (x[:x], x[:x]) => 1.0, (x[:x], x[:y]) => -2.0
) && c == 0.5

x, Q, c = ToQUBO.PBO.qubo_normal_form(Dict, q)
@test Q == Dict{Tuple{Int, Int}, T}(
    (x[:y], x[:y]) => 1.0, (x[:x], x[:y]) => 2.0
) && c == 0.5

x, Q, c = ToQUBO.PBO.qubo_normal_form(Dict, r)
@test Q == Dict{Tuple{Int, Int}, T}(
    (x[:z], x[:z]) => -1.0
) && c == 1.0

x, Q, c = ToQUBO.PBO.qubo_normal_form(Array, p)

@test Q == Symmetric(Array{T, 2}([1.0 -1.0; -1.0 0.0])) && c == 0.5

x, Q, c = ToQUBO.PBO.qubo_normal_form(Array, q)
@test Q == Symmetric(Array{T, 2}([0.0 1.0; 1.0 1.0])) && c == 0.5

x, Q, c = ToQUBO.PBO.qubo_normal_form(Array, r)
@test Q == Symmetric(Array{T, 2}([-1.0][:,:])) && c == 1.0

# -*- Test: Degree Reduction -*-

# - Reduction by Minimum Selection - 
function slack(n::Union{Int, Nothing} = nothing)
    if isnothing(n)
        return :w
    elseif n == 1
        return [:w]
    elseif n == 2
        return [:u :v]
    elseif n == 3
        return [:u :v :w]
    end
end


@test ToQUBO.PBO.quadratize(s, slack=slack) == PBO.PBF{S, T}(
    [:w] => 3.0,
    [:x, :w] => 3.0,
    [:y, :w] => -3.0,
    [:z, :w] => -3.0,
    [:y, :z] => 3.0
) 

@test ToQUBO.PBO.discretize(p; tol=0.1) == PBO.PBF{S, T}(
    ∅ => 1.0, [:x] => 2.0, [:x, :y] => -4.0,
)

@test ToQUBO.PBO.discretize(q; tol=0.1) == PBO.PBF{S, T}(
    ∅ => 1.0, [:y] => 2.0, [:x, :y] =>  4.0,
)

@test ToQUBO.PBO.discretize(r; tol=0.1) == PBO.PBF{S, T}(
    ∅ => 1.0, [:z] => -1.0,
)

end