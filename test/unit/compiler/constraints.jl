function test_compiler_constraints_quadratic()
    n = 3
    A = [
        -1.0  2.0  2.0
         2.0 -1.0  2.0
         2.0  2.0 -1.0
    ]
    b = 6.0

    model = ToQUBO.Virtual.Model{Float64}()
    arch  = ToQUBO.Compiler.GenericArchitecture()
    x, _  = MOI.add_constrained_variables(model.source_model, repeat([MOI.ZeroOne()], n))

    ToQUBO.Compiler.variables!(model, arch)

    f = MOI.ScalarQuadraticFunction{Float64}(
        [MOI.ScalarQuadraticTerm(A[i, j], x[i], x[j]) for i = 1:n for j = 1:n if i != j],
        [MOI.ScalarAffineTerm(A[i, i] / 2.0, x[i]) for i = 1:n],
        0.0,
    )
    s = MOI.EqualTo{Float64}(b)
    c = MOI.add_constraint(model.source_model, f, s)
    g = ToQUBO.Compiler.constraint(model, c, f, s, arch)

    h = ToQUBO.PBO.PBF{VI,Float64}()

    ToQUBO.Compiler.parse!(model, h, f, s, arch)

    @test h == PBO.PBF{VI,Float64}(
        -6.0,
        x[1] => -0.5,
        x[2] => -0.5,
        x[3] => -0.5,
        [x[1], x[2]] => 4.0,
        [x[1], x[3]] => 4.0,
        [x[2], x[3]] => 4.0,
    )

    @test g == PBO.PBF{VI,Float64}(
        144.0,
        x[1] => 25.0,
        x[2] => 25.0,
        x[3] => 25.0,
        [x[1], x[2]] => -158.0,
        [x[1], x[3]] => -158.0,
        [x[2], x[3]] => -158.0,
        [x[1], x[2], x[3]] => 336.0,
    )

    return nothing
end

function test_compiler_constraints()
    @testset "→ Constraints" verbose = true begin
        test_compiler_constraints_quadratic()
    end

    return nothing
end
