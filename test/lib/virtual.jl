struct VirtualModel{T} <: ToQUBO.AbstractVirtualModel{T}
    source_model::MOIU.Model{T}
    target_model::MOIU.Model{T}
    variables::Vector{ToQUBO.VirtualVariable{T}}
    source::Dict{VI,ToQUBO.VirtualVariable{T}}
    target::Dict{VI,ToQUBO.VirtualVariable{T}}

    function VirtualModel{T}(; kws...) where {T}
        new{T}(
            MOIU.Model{T}(),
            MOIU.Model{T}(),
            ToQUBO.VirtualVariable{T}[],
            Dict{VI,ToQUBO.VirtualVariable{T}}(),
            Dict{VI,ToQUBO.VirtualVariable{T}}(),
        )
    end

    VirtualModel(; kws...) = VirtualModel{Float64}(; kws...)
end

MOI.get(model::VirtualModel, ::ToQUBO.SourceModel)                 = model.source_model
MOI.get(model::VirtualModel, ::ToQUBO.TargetModel)                 = model.target_model
MOI.get(model::VirtualModel, ::ToQUBO.Variables)                   = model.variables
MOI.get(model::VirtualModel, ::ToQUBO.Source, x::VI)               = model.source[x]
MOI.set(model::VirtualModel, ::ToQUBO.Source, x::VI, v::ToQUBO.VV) = (model.source[x] = v)
MOI.get(model::VirtualModel, ::ToQUBO.Target, y::VI)               = model.target[y]
MOI.set(model::VirtualModel, ::ToQUBO.Target, y::VI, v::ToQUBO.VV) = (model.target[y] = v)

