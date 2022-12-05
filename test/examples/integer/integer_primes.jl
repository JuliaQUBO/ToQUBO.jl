function test_integer_primes()
    @testset "Prime Factoring: 15 = 3 × 5" begin
        # ~*~ Problem Data ~*~ #
        R = 15
        a = ceil(Int, √R)
        b = ceil(Int, R ÷ 2)

        # ~*~ Solution Data ~*~ #
        ᾱ = 1
        β̄ = 49
        Q̄ = [
            -24  16  15  15  8  0  20  18   0  20
              0 -40  60  60 -8  8 -20   0  40 -20
              0   0 -40  98 -8 -8 -20 -18 -40   0
              0   0   0 -40 -8 -8   0 -18 -40 -20
              0   0   0   0 16  0   0   0   0   0
              0   0   0   0  0  8   0   0   0   0
              0   0   0   0  0  0  20   0   0   0
              0   0   0   0  0  0   0  18   0   0
              0   0   0   0  0  0   0   0  40   0
              0   0   0   0  0  0   0   0   0  20
        ]


        ρ̄ = 1
        p̄ = 3
        q̄ = 5

        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, 2 <= p <= a, Int)
        @variable(model, a <= q <= b, Int)
        @constraint(model, c1, p * q - R == 0)

        optimize!(model)

        # :: Reformulation :: #    
        ρ       = MOI.get(unsafe_backend(model), ToQUBO.Penalty(), c1.index)
        Q, α, β = ToQUBO.qubo(unsafe_backend(model), Matrix)

        @test ρ ≈ ρ̄
        @test α ≈ ᾱ
        @test β ≈ β̄
        @test Q ≈ Q̄

        # :: Solutions :: #
        p̂ = trunc(Int, value(p))
        q̂ = trunc(Int, value(q))

        @test p̂ == p̄
        @test q̂ == q̄

        return nothing
    end
end