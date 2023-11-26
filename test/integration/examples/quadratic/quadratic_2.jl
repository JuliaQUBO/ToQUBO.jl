QUBOTools.PBO.varshow(v::VI) = QUBOTools.PBO.varshow(v.value)


"""
min x₁ + x₂
 st x₁ * x₂ >= 1
    x₁, x₂ ∈ {0, 1}

min x₁ + x₂ + ρ (x₁ * x₂ - 1)²
    st x₁, x₂ ∈ {0, 1}
       s ∈ [0, 1]

"""
function test_quadratic_2()
    ρ̄ = 3
    Q̄ = [
        1 -ρ̄
        0  2
    ]
    ᾱ = 1
    β̄ = 0
    x̄ = [0, 1]

    model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

    @variable(model, x[1:2], Bin)
    @objective(model, Min, x[1] + 2 * x[2])
    @constraint(model, c, x[1] * x[2] >= 1)

    optimize!(model)

    n, l, q, α, β = QUBOTools.qubo(model, :dense)

    ρ = get_attribute(c, ToQUBO.Attributes.ConstraintEncodingPenalty())
    Q = q + diagm(l)

    @test n == 2
    @test ρ ≈ ρ̄
    @test α ≈ ᾱ
    @test β ≈ β̄
    @test Q ≈ Q̄

    @test value.(x) ≈ x̄

    @test termination_status(model) === MOI.LOCALLY_SOLVED
    @test get_attribute(model, Attributes.CompilationStatus()) === MOI.LOCALLY_SOLVED

    return nothing
end
