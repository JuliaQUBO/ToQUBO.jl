function test_variable_encoding_methods()
    @testset "→ Variables" begin
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

        @testset "⊛ Interval" begin
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

                    @testset "ℝ (fixed)" begin
                        let φ = PBO.vargen(VI)
                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S, 8)

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

                    @testset "ℝ (tolerance)" begin
                        let φ = PBO.vargen(VI)
                            @test ToQUBO.Encoding.encoding_bits(e, S, 1 / 4) == 5

                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S; tol = 1 / 4)

                            @test length(y) == 5
                            @test y == VI.([1, 2, 3, 4, 5])
                            @test ξ == PBO.PBF{VI,Float64}(
                                y[1] => 4 / 5,
                                y[2] => 4 / 5,
                                y[3] => 4 / 5,
                                y[4] => 4 / 5,
                                y[5] => 4 / 5,
                                -2.0,
                            )
                            @test isnothing(χ)
                        end
                    end
                end
            end

            @testset "⋅ Binary" begin
                let e = ToQUBO.Encoding.Binary{Float64}()
                    S = (-2.0, 2.0)

                    @testset "ℤ" begin
                        let φ = PBO.vargen(VI)
                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S)

                            @test length(y) == 3
                            @test y == VI.([1, 2, 3])
                            @test ξ == PBO.PBF{VI,Float64}(
                                y[1] => 1.0,
                                y[2] => 2.0,
                                y[3] => 1.0,
                                -2.0,
                            )
                            @test isnothing(χ)
                        end
                    end

                    @testset "ℝ (fixed)" begin
                        let φ = PBO.vargen(VI)
                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S, 8)

                            @test length(y) == 8
                            @test y == VI.([1, 2, 3, 4, 5, 6, 7, 8])
                            @test ξ == PBO.PBF{VI,Float64}(
                                y[1] => 4 / 255,
                                y[2] => 8 / 255,
                                y[3] => 16 / 255,
                                y[4] => 32 / 255,
                                y[5] => 64 / 255,
                                y[6] => 128 / 255,
                                y[7] => 256 / 255,
                                y[8] => 512 / 255,
                                -2.0,
                            )
                            @test isnothing(χ)
                        end
                    end

                    @testset "ℝ (tolerance)" begin
                        let φ = PBO.vargen(VI)
                            @test ToQUBO.Encoding.encoding_bits(e, S, 1 / 4) == 3

                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S; tol = 1 / 4)

                            @test length(y) == 3
                            @test y == VI.([1, 2, 3])
                            @test ξ == PBO.PBF{VI,Float64}(
                                y[1] => 4 / 7,
                                y[2] => 8 / 7,
                                y[3] => 16 / 7,
                                -2.0,
                            )
                            @test isnothing(χ)
                        end
                    end
                end
            end

            @testset "⋅ Arithmetic" begin
                let e = ToQUBO.Encoding.Arithmetic{Float64}()
                    S = (-2.0, 2.0)

                    @testset "ℤ" begin
                        let φ = PBO.vargen(VI)
                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S)

                            @test length(y) == 3
                            @test y == VI.([1, 2, 3])
                            @test ξ == PBO.PBF{VI,Float64}(
                                y[1] => 1.0,
                                y[2] => 2.0,
                                y[3] => 1.0,
                                -2.0,
                            )
                            @test isnothing(χ)
                        end
                    end

                    @testset "ℝ (fixed)" begin
                        let φ = PBO.vargen(VI)
                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S, 8)

                            @test length(y) == 8
                            @test y == VI.([1, 2, 3, 4, 5, 6, 7, 8])
                            @test ξ == PBO.PBF{VI,Float64}(
                                y[1] => 8 / 72,
                                y[2] => 16 / 72,
                                y[3] => 24 / 72,
                                y[4] => 32 / 72,
                                y[5] => 40 / 72,
                                y[6] => 48 / 72,
                                y[7] => 56 / 72,
                                y[8] => 64 / 72,
                                -2.0,
                            )
                            @test isnothing(χ)
                        end
                    end

                    @testset "ℝ (tolerance)" begin
                        let φ = PBO.vargen(VI)
                            @test ToQUBO.Encoding.encoding_bits(e, S, 1 / 12) == 4

                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S; tol = 1 / 12)

                            @test length(y) == 4
                            @test y == VI.([1, 2, 3, 4])
                            @test ξ == PBO.PBF{VI,Float64}(
                                y[1] => 8 / 20,
                                y[2] => 16 / 20,
                                y[3] => 24 / 20,
                                y[4] => 32 / 20,
                                -2.0,
                            )
                            @test isnothing(χ)
                        end
                    end
                end
            end
        end

        @testset "⊛ Set" begin
            @testset "⋅ One-Hot" begin
                let e = ToQUBO.Encoding.OneHot{Float64}()
                    S = (-2.0, 2.0)
                    Γ = [-1.0, -0.5, 0.0, 0.5, 1.0]

                    @testset "Γ ⊂ ℝ" begin
                        let φ = PBO.vargen(VI)
                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, Γ)

                            @test length(y) == 5
                            @test y == VI.([1, 2, 3, 4, 5])
                            @test ξ == PBO.PBF{VI,Float64}(
                                y[1] => -1.0,
                                y[2] => -0.5,
                                y[3] => 0.0,
                                y[4] => 0.5,
                                y[5] => 1.0,
                            )
                            @test χ == PBO.PBF{VI,Float64}(
                                [
                                    1.0
                                    [y[i] => -1.0 for i = 1:5]
                                    [(y[i], y[j]) => 2.0 for i = 1:5 for j = (i+1):5]
                                ],
                            )
                        end
                    end

                    @testset "ℤ" begin
                        let φ = PBO.vargen(VI)
                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S)

                            @test length(y) == 5
                            @test y == VI.([1, 2, 3, 4, 5])
                            @test ξ == PBO.PBF{VI,Float64}(
                                y[1] => -2.0,
                                y[2] => -1.0,
                                y[3] => 0.0,
                                y[4] => 1.0,
                                y[5] => 2.0,
                            )
                            @test χ == PBO.PBF{VI,Float64}(
                                [
                                    1.0
                                    [y[i] => -1.0 for i = 1:5]
                                    [(y[i], y[j]) => 2.0 for i = 1:5 for j = (i+1):5]
                                ],
                            )
                        end
                    end

                    @testset "ℝ (fixed)" begin
                        let φ = PBO.vargen(VI)

                        end
                    end

                    @testset "ℝ (tolerance)" begin
                        let φ = PBO.vargen(VI)

                        end
                    end
                end
            end

            @testset "⋅ Domain Wall" begin
                let e = ToQUBO.Encoding.DomainWall{Float64}()
                    S = (-2.0, 2.0)
                    Γ = [-1.0, -0.5, 0.0, 0.5, 1.0]

                    @testset "ℤ" begin
                        let φ = PBO.vargen(VI)

                        end
                    end

                    @testset "ℝ (fixed)" begin
                        let φ = PBO.vargen(VI)

                        end
                    end
                end
            end
        end

        #=

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
        =#
    end

    return nothing
end