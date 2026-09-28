function test_compiler_integer_discretization()
    @testset "Integer constraint discretization" begin
        # These integral coefficients expose the order sensitivity of the
        # approximate GCD: gcd(475713, 524288, 1) must always be exactly 1.
        coefficients = (
            (475713.0, 524288.0, 1.0),
            (475713.0, 1.0, 524288.0),
            (524288.0, 475713.0, 1.0),
            (524288.0, 1.0, 475713.0),
            (1.0, 475713.0, 524288.0),
            (1.0, 524288.0, 475713.0),
        )

        for T in (Float32, Float64, BigFloat)
            x, y = VI(1), VI(2)
            scale = T(2)^80
            large = PBO.PBF{VI,T}(x => -scale, y => 3scale)
            @test ToQUBO.Compiler._discretize!(large) === large
            @test large == PBO.PBF{VI,T}(x => -1, y => 3)

            zero_residual = PBO.PBF{VI,T}()
            @test ToQUBO.Compiler._discretize!(zero_residual) === zero_residual
            @test isempty(zero_residual)

            constant = PBO.PBF{VI,T}(-12)
            @test ToQUBO.Compiler._discretize!(constant) == PBO.PBF{VI,T}(-1)

            fractional = PBO.PBF{VI,T}(T(1.25), x => T(0.5), y => T(-0.75))
            @test ToQUBO.Compiler._discretize!(fractional) ==
                  PBO.PBF{VI,T}(5, x => 2, y => -3)
        end

        for a in coefficients,
            factor in (1.0, 2.0),
            quadratic in (false, true),
            S in (MOI.EqualTo, MOI.LessThan, MOI.GreaterThan)

            model = ToQUBO.Virtual.Model{Float64}()
            arch = ToQUBO.Compiler.GenericArchitecture()
            x, _ = MOI.add_constrained_variables(model.source_model, fill(MOI.ZeroOne(), 3))
            ToQUBO.Compiler.variables!(model, arch)

            f = if quadratic
                MOI.ScalarQuadraticFunction(
                    [MOI.ScalarQuadraticTerm(factor * a[1], x[1], x[2])],
                    [MOI.ScalarAffineTerm(factor * a[i], x[i]) for i = 2:3],
                    0.0,
                )
            else
                MOI.ScalarAffineFunction(
                    [MOI.ScalarAffineTerm(factor * a[i], x[i]) for i = 1:3],
                    0.0,
                )
            end
            s = S(factor * 500000.0)
            ci = MOI.add_constraint(model.source_model, f, s)
            residual = ToQUBO.Compiler._parse(model, f, s, arch) / factor
            penalty = ToQUBO.Compiler.constraint(model, ci, f, s, arch)

            if S !== MOI.EqualTo
                slack = ToQUBO.Virtual.expansion(model.slack[ci])
                # Both bounds require exactly 19 binary slack variables.
                @test length(ToQUBO.Virtual.target(model.slack[ci])) == 19
                residual = S === MOI.LessThan ? residual + slack : residual - slack
            end

            @test penalty == residual^2
        end
    end

    return nothing
end
