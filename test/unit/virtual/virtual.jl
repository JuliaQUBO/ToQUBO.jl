function test_virtual_model()
    @testset "→ Virtual.Model" begin
        @testset "Construction" begin
            # Test model without optimizer
            let model = ToQUBO.Virtual.Model{Float64}()
                @test model isa ToQUBO.Virtual.Model{Float64, Nothing}
                @test isnothing(model.optimizer)
                @test isempty(model.variables)
                @test isempty(model.source)
                @test isempty(model.target)
                @test isempty(model.slack)
            end

            # Test default Float64 model
            let model = ToQUBO.Virtual.Model()
                @test model isa ToQUBO.Virtual.Model{Float64, Nothing}
            end
        end

        @testset "Variable operations" begin
            let model = ToQUBO.Virtual.Model{Float64}()
                # Add a variable through source model
                x = MOI.add_variable(model.source_model)

                @test x == VI(1)
                @test MOI.get(model.source_model, MOI.NumberOfVariables()) == 1
            end
        end

        @testset "Settings" begin
            let model = ToQUBO.Virtual.Model{Float64}()
                @test isempty(model.compiler_settings)
                @test isempty(model.variable_settings)
                @test isempty(model.constraint_settings)
                @test isempty(model.moi_settings)
            end
        end
    end

    return nothing
end

function test_virtual_variable()
    @testset "→ Virtual.Variable" begin
        @testset "Construction" begin
            let
                e = ToQUBO.Encoding.Mirror{Float64}()
                x = VI(1)
                y = VI[VI(2)]
                ξ = PBO.PBF{VI,Float64}(VI(2))
                χ = nothing

                v = ToQUBO.Virtual.Variable{Float64}(e, x, y, ξ, χ)

                @test ToQUBO.Virtual.source(v) == x
                @test ToQUBO.Virtual.target(v) == y
                @test ToQUBO.Virtual.encoding(v) == e
                @test ToQUBO.Virtual.expansion(v) == ξ
                @test ToQUBO.Virtual.penaltyfn(v) === χ
            end
        end

        @testset "With penalty function" begin
            let
                e = ToQUBO.Encoding.OneHot{Float64}()
                x = VI(1)
                y = VI[VI(2), VI(3), VI(4)]
                ξ = PBO.PBF{VI,Float64}(
                    y[1] => 1.0,
                    y[2] => 2.0,
                    y[3] => 3.0,
                )
                χ = PBO.PBF{VI,Float64}([y; -1])^2

                v = ToQUBO.Virtual.Variable{Float64}(e, x, y, ξ, χ)

                @test ToQUBO.Virtual.source(v) == x
                @test ToQUBO.Virtual.target(v) == y
                @test ToQUBO.Virtual.encoding(v) == e
                @test ToQUBO.Virtual.expansion(v) == ξ
                @test !isnothing(ToQUBO.Virtual.penaltyfn(v))
            end
        end

        @testset "Constraint index as source" begin
            let
                e = ToQUBO.Encoding.Unary{Float64}()
                c = CI{MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}}(1)
                y = VI[VI(1), VI(2), VI(3)]
                ξ = PBO.PBF{VI,Float64}(
                    y[1] => 1.0,
                    y[2] => 1.0,
                    y[3] => 1.0,
                    0.0,
                )
                χ = nothing

                v = ToQUBO.Virtual.Variable{Float64}(e, c, y, ξ, χ)

                @test ToQUBO.Virtual.source(v) == c
                @test ToQUBO.Virtual.target(v) == y
            end
        end

        @testset "Nothing as source" begin
            let
                e = ToQUBO.Encoding.Binary{Float64}()
                y = VI[VI(1), VI(2)]
                ξ = PBO.PBF{VI,Float64}(
                    y[1] => 1.0,
                    y[2] => 2.0,
                    0.0,
                )
                χ = nothing

                v = ToQUBO.Virtual.Variable{Float64}(e, nothing, y, ξ, χ)

                @test isnothing(ToQUBO.Virtual.source(v))
                @test ToQUBO.Virtual.target(v) == y
            end
        end
    end

    return nothing
end

function test_virtual_encoding()
    @testset "→ Virtual.Encoding" begin
        @testset "encode! with Mirror" begin
            let model = ToQUBO.Virtual.Model{Float64}()
                x = VI(1)
                e = ToQUBO.Encoding.Mirror{Float64}()

                v = ToQUBO.Encoding.encode!(model, x, e)

                @test length(model.variables) == 1
                @test haskey(model.source, x)
                @test length(model.target) == 1
            end
        end

        @testset "encode! with Unary (interval)" begin
            let model = ToQUBO.Virtual.Model{Float64}()
                x = VI(1)
                e = ToQUBO.Encoding.Unary{Float64}()
                S = (-2.0, 2.0)  # Integer interval

                v = ToQUBO.Virtual.encode!(model, x, e, S; tol = nothing)

                @test length(model.variables) == 1
                @test haskey(model.source, x)
                # Should have 4 binary variables for interval [-2, 2]
                @test length(model.target) == 4
            end
        end

        @testset "encode! with set" begin
            let model = ToQUBO.Virtual.Model{Float64}()
                x = VI(1)
                e = ToQUBO.Encoding.OneHot{Float64}()
                γ = Float64[1.0, 2.0, 3.0]

                v = ToQUBO.Encoding.encode!(model, x, e, γ)

                @test length(model.variables) == 1
                @test haskey(model.source, x)
                # Should have 3 binary variables for set {1, 2, 3}
                @test length(model.target) == 3
                # OneHot has penalty function
                @test haskey(model.h, x)
            end
        end

        @testset "encode! with constraint index" begin
            let model = ToQUBO.Virtual.Model{Float64}()
                c = CI{MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}}(1)
                e = ToQUBO.Encoding.Unary{Float64}()
                S = (0.0, 3.0)

                v = ToQUBO.Virtual.encode!(model, c, e, S; tol = nothing)

                @test length(model.variables) == 1
                @test haskey(model.slack, c)
                @test length(model.target) == 3
            end
        end

        @testset "encode! with fixed bits" begin
            let model = ToQUBO.Virtual.Model{Float64}()
                x = VI(1)
                e = ToQUBO.Encoding.Binary{Float64}()
                S = (-2.0, 2.0)
                n = 8

                v = ToQUBO.Encoding.encode!(model, x, e, S, n)

                @test length(model.variables) == 1
                @test haskey(model.source, x)
                @test length(model.target) == n
            end
        end
    end

    return nothing
end

function test_virtual()
    @testset "□ Virtual Module" verbose = true begin
        test_virtual_model()
        test_virtual_variable()
        test_virtual_encoding()
    end

    return nothing
end
