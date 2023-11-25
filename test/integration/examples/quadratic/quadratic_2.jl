QUBOTools.PBO.varshow(v::VI) = QUBOTools.PBO.varshow(v.value)


"""
min x₁ + x₂
 st x₁² + x₂² >= 1
    x₁, x₂ ∈ {0, 1}

min x₁ + x₂ + ρ (x₁² + x₂² - 1 + s)²
    st x₁, x₂ ∈ {0, 1}
       s ∈ [0, 1]

"""
function test_quadratic_2()
    model = Model(() -> ToQUBO.Optimizer())

    @variable(model, x[1:2], Bin)
    @objective(model, Min, x[1] + x[2])
    @constraint(model, c, x[1] * x[2] >= 1)

    optimize!(model)

    n, l, q, α, β = QUBOTools.qubo(model, :dense)

    Q = q + diagm(l)

    @show n
    @show Q

    @test termination_status(model) === MOI.LOCALLY_SOLVED
    @test get_attribute(model, Attributes.CompilationStatus()) === MOI.LOCALLY_SOLVED

    return nothing
end
