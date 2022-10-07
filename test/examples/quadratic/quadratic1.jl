function test_quadratic1()
    @testset "3 variables, 1 constraint" begin
        # ~*~ Problem Data ~*~ #
        n = 3
        A = [
            -1  2  2
             2 -1  2
             2  2 -1
        ]
        b = 6

        # Penalty Choice
        ρ̄ = -7

        # ~*~ Solution Data ~*~ #
        Q̄ = []

        c̄ = -1792

        x̄ = Set{Vector{Int}}([[0, 1, 1]])

        ȳ = 4

        # ~*~ Model ~*~ #
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, x[1:3], Bin)
        @objective(model, Max, x'A * x)
        @constraint(model, x'A * x <= b)

        optimize!(model)

        vqm = unsafe_backend(model)

        _, Q, c = ToQUBO.PBO.qubo_normal_form(vqm)

        ρ = last.(collect(vqm.ρ))

        # :: Reformulation ::
        @show ρ

        @show c
        @show Q

        # :: Solutions ::
        x̂ = trunc.(Int, value.(x))
        ŷ = objective_value(model)

        @show x̂
        @show ŷ
    end
end