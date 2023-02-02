function test_virtual()
    @testset "VirtualMapping" verbose = true begin
        @testset "Virtual Model" begin
            model = ToQUBO.VirtualModel()

            @test MOI.is_empty(model)
        end

        @testset "Encodings" verbose = true begin
            @testset "Linear" begin
                model = ToQUBO.VirtualModel()

                x = MOI.add_variable(model.source_model)
                γ = [1.0, 2.0, 3.0]
                α = 1.0

                v = ToQUBO.encode!(model, ToQUBO.Linear(), x, γ, α)
                y = ToQUBO.target(v)

                @test length(y) == 3

                @test ToQUBO.source(v) == x
                @test ToQUBO.expansion(v) == PBO.PBF{VI,Float64}(
                    y[1] => γ[1],
                    y[2] => γ[2],
                    y[3] => γ[3],
                    nothing => α,
                )
                @test isnothing(ToQUBO.penaltyfn(v))

                @test model.variables                             == [v]
                @test model.source[ToQUBO.source(v)]              == (v)
                @test [model.target[y] for y in ToQUBO.target(v)] == [v, v, v]
            end

            @testset "Mirror" begin
                model = ToQUBO.VirtualModel()

                x = MOI.add_variable(model.source_model)

                v = ToQUBO.encode!(model, ToQUBO.Mirror(), x)
                y = ToQUBO.target(v)

                @test length(y) == 1

                @test ToQUBO.source(v)    == x
                @test ToQUBO.expansion(v) == PBO.PBF{VI,Float64}(y[1])
                @test isnothing(ToQUBO.penaltyfn(v))

                @test model.variables                             == [v]
                @test model.source[ToQUBO.source(v)]              == (v)
                @test [model.target[y] for y in ToQUBO.target(v)] == [v]
            end

            @testset "Unary ℤ" begin
                model = ToQUBO.VirtualModel()

                x = MOI.add_variable(model.source_model)
                a, b = (-2.0, 2.0)

                v = ToQUBO.encode!(model, ToQUBO.Unary(), x, a, b)
                y = ToQUBO.target(v)

                @test length(y) == 4

                @test ToQUBO.source(v) == x
                @test ToQUBO.expansion(v) == PBO.PBF{VI,Float64}(
                    y[1] => 1.0,
                    y[2] => 1.0,
                    y[3] => 1.0,
                    y[4] => 1.0,
                    nothing => a,
                )
                @test isnothing(ToQUBO.penaltyfn(v))

                @test model.variables                             == [v]
                @test model.source[ToQUBO.source(v)]              == (v)
                @test [model.target[y] for y in ToQUBO.target(v)] == [v, v, v, v]
            end

            @testset "Unary ℝ" begin
                model = ToQUBO.VirtualModel()

                x = MOI.add_variable(model.source_model)
                a, b = (-2.0, 2.0)
                n = 4

                v = ToQUBO.encode!(model, ToQUBO.Unary(), x, a, b, n)
                y = ToQUBO.target(v)

                @test length(y) == n

                @test ToQUBO.source(v) == x
                @test ToQUBO.expansion(v) ≈ PBO.PBF{VI,Float64}(
                    y[1] => 1.0,
                    y[2] => 1.0,
                    y[3] => 1.0,
                    y[4] => 1.0,
                    nothing => a,
                )
                @test isnothing(ToQUBO.penaltyfn(v))

                @test model.variables                             == [v]
                @test model.source[ToQUBO.source(v)]              == (v)
                @test [model.target[y] for y in ToQUBO.target(v)] == [v, v, v, v]
            end

            @testset "Binary ℤ" begin
                model = ToQUBO.VirtualModel()

                x = MOI.add_variable(model.source_model)
                a, b = (-2.0, 2.0)

                v = ToQUBO.encode!(model, ToQUBO.Binary(), x, a, b)
                y = ToQUBO.target(v)

                @test length(y) == 3

                @test ToQUBO.source(v) == x
                @test ToQUBO.expansion(v) == PBO.PBF{VI,Float64}(
                    y[1] => 1.0,
                    y[2] => 2.0,
                    y[3] => 1.0,
                    nothing => a,
                )
                @test isnothing(ToQUBO.penaltyfn(v))

                @test model.variables                             == [v]
                @test model.source[ToQUBO.source(v)]              == (v)
                @test [model.target[y] for y in ToQUBO.target(v)] == [v, v, v]
            end

            @testset "Binary ℝ" begin
                model = ToQUBO.VirtualModel()

                x = MOI.add_variable(model.source_model)
                a, b = (-2.0, 2.0)
                n = 3

                v = ToQUBO.encode!(model, ToQUBO.Binary(), x, a, b, n)
                y = ToQUBO.target(v)

                @test length(y) == n

                @test ToQUBO.source(v) == x
                @test ToQUBO.expansion(v) ≈ PBO.PBF{VI,Float64}(
                    y[1] =>  4 / 7,
                    y[2] =>  8 / 7,
                    y[3] => 16 / 7,
                    nothing => a,
                )
                @test isnothing(ToQUBO.penaltyfn(v))

                @test model.variables                             == [v]
                @test model.source[ToQUBO.source(v)]              == (v)
                @test [model.target[y] for y in ToQUBO.target(v)] == [v, v, v]
            end

            @testset "Arithmetic ℤ" begin
                model = ToQUBO.VirtualModel()

                x = MOI.add_variable(model.source_model)
                a, b = (-2.0, 2.0)

                v = ToQUBO.encode!(model, ToQUBO.Arithmetic(), x, a, b)
                y = ToQUBO.target(v)

                @test length(y) == 3

                @test ToQUBO.source(v) == x
                @test ToQUBO.expansion(v) == PBO.PBF{VI,Float64}(
                    y[1] => 1.0,
                    y[2] => 2.0,
                    y[3] => 1.0,
                    nothing => a,
                )
                @test isnothing(ToQUBO.penaltyfn(v))

                @test model.variables                             == [v]
                @test model.source[ToQUBO.source(v)]              == (v)
                @test [model.target[y] for y in ToQUBO.target(v)] == [v, v, v]
            end

            @testset "Arithmetic ℝ" begin
                model = ToQUBO.VirtualModel()

                x = MOI.add_variable(model.source_model)
                a, b = (-2.0, 2.0)
                n = 3

                v = ToQUBO.encode!(model, ToQUBO.Arithmetic(), x, a, b, n)
                y = ToQUBO.target(v)

                @test length(y) == n

                @test ToQUBO.source(v) == x
                @test ToQUBO.expansion(v) ≈ PBO.PBF{VI,Float64}(
                    y[1] =>  2 / 3,
                    y[2] =>  4 / 3,
                    y[3] =>  6 / 3,
                    nothing => a,
                )
                @test isnothing(ToQUBO.penaltyfn(v))

                @test model.variables                             == [v]
                @test model.source[ToQUBO.source(v)]              == (v)
                @test [model.target[y] for y in ToQUBO.target(v)] == [v, v, v]
            end

            @testset "One Hot" begin
                model = ToQUBO.VirtualModel()

                x = MOI.add_variable(model.source_model)
                γ = [-1.0, -0.5, 0.0, 0.5, 1.0]

                v = ToQUBO.encode!(model, ToQUBO.OneHot(), x, γ)
                y = ToQUBO.target(v)

                @test length(y) == length(γ)

                @test ToQUBO.source(v) == x
                @test ToQUBO.expansion(v) ≈ PBO.PBF{VI,Float64}(
                    y[1] => -1.0,
                    y[2] => -0.5,
                    y[4] => 0.5,
                    y[5] => 1.0,
                )
                @test ToQUBO.penaltyfn(v) ≈ (PBO.PBF{VI,Float64}(-1.0, y...)^2)

                @test model.variables                             == [v]
                @test model.source[ToQUBO.source(v)]              == (v)
                @test [model.target[y] for y in ToQUBO.target(v)] == [v, v, v, v, v]
            end

            @testset "One Hot ℤ" begin
                model = ToQUBO.VirtualModel()

                x = MOI.add_variable(model.source_model)
                a, b = (-2.0, 2.0)

                v = ToQUBO.encode!(model, ToQUBO.OneHot(), x, a, b)
                y = ToQUBO.target(v)

                @test length(y) == 5

                @test ToQUBO.source(v) == x
                @test ToQUBO.expansion(v) ≈ PBO.PBF{VI,Float64}(
                    y[1] => -2.0,
                    y[2] => -1.0,
                    y[4] => 1.0,
                    y[5] => 2.0,
                )
                @test ToQUBO.penaltyfn(v) ≈ (PBO.PBF{VI,Float64}(-1.0, y...)^2)

                @test model.variables                             == [v]
                @test model.source[ToQUBO.source(v)]              == (v)
                @test [model.target[y] for y in ToQUBO.target(v)] == [v, v, v, v, v]
            end
            @testset "One Hot ℝ" begin
                model = ToQUBO.VirtualModel()

                x = MOI.add_variable(model.source_model)
                a, b = (-2.0, 2.0)
                n = 5

                v = ToQUBO.encode!(model, ToQUBO.OneHot(), x, a, b, n)
                y = ToQUBO.target(v)

                @test length(y) == n

                @test ToQUBO.source(v) == x
                @test ToQUBO.expansion(v) ≈ PBO.PBF{VI,Float64}(
                    y[1] => -2.0,
                    y[2] => -1.0,
                    y[4] => 1.0,
                    y[5] => 2.0,
                )
                @test ToQUBO.penaltyfn(v) ≈ (PBO.PBF{VI,Float64}(-1.0, y...)^2)

                @test model.variables                             == [v]
                @test model.source[ToQUBO.source(v)]              == (v)
                @test [model.target[y] for y in ToQUBO.target(v)] == [v, v, v, v, v]
            end
            @testset "Domain Wall ℤ" begin
                model = ToQUBO.VirtualModel()

                x = MOI.add_variable(model.source_model)
                a, b = (-2.0, 2.0)

                v = ToQUBO.encode!(model, ToQUBO.DomainWall(), x, a, b)
                y = ToQUBO.target(v)

                @test length(y) == 4

                @test ToQUBO.source(v) == x
                @test ToQUBO.expansion(v) ≈ PBO.PBF{VI,Float64}(
                    y[1] => -1.0,
                    y[2] => -1.0,
                    y[3] => -1.0,
                    y[4] => -1.0,
                )
                @test ToQUBO.penaltyfn(v) ≈ PBO.PBF{VI,Float64}(
                    y[2] => 2.0,
                    y[3] => 2.0,
                    y[4] => 2.0,
                    [y[1], y[2]] => -2.0,
                    [y[2], y[3]] => -2.0,
                    [y[3], y[4]] => -2.0,
                )

                @test model.variables                             == [v]
                @test model.source[ToQUBO.source(v)]              == (v)
                @test [model.target[y] for y in ToQUBO.target(v)] == [v, v, v, v]
            end

            @testset "Domain Wall ℝ" begin
                model = ToQUBO.VirtualModel()

                x = MOI.add_variable(model.source_model)
                a, b = (-2.0, 2.0)
                n = 5

                v = ToQUBO.encode!(model, ToQUBO.DomainWall(), x, a, b, n)
                y = ToQUBO.target(v)

                @test length(y) == n - 1

                @test ToQUBO.source(v) == x
                @test ToQUBO.expansion(v) ≈ PBO.PBF{VI,Float64}(
                    y[1] => -1.0,
                    y[2] => -1.0,
                    y[3] => -1.0,
                    y[4] => -1.0,
                )
                @test ToQUBO.penaltyfn(v) ≈ PBO.PBF{VI,Float64}(
                    y[2] => 2.0,
                    y[3] => 2.0,
                    y[4] => 2.0,
                    [y[1], y[2]] => -2.0,
                    [y[2], y[3]] => -2.0,
                    [y[3], y[4]] => -2.0,
                )

                @test model.variables                             == [v]
                @test model.source[ToQUBO.source(v)]              == (v)
                @test [model.target[y] for y in ToQUBO.target(v)] == [v, v, v, v]
            end

            @testset "Bounded(Unary) ℤ" begin
                model = ToQUBO.VirtualModel()

                x = MOI.add_variable(model.source_model)
                a, b = (-10.0, 10.0)

                v = ToQUBO.encode!(model, ToQUBO.Bounded{ToQUBO.Unary}(5.0), x, a, b)
                y = ToQUBO.target(v)

                @test length(y)           == 8
                @test ToQUBO.source(v)    == x
                @test ToQUBO.expansion(v) == PBO.PBF{VI,Float64}(
                    y[1] => 1.0,
                    y[2] => 1.0,
                    y[3] => 1.0,
                    y[4] => 1.0,
                    y[5] => 5.0,
                    y[6] => 5.0,
                    y[7] => 5.0,
                    y[8] => 1.0,
                    nothing => a,
                )
                @test isnothing(ToQUBO.penaltyfn(v))

                @test model.variables                             == [v]
                @test model.source[ToQUBO.source(v)]              == (v)
                @test [model.target[y] for y in ToQUBO.target(v)] == [v, v, v, v, v, v, v, v]
            end

            @testset "Bounded(Binary) ℤ" begin
                model = ToQUBO.VirtualModel()

                x = MOI.add_variable(model.source_model)
                a, b = (-10.0, 10.0)

                v = ToQUBO.encode!(model, ToQUBO.Bounded{ToQUBO.Binary}(5.0), x, a, b)
                y = ToQUBO.target(v)

                @test length(y)           == 6
                @test ToQUBO.source(v)    == x
                @test ToQUBO.expansion(v) == PBO.PBF{VI,Float64}(
                    y[1] => 1.0,
                    y[2] => 2.0,
                    y[3] => 4.0,
                    y[4] => 5.0,
                    y[5] => 5.0,
                    y[6] => 3.0,
                    nothing => a,
                )
                @test isnothing(ToQUBO.penaltyfn(v))

                @test model.variables                             == [v]
                @test model.source[ToQUBO.source(v)]              == (v)
                @test [model.target[y] for y in ToQUBO.target(v)] == [v, v, v, v, v, v]
            end
        end
    end
end