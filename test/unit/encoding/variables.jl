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
                    @testset "ℤ" begin
                        let φ = PBO.vargen(VI)
                            S = (-2.0, 2.0)
                            n = 4

                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S)

                            @test length(y) == n
                            @test y == VI.(1:n)
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

                    @testset "ℤ (bounded)" begin
                        let μ = 2.0
                            ê = ToQUBO.Encoding.Bounded(e, μ)
                            φ = PBO.vargen(VI)
                            S = (-2.0, 2.0)
                            n = 3

                            y, ξ, χ = ToQUBO.Encoding.encode(φ, ê, S)

                            @test length(y) == n
                            @test y == VI.(1:n)
                            @test ξ == PBO.PBF{VI,Float64}(
                                y[1] => 1.0,
                                y[2] => 1.0,
                                y[3] => 2.0,
                                -2.0,
                            )
                            @test isnothing(χ)
                        end
                    end

                    @testset "ℝ (fixed)" begin
                        let φ = PBO.vargen(VI)
                            S = (-2.0, 2.0)
                            n = 8

                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S, n)

                            @test length(y) == n
                            @test y == VI.(1:n)
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

                    @testset "ℝ (fixed, bounded)" begin
                        let μ = 2.0
                            ê = ToQUBO.Encoding.Bounded(e, μ)
                            φ = PBO.vargen(VI)
                            S = (-2.0, 2.0)
                            n = 8

                            y, ξ, χ = ToQUBO.Encoding.encode(φ, ê, S, n)

                            @test length(y) == n
                            @test y == VI.(1:n)
                            @test ξ == PBO.PBF{VI,Float64}(
                                y[1] => 2 / 7,
                                y[2] => 2 / 7,
                                y[3] => 2 / 7,
                                y[4] => 2 / 7,
                                y[5] => 2 / 7,
                                y[6] => 2 / 7,
                                y[7] => 2 / 7,
                                y[8] => 2.0,
                                -2.0,
                            )
                            @test isnothing(χ)
                        end
                    end

                    @testset "ℝ (tolerance)" begin
                        let φ = PBO.vargen(VI)
                            S = (-2.0, 2.0)
                            n = 5

                            @test ToQUBO.Encoding.encoding_bits(e, S, 1 / 4) == n

                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S; tol = 1 / 4)

                            @test length(y) == n
                            @test y == VI.(1:n)
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

                    @testset "ℝ (tolerance, bounded)" begin
                        let μ = 2.0
                            ê = ToQUBO.Encoding.Bounded(e, μ)
                            φ = PBO.vargen(VI)
                            S = (-2.0, 2.0)
                            n = 4

                            @test ToQUBO.Encoding.encoding_bits(ê, S, 1 / 4) == n

                            y, ξ, χ = ToQUBO.Encoding.encode(φ, ê, S; tol = 1 / 4)

                            @test length(y) == n
                            @test y == VI.(1:n)
                            @test ξ == PBO.PBF{VI,Float64}(
                                y[1] => 2 / 3,
                                y[2] => 2 / 3,
                                y[3] => 2 / 3,
                                y[4] => 2.0,
                                -2.0,
                            )
                            @test isnothing(χ)
                        end
                    end
                end
            end

            @testset "⋅ Binary" begin
                let e = ToQUBO.Encoding.Binary{Float64}()
                    @testset "ℤ" begin
                        let φ = PBO.vargen(VI)
                            S = (-2.0, 2.0)
                            n = 3

                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S)

                            @test length(y) == n
                            @test y == VI.(1:n)
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
                            S = (-2.0, 2.0)
                            n = 8

                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S, n)

                            @test length(y) == n
                            @test y == VI.(1:n)
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
                            S = (-2.0, 2.0)
                            n = 3

                            @test ToQUBO.Encoding.encoding_bits(e, S, 1 / 4) == n

                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S; tol = 1 / 4)

                            @test length(y) == n
                            @test y == VI.(1:n)
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
                            @test y == VI.(1:3)
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
                            @test y == VI.(1:8)
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
                            @test y == VI.(1:4)
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
                    @testset "Γ ⊂ ℝ" begin
                        let φ = PBO.vargen(VI)
                            Γ = [-1.0, -0.5, 0.0, 0.5, 1.0]
                            n = 5

                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, Γ)

                            @test length(y) == n
                            @test y == VI.(1:n)
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
                                    [y[i] => -1.0 for i = 1:n]
                                    [(y[i], y[j]) => 2.0 for i = 1:n for j = (i+1):n]
                                ],
                            )
                        end
                    end

                    @testset "ℤ" begin
                        let φ = PBO.vargen(VI)
                            S = (-2.0, 2.0)
                            n = 5

                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S)

                            @test length(y) == n
                            @test y == VI.(1:n)
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
                                    [y[i] => -1.0 for i = 1:n]
                                    [(y[i], y[j]) => 2.0 for i = 1:n for j = (i+1):n]
                                ],
                            )
                        end
                    end

                    @testset "ℝ (fixed)" begin
                        let φ = PBO.vargen(VI)
                            S = (-2.0, 2.0)
                            n = 9

                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S, n)

                            @test length(y) == n
                            @test y == VI.(1:n)
                            @test ξ == PBO.PBF{VI,Float64}(
                                y[1] => -2.0,
                                y[2] => -1.5,
                                y[3] => -1.0,
                                y[4] => -0.5,
                                y[5] => 0.0,
                                y[6] => 0.5,
                                y[7] => 1.0,
                                y[8] => 1.5,
                                y[9] => 2.0,
                            )
                            @test χ == PBO.PBF{VI,Float64}(
                                [
                                    1.0
                                    [y[i] => -1.0 for i = 1:n]
                                    [(y[i], y[j]) => 2.0 for i = 1:n for j = (i+1):n]
                                ],
                            )
                        end
                    end

                    @testset "ℝ (tolerance)" begin
                        let φ = PBO.vargen(VI)
                            S = (-2.0, 2.0)
                            τ = 1 / 4
                            n = 17

                            @test ToQUBO.Encoding.encoding_points(e, S, τ) == n
                            @test ToQUBO.Encoding.encoding_bits(e, S, τ) == n

                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S; tol = τ)

                            @test length(y) == n
                            @test y == VI.(1:n)
                            @test ξ == PBO.PBF{VI,Float64}(
                                y[1] => -2.0,
                                y[2] => -1.75,
                                y[3] => -1.5,
                                y[4] => -1.25,
                                y[5] => -1.0,
                                y[6] => -0.75,
                                y[7] => -0.5,
                                y[8] => -0.25,
                                y[9] => 0.0,
                                y[10] => 0.25,
                                y[11] => 0.5,
                                y[12] => 0.75,
                                y[13] => 1.0,
                                y[14] => 1.25,
                                y[15] => 1.5,
                                y[16] => 1.75,
                                y[17] => 2.0,
                            )
                            @test χ == PBO.PBF{VI,Float64}(
                                [
                                    1.0
                                    [y[i] => -1.0 for i = 1:n]
                                    [(y[i], y[j]) => 2.0 for i = 1:n for j = (i+1):n]
                                ],
                            )
                        end
                    end
                end
            end

            @testset "⋅ Domain Wall" begin
                let e = ToQUBO.Encoding.DomainWall{Float64}()
                    @testset "Γ ⊂ ℝ" begin
                        let φ = PBO.vargen(VI)
                            Γ = [-1.0, -0.25, 0.0, 0.25, 1.0]
                            n = 4

                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, Γ)

                            @test length(y) == n
                            @test y == VI.(1:n)
                            @test ξ == PBO.PBF{VI,Float64}(
                                -1.0,
                                y[1] => 0.75,
                                y[2] => 0.25,
                                y[3] => 0.25,
                                y[4] => 0.75,
                            )
                            @test χ == PBO.PBF{VI,Float64}(
                                [
                                    [y[i] => 2.0 for i = 2:n]
                                    [(y[i], y[i+1]) => -2.0 for i = 1:(n-1)]
                                ],
                            )
                        end
                    end

                    @testset "ℤ" begin
                        let φ = PBO.vargen(VI)
                            S = (-2.0, 2.0)
                            n = 4

                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S)

                            @test length(y) == n
                            @test y == VI.(1:n)
                            @test ξ == PBO.PBF{VI,Float64}(
                                -2.0,
                                y[1] => 1.0,
                                y[2] => 1.0,
                                y[3] => 1.0,
                                y[4] => 1.0,
                            )
                            @test χ == PBO.PBF{VI,Float64}(
                                [
                                    [y[i] => 2.0 for i = 2:n]
                                    [(y[i], y[i+1]) => -2.0 for i = 1:(n-1)]
                                ],
                            )
                        end
                    end

                    @testset "ℝ (fixed)" begin
                        let φ = PBO.vargen(VI)
                            S = (-2.0, 2.0)
                            n = 8

                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S, n)

                            @test length(y) == n
                            @test y == VI.(1:n)
                            @test ξ == PBO.PBF{VI,Float64}(
                                -2.0,
                                y[1] => 0.5,
                                y[2] => 0.5,
                                y[3] => 0.5,
                                y[4] => 0.5,
                                y[5] => 0.5,
                                y[6] => 0.5,
                                y[7] => 0.5,
                                y[8] => 0.5,
                            )
                            @test χ == PBO.PBF{VI,Float64}(
                                [
                                    [y[i] => 2.0 for i = 2:n]
                                    [(y[i], y[i+1]) => -2.0 for i = 1:(n-1)]
                                ],
                            )
                        end
                    end

                    @testset "ℝ (tolerance)" begin
                        let φ = PBO.vargen(VI)
                            S = (-2.0, 2.0)
                            τ = 1 / 4
                            n = 16

                            @test ToQUBO.Encoding.encoding_points(e, S, τ) == n + 1
                            @test ToQUBO.Encoding.encoding_bits(e, S, τ) == n

                            y, ξ, χ = ToQUBO.Encoding.encode(φ, e, S; tol = τ)

                            @test length(y) == n
                            @test y == VI.(1:n)
                            @test ξ == PBO.PBF{VI,Float64}(
                                -2.0,
                                y[1] => 0.25,
                                y[2] => 0.25,
                                y[3] => 0.25,
                                y[4] => 0.25,
                                y[5] => 0.25,
                                y[6] => 0.25,
                                y[7] => 0.25,
                                y[8] => 0.25,
                                y[9] => 0.25,
                                y[10] => 0.25,
                                y[11] => 0.25,
                                y[12] => 0.25,
                                y[13] => 0.25,
                                y[14] => 0.25,
                                y[15] => 0.25,
                                y[16] => 0.25,
                            )
                            @test χ == PBO.PBF{VI,Float64}(
                                [
                                    [y[i] => 2.0 for i = 2:n]
                                    [(y[i], y[i+1]) => -2.0 for i = 1:(n-1)]
                                ],
                            )
                        end
                    end
                end
            end
        end
    end

    return nothing
end