function test_virtual()
    @testset "VirtualMapping" verbose = true begin
        @testset "Virtual Model" begin
            model = VirtualModel()

            @test MOI.is_empty(model)
        end

        @testset "Encodings" verbose = true begin
            @testset "Linear" begin
                model = VirtualModel()

                x = MOI.add_variable(MOI.get(model, ToQUBO.SourceModel()))
                γ = [1.0, 2.0, 3.0]
                α = 1.0

                v = ToQUBO.encode!(ToQUBO.Linear(), model, x, γ, α)
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

                @test MOI.get(model, ToQUBO.Variables()) == [v]
                @test MOI.get(model, ToQUBO.Source(), ToQUBO.source(v)) == v
                @test MOI.get.(model, ToQUBO.Target(), ToQUBO.target(v)) == [v, v, v]
            end

            @testset "Mirror" begin
                model = VirtualModel()

                x = MOI.add_variable(MOI.get(model, ToQUBO.SourceModel()))

                v = ToQUBO.encode!(ToQUBO.Mirror(), model, x)
                y = ToQUBO.target(v)

                @test length(y) == 1

                @test ToQUBO.source(v)    == x
                @test ToQUBO.expansion(v) == PBO.PBF{VI,Float64}(y[1])
                @test isnothing(ToQUBO.penaltyfn(v))

                @test MOI.get(model, ToQUBO.Variables())                 == [v]
                @test MOI.get(model, ToQUBO.Source(), ToQUBO.source(v))  == v
                @test MOI.get.(model, ToQUBO.Target(), ToQUBO.target(v)) == [v]
            end

            @testset "Unary ℤ" begin
                model = VirtualModel()

                x = MOI.add_variable(MOI.get(model, ToQUBO.SourceModel()))
                a, b = (-2.0, 2.0)

                v = ToQUBO.encode!(ToQUBO.Unary(), model, x, a, b)
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

                @test MOI.get(model, ToQUBO.Variables())                 == [v]
                @test MOI.get(model, ToQUBO.Source(), ToQUBO.source(v))  == v
                @test MOI.get.(model, ToQUBO.Target(), ToQUBO.target(v)) == [v, v, v, v]
            end

            @testset "Unary ℝ" begin
                model = VirtualModel()

                x = MOI.add_variable(MOI.get(model, ToQUBO.SourceModel()))
                a, b = (-2.0, 2.0)
                n = 4

                v = ToQUBO.encode!(ToQUBO.Unary(), model, x, a, b, n)
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

                @test MOI.get(model, ToQUBO.Variables())                 == [v]
                @test MOI.get(model, ToQUBO.Source(), ToQUBO.source(v))  == v
                @test MOI.get.(model, ToQUBO.Target(), ToQUBO.target(v)) == [v, v, v, v]
            end

            @testset "Binary ℤ" begin
                model = VirtualModel()

                x = MOI.add_variable(MOI.get(model, ToQUBO.SourceModel()))
                a, b = (-2.0, 2.0)

                v = ToQUBO.encode!(ToQUBO.Binary(), model, x, a, b)
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

                @test MOI.get(model, ToQUBO.Variables())                 == [v]
                @test MOI.get(model, ToQUBO.Source(), ToQUBO.source(v))  == v
                @test MOI.get.(model, ToQUBO.Target(), ToQUBO.target(v)) == [v, v, v]
            end

            @testset "Binary ℝ" begin
                model = VirtualModel()

                x = MOI.add_variable(MOI.get(model, ToQUBO.SourceModel()))
                a, b = (-2.0, 2.0)
                n = 3

                v = ToQUBO.encode!(ToQUBO.Binary(), model, x, a, b, n)
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

                @test MOI.get(model, ToQUBO.Variables())                 == [v]
                @test MOI.get(model, ToQUBO.Source(), ToQUBO.source(v))  == v
                @test MOI.get.(model, ToQUBO.Target(), ToQUBO.target(v)) == [v, v, v]
            end

            @testset "Arithmetic ℤ" begin
                model = VirtualModel()

                x = MOI.add_variable(MOI.get(model, ToQUBO.SourceModel()))
                a, b = (-2.0, 2.0)

                v = ToQUBO.encode!(ToQUBO.Arithmetic(), model, x, a, b)
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

                @test MOI.get(model, ToQUBO.Variables())                 == [v]
                @test MOI.get(model, ToQUBO.Source(), ToQUBO.source(v))  == v
                @test MOI.get.(model, ToQUBO.Target(), ToQUBO.target(v)) == [v, v, v]
            end

            @testset "Arithmetic ℝ" begin
                model = VirtualModel()

                x = MOI.add_variable(MOI.get(model, ToQUBO.SourceModel()))
                a, b = (-2.0, 2.0)
                n = 3

                v = ToQUBO.encode!(ToQUBO.Arithmetic(), model, x, a, b, n)
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

                @test MOI.get(model, ToQUBO.Variables())                 == [v]
                @test MOI.get(model, ToQUBO.Source(), ToQUBO.source(v))  == v
                @test MOI.get.(model, ToQUBO.Target(), ToQUBO.target(v)) == [v, v, v]
            end

            @testset "One Hot" begin
                model = VirtualModel()

                x = MOI.add_variable(MOI.get(model, ToQUBO.SourceModel()))
                γ = [-1.0, -0.5, 0.0, 0.5, 1.0]

                v = ToQUBO.encode!(ToQUBO.OneHot(), model, x, γ)
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

                @test MOI.get(model, ToQUBO.Variables())                 == [v]
                @test MOI.get(model, ToQUBO.Source(), ToQUBO.source(v))  == v
                @test MOI.get.(model, ToQUBO.Target(), ToQUBO.target(v)) == [v, v, v, v, v]
            end

            @testset "One Hot ℤ" begin
                model = VirtualModel()

                x = MOI.add_variable(MOI.get(model, ToQUBO.SourceModel()))
                a, b = (-2.0, 2.0)

                v = ToQUBO.encode!(ToQUBO.OneHot(), model, x, a, b)
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

                @test MOI.get(model, ToQUBO.Variables())                 == [v]
                @test MOI.get(model, ToQUBO.Source(), ToQUBO.source(v))  == v
                @test MOI.get.(model, ToQUBO.Target(), ToQUBO.target(v)) == [v, v, v, v, v]
            end
            @testset "One Hot ℝ" begin
                model = VirtualModel()

                x = MOI.add_variable(MOI.get(model, ToQUBO.SourceModel()))
                a, b = (-2.0, 2.0)
                n = 5

                v = ToQUBO.encode!(ToQUBO.OneHot(), model, x, a, b, n)
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

                @test MOI.get(model, ToQUBO.Variables())                 == [v]
                @test MOI.get(model, ToQUBO.Source(), ToQUBO.source(v))  == v
                @test MOI.get.(model, ToQUBO.Target(), ToQUBO.target(v)) == [v, v, v, v, v]
            end
            @testset "Domain Wall ℤ" begin
                model = VirtualModel()

                x = MOI.add_variable(MOI.get(model, ToQUBO.SourceModel()))
                a, b = (-2.0, 2.0)

                v = ToQUBO.encode!(ToQUBO.DomainWall(), model, x, a, b)
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

                @test MOI.get(model, ToQUBO.Variables())                 == [v]
                @test MOI.get(model, ToQUBO.Source(), ToQUBO.source(v))  == v
                @test MOI.get.(model, ToQUBO.Target(), ToQUBO.target(v)) == [v, v, v, v]
            end

            @testset "Domain Wall ℝ" begin
                model = VirtualModel()

                x = MOI.add_variable(MOI.get(model, ToQUBO.SourceModel()))
                a, b = (-2.0, 2.0)
                n = 5

                v = ToQUBO.encode!(ToQUBO.DomainWall(), model, x, a, b, n)
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

                @test MOI.get(model, ToQUBO.Variables())                 == [v]
                @test MOI.get(model, ToQUBO.Source(), ToQUBO.source(v))  == v
                @test MOI.get.(model, ToQUBO.Target(), ToQUBO.target(v)) == [v, v, v, v]
            end
        end
    end
end