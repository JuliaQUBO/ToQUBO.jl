function test_continuous_1()
    @testset "9 variables ∈ [0, 1]" begin
        # Problem Data
        n = 3
        A = [
            -1  2  2
             2 -1  2
             2  2 -1
        ]

        # Solution
        Q̄ = [
            -1  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
             0 -2  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
             0  0  2  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0
             0  0  0  4  0  0  0  0  0  0  0  0  0  0  0  0  0  0
             0  0  0  0  2  0  0  0  0  0  0  0  0  0  0  0  0  0
             0  0  0  0  0  4  0  0  0  0  0  0  0  0  0  0  0  0
             0  0  0  0  0  0  2  0  0  0  0  0  0  0  0  0  0  0
             0  0  0  0  0  0  0  4  0  0  0  0  0  0  0  0  0  0
             0  0  0  0  0  0  0  0  2  0  0  0  0  0  0  0  0  0
             0  0  0  0  0  0  0  0  0  4  0  0  0  0  0  0  0  0
             0  0  0  0  0  0  0  0  0  0 -1  0  0  0  0  0  0  0
             0  0  0  0  0  0  0  0  0  0  0 -2  0  0  0  0  0  0
             0  0  0  0  0  0  0  0  0  0  0  0  2  0  0  0  0  0
             0  0  0  0  0  0  0  0  0  0  0  0  0  4  0  0  0  0
             0  0  0  0  0  0  0  0  0  0  0  0  0  0  2  0  0  0
             0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  4  0  0
             0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0 -1  0
             0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0  0 -2
        ]

        ᾱ = 1
        β̄ = 0

        x̄ = Set{Matrix{Int}}([
            [0 1 1;1 0 1;1 1 0]
        ])
        ȳ = 12

        # Model
        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        set_optimizer_attribute(model, ToQUBO.DEFAULT_VARIABLE_ENCODING_ATOL(), 1E-1)

        @variable(model, 0 <= x[1:n,1:n] <= 1)
        @objective(model, Max, sum(A .* x))

        optimize!(model)

        # Reformulation
        Q, α, β = ToQUBO.qubo(model, Matrix)

        @test α ≈ ᾱ
        @test β ≈ β̄
        @test Q ≈ Q̄/3

        # Solutions
        x̂ = trunc.(Int, value.(x))
        ŷ = objective_value(model)

        @test x̂ ∈ x̄
        @test ŷ ≈ ȳ

        return nothing
    end
end