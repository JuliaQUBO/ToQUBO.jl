function test_variable_encoding_methods()
    @testset "→ Variable" begin
        @testset "⋅ Mirror" begin
            let e = ToQUBO.Encoding.Mirror{Float64}()
                φ = PBO.vargen(VI)

                y, ξ, χ = ToQUBO.Encoding.encode(φ, e)

                @test length(y) == 1
                @test y == VI.([1])
                @test ξ == PBO.PBF{VI,Float64}(y => 1.0)
                @test isnothing(χ)
            end
        end

        @testset "⋅ Unary" begin
            let e = ToQUBO.Encoding.Unary{Float64}()
                S = (-2.0, 2.0)

                @testset "ℤ" begin
                    let φ = PBO.vargen(VI)
                        y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S)

                        @test length(y) == 4
                        @test y == VI.([1, 2, 3, 4])
                        @test ξ == PBO.PBF{VI,Float64}(
                            y[1] => 1.0,
                            y[2] => 1.0,
                            y[3] => 1.0,
                            y[4] => 1.0,
                            -2.0,
                        )
                        @test isnothing(χ)
                    end
                end

                @testset "ℝ" begin
                    let φ = PBO.vargen(VI)
                        y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S; bits = 8)

                        @test length(y) == 8
                        @test y == VI.([1, 2, 3, 4, 5, 6, 7, 8])
                        @test ξ == PBO.PBF{VI,Float64}(
                            y[1] => 0.5,
                            y[2] => 0.5,
                            y[3] => 0.5,
                            y[4] => 0.5,
                            y[5] => 0.5,
                            y[6] => 0.5,
                            y[7] => 0.5,
                            y[8] => 0.5,
                            -2.0,
                        )
                        @test isnothing(χ)
                    end
                end
            end
        end

        return nothing

        @testset "Unary ℤ" begin
            model = ToQUBO.Virtual.Model()

            x = MOI.add_variable(model.source_model)
            a, b = (-2.0, 2.0)

            v = ToQUBO.Encoding.encode!(
                model,
                ToQUBO.Encoding.Unary{Float64}(),
                x,
                (a, b),
            )
            y = ToQUBO.Virtual.target(v)

            @test length(y) == 4

            @test ToQUBO.Virtual.source(v) == x
            @test ToQUBO.Encoding.expansion(v) == PBO.PBF{VI,Float64}(
                y[1] => 1.0,
                y[2] => 1.0,
                y[3] => 1.0,
                y[4] => 1.0,
                nothing => a,
            )
            @test isnothing(ToQUBO.Encoding.penaltyfn(v))

            @test model.variables == [v]
            @test model.source[ToQUBO.Virtual.source(v)] == (v)
            @test [model.target[y] for y in ToQUBO.Virtual.target(v)] == [v, v, v, v]
        end

            @testset "Unary ℝ" begin
                model = ToQUBO.Virtual.Model()

                x = MOI.add_variable(model.source_model)
                a, b = (-2.0, 2.0)
                n = 4

                v = ToQUBO.Encoding.encode!(
                    model,
                    ToQUBO.Encoding.Unary{Float64}(),
                    x,
                    n,
                    (a, b),
                )
                y = ToQUBO.Virtual.target(v)

                @test length(y) == n

                @test ToQUBO.Virtual.source(v) == x
                @test ToQUBO.Encoding.expansion(v) ≈ PBO.PBF{VI,Float64}(
                    y[1] => 1.0,
                    y[2] => 1.0,
                    y[3] => 1.0,
                    y[4] => 1.0,
                    nothing => a,
                )
                @test isnothing(ToQUBO.Encoding.penaltyfn(v))

                @test model.variables == [v]
                @test model.source[ToQUBO.Virtual.source(v)] == (v)
                @test [model.target[y] for y in ToQUBO.Virtual.target(v)] == [v, v, v, v]
            end

            @testset "Binary ℤ" begin
                model = ToQUBO.Virtual.Model()

                x = MOI.add_variable(model.source_model)
                a, b = (-2.0, 2.0)

                v = ToQUBO.Encoding.encode!(
                    model,
                    ToQUBO.Encoding.Binary{Float64}(),
                    x,
                    (a, b),
                )
                y = ToQUBO.Virtual.target(v)

                @test length(y) == 3

                @test ToQUBO.Virtual.source(v) == x
                @test ToQUBO.Encoding.expansion(v) == PBO.PBF{VI,Float64}(
                    y[1] => 1.0,
                    y[2] => 2.0,
                    y[3] => 1.0,
                    nothing => a,
                )
                @test isnothing(ToQUBO.Encoding.penaltyfn(v))

                @test model.variables == [v]
                @test model.source[ToQUBO.Virtual.source(v)] == (v)
                @test [model.target[y] for y in ToQUBO.Virtual.target(v)] == [v, v, v]

                return nothing
            end

            @testset "Binary ℝ" begin
                model = ToQUBO.Virtual.Model()

                x = MOI.add_variable(model.source_model)
                a, b = (-2.0, 2.0)
                n = 3

                v = ToQUBO.Encoding.encode!(
                    model,
                    ToQUBO.Encoding.Binary{Float64}(),
                    x,
                    n,
                    (a, b),
                )
                y = ToQUBO.Virtual.target(v)

                @test length(y) == n

                @test ToQUBO.Virtual.source(v) == x
                @test ToQUBO.Encoding.expansion(v) ≈ PBO.PBF{VI,Float64}(
                    y[1] => 4 / 7,
                    y[2] => 8 / 7,
                    y[3] => 16 / 7,
                    nothing => a,
                )
                @test isnothing(ToQUBO.Encoding.penaltyfn(v))

                @test model.variables == [v]
                @test model.source[ToQUBO.Virtual.source(v)] == (v)
                @test [model.target[y] for y in ToQUBO.Virtual.target(v)] == [v, v, v]
            end

            @testset "Arithmetic ℤ" begin
                model = ToQUBO.Virtual.Model()

                x = MOI.add_variable(model.source_model)
                a, b = (-2.0, 2.0)

                v = ToQUBO.Encoding.encode!(
                    model,
                    ToQUBO.Encoding.Arithmetic{Float64}(),
                    x,
                    (a, b),
                )
                y = ToQUBO.Virtual.target(v)

                @test length(y) == 3

                @test ToQUBO.Virtual.source(v) == x
                @test ToQUBO.Encoding.expansion(v) == PBO.PBF{VI,Float64}(
                    y[1] => 1.0,
                    y[2] => 2.0,
                    y[3] => 1.0,
                    nothing => a,
                )
                @test isnothing(ToQUBO.Encoding.penaltyfn(v))

                @test model.variables == [v]
                @test model.source[ToQUBO.Virtual.source(v)] == (v)
                @test [model.target[y] for y in ToQUBO.Virtual.target(v)] == [v, v, v]
            end

            @testset "Arithmetic ℝ" begin
                model = ToQUBO.Virtual.Model()

                x = MOI.add_variable(model.source_model)
                a, b = (-2.0, 2.0)
                n = 3

                v = ToQUBO.Encoding.encode!(
                    model,
                    ToQUBO.Encoding.Arithmetic{Float64}(),
                    x,
                    n,
                    (a, b),
                )
                y = ToQUBO.Virtual.target(v)

                @test length(y) == n

                @test ToQUBO.Virtual.source(v) == x
                @test ToQUBO.Encoding.expansion(v) ≈ PBO.PBF{VI,Float64}(
                    y[1] => 2 / 3,
                    y[2] => 4 / 3,
                    y[3] => 6 / 3,
                    nothing => a,
                )
                @test isnothing(ToQUBO.Encoding.penaltyfn(v))

                @test model.variables == [v]
                @test model.source[ToQUBO.Virtual.source(v)] == (v)
                @test [model.target[y] for y in ToQUBO.Virtual.target(v)] == [v, v, v]
            end

            @testset "One Hot" begin
                model = ToQUBO.Virtual.Model()

                x = MOI.add_variable(model.source_model)
                γ = [-1.0, -0.5, 0.0, 0.5, 1.0]

                v = ToQUBO.Encoding.encode!(model, ToQUBO.Encoding.OneHot{Float64}(), x, γ)
                y = ToQUBO.Virtual.target(v)

                @test length(y) == length(γ)

                @test ToQUBO.Virtual.source(v) == x
                @test ToQUBO.Encoding.expansion(v) ≈ PBO.PBF{VI,Float64}(
                    y[1] => -1.0,
                    y[2] => -0.5,
                    y[4] => 0.5,
                    y[5] => 1.0,
                )
                @test ToQUBO.Encoding.penaltyfn(v) ≈ (PBO.PBF{VI,Float64}(-1.0, y...)^2)

                @test model.variables == [v]
                @test model.source[ToQUBO.Virtual.source(v)] == (v)
                @test [model.target[y] for y in ToQUBO.Virtual.target(v)] == [v, v, v, v, v]
            end

            @testset "One Hot ℤ" begin
                model = ToQUBO.Virtual.Model()

                x = MOI.add_variable(model.source_model)
                a, b = (-2.0, 2.0)

                v = ToQUBO.Encoding.encode!(
                    model,
                    ToQUBO.Encoding.OneHot{Float64}(),
                    x,
                    (a, b),
                )
                y = ToQUBO.Virtual.target(v)

                @test length(y) == 5

                @test ToQUBO.Virtual.source(v) == x
                @test ToQUBO.Encoding.expansion(v) ≈ PBO.PBF{VI,Float64}(
                    y[1] => -2.0,
                    y[2] => -1.0,
                    y[4] => 1.0,
                    y[5] => 2.0,
                )
                @test ToQUBO.Encoding.penaltyfn(v) ≈ (PBO.PBF{VI,Float64}(-1.0, y...)^2)

                @test model.variables == [v]
                @test model.source[ToQUBO.Virtual.source(v)] == (v)
                @test [model.target[y] for y in ToQUBO.Virtual.target(v)] == [v, v, v, v, v]
            end
            @testset "One Hot ℝ" begin
                model = ToQUBO.Virtual.Model()

                x = MOI.add_variable(model.source_model)
                a, b = (-2.0, 2.0)
                n = 5

                v = ToQUBO.Encoding.encode!(
                    model,
                    ToQUBO.Encoding.OneHot{Float64}(),
                    x,
                    n,
                    (a, b),
                )
                y = ToQUBO.Virtual.target(v)

                @test length(y) == n

                @test ToQUBO.Virtual.source(v) == x
                @test ToQUBO.Encoding.expansion(v) ≈ PBO.PBF{VI,Float64}(
                    y[1] => -2.0,
                    y[2] => -1.0,
                    y[4] => 1.0,
                    y[5] => 2.0,
                )
                @test ToQUBO.Encoding.penaltyfn(v) ≈ (PBO.PBF{VI,Float64}(-1.0, y...)^2)

                @test model.variables == [v]
                @test model.source[ToQUBO.Virtual.source(v)] == (v)
                @test [model.target[y] for y in ToQUBO.Virtual.target(v)] == [v, v, v, v, v]
            end
            @testset "Domain Wall ℤ" begin
                model = ToQUBO.Virtual.Model()

                x = MOI.add_variable(model.source_model)
                a, b = (-2.0, 2.0)

                v = ToQUBO.Encoding.encode!(
                    model,
                    ToQUBO.Encoding.DomainWall{Float64}(),
                    x,
                    (a, b),
                )
                y = ToQUBO.Virtual.target(v)

                @test length(y) == 4

                @test ToQUBO.Virtual.source(v) == x
                @test ToQUBO.Encoding.expansion(v) ≈ PBO.PBF{VI,Float64}(
                    y[1] => -1.0,
                    y[2] => -1.0,
                    y[3] => -1.0,
                    y[4] => -1.0,
                )
                @test ToQUBO.Encoding.penaltyfn(v) ≈ PBO.PBF{VI,Float64}(
                    y[2] => 2.0,
                    y[3] => 2.0,
                    y[4] => 2.0,
                    [y[1], y[2]] => -2.0,
                    [y[2], y[3]] => -2.0,
                    [y[3], y[4]] => -2.0,
                )

                @test model.variables == [v]
                @test model.source[ToQUBO.Virtual.source(v)] == (v)
                @test [model.target[y] for y in ToQUBO.Virtual.target(v)] == [v, v, v, v]
            end

            @testset "Domain Wall ℝ" begin
                model = ToQUBO.Virtual.Model()

                x = MOI.add_variable(model.source_model)
                a, b = (-2.0, 2.0)
                n = 5

                v = ToQUBO.Encoding.encode!(
                    model,
                    ToQUBO.Encoding.DomainWall{Float64}(),
                    x,
                    n,
                    (a, b),
                )
                y = ToQUBO.Virtual.target(v)

                @test length(y) == n - 1

                @test ToQUBO.Virtual.source(v) == x
                @test ToQUBO.Encoding.expansion(v) ≈ PBO.PBF{VI,Float64}(
                    y[1] => -1.0,
                    y[2] => -1.0,
                    y[3] => -1.0,
                    y[4] => -1.0,
                )
                @test ToQUBO.Encoding.penaltyfn(v) ≈ PBO.PBF{VI,Float64}(
                    y[2] => 2.0,
                    y[3] => 2.0,
                    y[4] => 2.0,
                    [y[1], y[2]] => -2.0,
                    [y[2], y[3]] => -2.0,
                    [y[3], y[4]] => -2.0,
                )

                @test model.variables == [v]
                @test model.source[ToQUBO.Virtual.source(v)] == (v)
                @test [model.target[y] for y in ToQUBO.Virtual.target(v)] == [v, v, v, v]
            end

            @testset "Bounded(Unary) ℤ" begin
                model = ToQUBO.Virtual.Model()

                x = MOI.add_variable(model.source_model)
                a, b = (-10.0, 10.0)

                v = ToQUBO.Encoding.encode!(
                    model,
                    ToQUBO.Encoding.Bounded(ToQUBO.Encoding.Unary{Float64}(), 5.0),
                    x,
                    (a, b),
                )
                y = ToQUBO.Virtual.target(v)

                @test length(y) == 8
                @test ToQUBO.Virtual.source(v) == x
                @test ToQUBO.Encoding.expansion(v) == PBO.PBF{VI,Float64}(
                    y[1] => 1.0,
                    y[2] => 1.0,
                    y[3] => 1.0,
                    y[4] => 1.0,
                    y[5] => 1.0,
                    y[6] => 5.0,
                    y[7] => 5.0,
                    y[8] => 5.0,
                    nothing => a,
                )
                @test isnothing(ToQUBO.Encoding.penaltyfn(v))

                @test model.variables == [v]
                @test model.source[ToQUBO.Virtual.source(v)] == (v)
                @test [model.target[y] for y in ToQUBO.Virtual.target(v)] == [v, v, v, v, v, v, v, v]
            end

            @testset "Bounded(Binary) ℤ" begin
                model = ToQUBO.Virtual.Model()

                x = MOI.add_variable(model.source_model)
                a, b = (-10.0, 10.0)

                v = ToQUBO.Encoding.encode!(
                    model,
                    ToQUBO.Encoding.Bounded(ToQUBO.Encoding.Binary{Float64}(), 5.0),
                    x,
                    (a, b),
                )
                y = ToQUBO.Virtual.target(v)

                @test length(y) == 6
                @test ToQUBO.Virtual.source(v) == x
                @test ToQUBO.Encoding.expansion(v) == PBO.PBF{VI,Float64}(
                    y[1] => 1.0,
                    y[2] => 2.0,
                    y[3] => 4.0,
                    y[4] => 3.0,
                    y[5] => 5.0,
                    y[6] => 5.0,
                    nothing => a,
                )
                @test isnothing(ToQUBO.Encoding.penaltyfn(v))

                @test model.variables == [v]
                @test model.source[ToQUBO.Virtual.source(v)] == (v)
                @test [model.target[y] for y in ToQUBO.Virtual.target(v)] == [v, v, v, v, v, v]
            end

            @testset "Bounded(Arithmetic) ℤ" begin
                model = ToQUBO.Virtual.Model()

                x = MOI.add_variable(model.source_model)
                a, b = (-10.0, 10.0)

                v = ToQUBO.Encoding.encode!(
                    model,
                    ToQUBO.Encoding.Bounded(ToQUBO.Encoding.Arithmetic{Float64}(), 5.0),
                    x,
                    (a, b),
                )
                y = ToQUBO.Virtual.target(v)

                @test length(y) == 6
                @test ToQUBO.Virtual.source(v) == x
                @test ToQUBO.Encoding.expansion(v) == PBO.PBF{VI,Float64}(
                    y[1] => 1.0,
                    y[2] => 2.0,
                    y[3] => 3.0,
                    y[4] => 4.0,
                    y[5] => 5.0,
                    y[6] => 5.0,
                    nothing => a,
                )
                @test isnothing(ToQUBO.Encoding.penaltyfn(v))

                @test model.variables == [v]
                @test model.source[ToQUBO.Virtual.source(v)] == (v)
                @test [model.target[y] for y in ToQUBO.Virtual.target(v)] == [v, v, v, v, v, v]
            end
        end
    end

    return nothing
end