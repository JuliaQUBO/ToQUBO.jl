function test_logical_sos1()
    @testset "SOS1: 3 variables" begin
        # ~*~ Problem Data ~*~ #
        n = 3
        A = [
            -1  2  2
             2 -1  2
             2  2 -1
        ]

        # Penalty Choice
        ρ̄ = -16

        # ~*~ Solution Data ~*~ #
        Q̄ = [
             15.0 -14.0 -14.0 -16.0
            -14.0  15.0 -14.0 -16.0
            -14.0 -14.0  15.0 -16.0
            -16.0 -16.0 -16.0  16.0
        ]

        β̄ = -16

        x̄ = Set{Vector{Int}}([[0, 0, 0]])

        ȳ = 0

        # ~*~ Model ~*~ #
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, x[1:n], Bin)
        @objective(model, Max, x'A * x)
        @constraint(model, x ∈ SOS1())

        optimize!(model)

        Q, _, β = ToQUBO.PBO.qubo(unsafe_backend(model))

        v = _variable_indices(unsafe_backend(model))
        c = _constraint_indices(unsafe_backend(model))

        ρ = MOI.get.(model, ToQUBO.Penalty(), [v; c])

        # :: Reformulation ::
        @test all(ρ .== ρ̄)

        @test β ≈ β̄
        @test Q ≈ Q̄

        # :: Solutions ::
        x̂ = trunc.(Int, value.(x))
        ŷ = objective_value(model)

        @test x̂ ∈ x̄
        @test ŷ ≈ ȳ
    end
end