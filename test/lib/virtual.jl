@testset "VirtualMapping" verbose = true begin

struct VirtualModel{T} <: VM.AbstractVirtualModel{T}
    source_model::MOIU.Model{T}
    target_model::MOIU.Model{T}
    variables::Vector{VM.VirtualVariable{<:Any, T}}
    source::Dict{VI, VM.VirtualVariable{<:Any, T}}
    target::Dict{VI, VM.VirtualVariable{<:Any, T}}

    function VirtualModel{T}(; kws...) where {T}
        new{T}(
            MOIU.Model{T}(),
            MOIU.Model{T}(),
            VM.VirtualVariable{<:Any, T}[],
            Dict{VI, VM.VirtualVariable{<:Any, T}}(),
            Dict{VI, VM.VirtualVariable{<:Any, T}}(),
        )
    end

    function VirtualModel(; kws...)
        VirtualModel{Float64}(; kws...)
    end
end

MOI.get(model::VirtualModel, ::VM.SourceModel) = model.source_model
MOI.get(model::VirtualModel, ::VM.TargetModel) = model.target_model
MOI.get(model::VirtualModel, ::VM.Variables) = model.variables
MOI.get(model::VirtualModel, ::VM.Source, x::VI) = model.source[x]
MOI.set(model::VirtualModel, ::VM.Source, x::VI, v::VM.VV) = (model.source[x] = v)
MOI.get(model::VirtualModel, ::VM.Target, y::VI) = model.target[y]
MOI.set(model::VirtualModel, ::VM.Target, y::VI, v::VM.VV) = (model.target[y] = v)

@testset "Virtual Model" begin
    model = VirtualModel()

    @test MOI.is_empty(model)
end

@testset "Encodings" verbose = true begin
    @testset "Linear" begin
        model = VirtualModel()

        x = MOI.add_variable(MOI.get(model, VM.SourceModel()))
        γ = [1.0, 2.0, 3.0]
        α = 1.0

        v = VM.encode!(VM.Linear, model, x, γ, α)
        y = VM.target(v)

        @test length(y) == 3

        @test VM.source(v) == x
        @test VM.expansion(v) == PBO.PBF{VI, Float64}(
            y[1] => γ[1],
            y[2] => γ[2],
            y[3] => γ[3],
            nothing => α,
        )
        @test VM.penaltyfn(v) |> isnothing

        @test MOI.get(model, VM.Variables()) == [v]
        @test MOI.get(model, VM.Source(), VM.source(v)) == v
        @test MOI.get.(model, VM.Target(), VM.target(v)) == [v, v, v]
    end

    @testset "Mirror" begin
        model = VirtualModel()

        x = MOI.add_variable(MOI.get(model, VM.SourceModel()))

        v = VM.encode!(VM.Mirror, model, x)
        y = VM.target(v)

        @test length(y) == 1

        @test VM.source(v) == x
        @test VM.expansion(v) == PBO.PBF{VI, Float64}(y[1])
        @test VM.penaltyfn(v) |> isnothing

        @test MOI.get(model, VM.Variables()) == [v]
        @test MOI.get(model, VM.Source(), VM.source(v)) == v
        @test MOI.get.(model, VM.Target(), VM.target(v)) == [v]
    end

    @testset "Unary ℤ" begin
        model = VirtualModel()

        x = MOI.add_variable(MOI.get(model, VM.SourceModel()))
        a, b = (-2.0, 2.0)

        v = VM.encode!(VM.Unary, model, x, a, b)
        y = VM.target(v)

        @test length(y) == 4

        @test VM.source(v) == x
        @test VM.expansion(v) == PBO.PBF{VI, Float64}(
            y[1] => 1.0,
            y[2] => 1.0,
            y[3] => 1.0,
            y[4] => 1.0,
            nothing => a,
        )
        @test VM.penaltyfn(v) |> isnothing

        @test MOI.get(model, VM.Variables()) == [v]
        @test MOI.get(model, VM.Source(), VM.source(v)) == v
        @test MOI.get.(model, VM.Target(), VM.target(v)) == [v, v, v, v]
    end

    @testset "Unary ℝ" begin
        model = VirtualModel()

        x = MOI.add_variable(MOI.get(model, VM.SourceModel()))
        a, b = (-2.0, 2.0)
        n = 4

        v = VM.encode!(VM.Unary, model, x, a, b, n)
        y = VM.target(v)

        @test length(y) == n

        @test VM.source(v) == x
        @test VM.expansion(v) ≈ PBO.PBF{VI, Float64}(
            y[1] => 1.0,
            y[2] => 1.0,
            y[3] => 1.0,
            y[4] => 1.0,
            nothing => a,
        )
        @test VM.penaltyfn(v) |> isnothing

        @test MOI.get(model, VM.Variables()) == [v]
        @test MOI.get(model, VM.Source(), VM.source(v)) == v
        @test MOI.get.(model, VM.Target(), VM.target(v)) == [v, v, v, v]
    end

    @testset "Binary ℤ" begin
        model = VirtualModel()

        x = MOI.add_variable(MOI.get(model, VM.SourceModel()))
        a, b = (-2.0, 2.0)

        v = VM.encode!(VM.Binary, model, x, a, b)
        y = VM.target(v)

        @test length(y) == 3

        @test VM.source(v) == x
        @test VM.expansion(v) == PBO.PBF{VI, Float64}(
            y[1] => 1.0,
            y[2] => 2.0,
            y[3] => 1.0,
            nothing => a,
        )
        @test VM.penaltyfn(v) |> isnothing

        @test MOI.get(model, VM.Variables()) == [v]
        @test MOI.get(model, VM.Source(), VM.source(v)) == v
        @test MOI.get.(model, VM.Target(), VM.target(v)) == [v, v, v]
    end

    @testset "Binary ℝ" begin
        model = VirtualModel()

        x = MOI.add_variable(MOI.get(model, VM.SourceModel()))
        a, b = (-2.0, 2.0)
        n = 3

        v = VM.encode!(VM.Unary, model, x, a, b, n)
        y = VM.target(v)

        @test length(y) == n

        @test VM.source(v) == x
        @test VM.expansion(v) ≈ PBO.PBF{VI, Float64}(
            y[1] => 4 / 3,
            y[2] => 4 / 3,
            y[3] => 4 / 3,
            nothing => a,
        )
        @test VM.penaltyfn(v) |> isnothing

        @test MOI.get(model, VM.Variables()) == [v]
        @test MOI.get(model, VM.Source(), VM.source(v)) == v
        @test MOI.get.(model, VM.Target(), VM.target(v)) == [v, v, v]
    end

    @testset "One Hot" begin
        model = VirtualModel()

        x = MOI.add_variable(MOI.get(model, VM.SourceModel()))
        γ = [-1.0, -0.5, 0.0, 0.5, 1.0]

        v = VM.encode!(VM.OneHot, model, x, γ)
        y = VM.target(v)

        @test length(y) == length(γ)

        @test VM.source(v) == x
        @test VM.expansion(v) ≈ PBO.PBF{VI, Float64}(
            y[1] => -1.0,
            y[2] => -0.5,
            y[4] =>  0.5,
            y[5] =>  1.0,
        )
        @test VM.penaltyfn(v) ≈ (PBO.PBF{VI, Float64}(-1.0, y...) ^ 2)

        @test MOI.get(model, VM.Variables()) == [v]
        @test MOI.get(model, VM.Source(), VM.source(v)) == v
        @test MOI.get.(model, VM.Target(), VM.target(v)) == [v, v, v, v, v]
    end

    @testset "One Hot ℤ" begin
        model = VirtualModel()

        x = MOI.add_variable(MOI.get(model, VM.SourceModel()))
        a, b = (-2.0, 2.0)

        v = VM.encode!(VM.OneHot, model, x, a, b)
        y = VM.target(v)

        @test length(y) == 5

        @test VM.source(v) == x
        @test VM.expansion(v) ≈ PBO.PBF{VI, Float64}(
            y[1] => -2.0,
            y[2] => -1.0,
            y[4] =>  1.0,
            y[5] =>  2.0,
        )
        @test VM.penaltyfn(v) ≈ (PBO.PBF{VI, Float64}(-1.0, y...) ^ 2)

        @test MOI.get(model, VM.Variables()) == [v]
        @test MOI.get(model, VM.Source(), VM.source(v)) == v
        @test MOI.get.(model, VM.Target(), VM.target(v)) == [v, v, v, v, v]
    end
    @testset "One Hot ℝ" begin
        model = VirtualModel()

        x = MOI.add_variable(MOI.get(model, VM.SourceModel()))
        a, b = (-2.0, 2.0)
        n = 5

        v = VM.encode!(VM.OneHot, model, x, a, b, n)
        y = VM.target(v)

        @test length(y) == n

        @test VM.source(v) == x
        @test VM.expansion(v) ≈ PBO.PBF{VI, Float64}(
            y[1] => -2.0,
            y[2] => -1.0,
            y[4] =>  1.0,
            y[5] =>  2.0,
        )
        @test VM.penaltyfn(v) ≈ (PBO.PBF{VI, Float64}(-1.0, y...) ^ 2)

        @test MOI.get(model, VM.Variables()) == [v]
        @test MOI.get(model, VM.Source(), VM.source(v)) == v
        @test MOI.get.(model, VM.Target(), VM.target(v)) == [v, v, v, v, v]
    end
    @testset "Domain Wall ℤ" begin
        model = VirtualModel()

        x = MOI.add_variable(MOI.get(model, VM.SourceModel()))
        a, b = (-2.0, 2.0)

        v = VM.encode!(VM.DomainWall, model, x, a, b)
        y = VM.target(v)

        @test length(y) == 4

        @test VM.source(v) == x
        @test VM.expansion(v) ≈ PBO.PBF{VI, Float64}(
            y[1] => -1.0,
            y[2] => -1.0,
            y[3] => -1.0,
            y[4] => -1.0,
        )
        @test VM.penaltyfn(v) ≈ PBO.PBF{VI, Float64}(
            y[2] => 2.0,
            y[3] => 2.0,
            y[4] => 2.0,
            [y[1], y[2]] => -2.0,
            [y[2], y[3]] => -2.0,
            [y[3], y[4]] => -2.0,
        )

        @test MOI.get(model, VM.Variables()) == [v]
        @test MOI.get(model, VM.Source(), VM.source(v)) == v
        @test MOI.get.(model, VM.Target(), VM.target(v)) == [v, v, v, v]
    end
        
    @testset "Domain Wall ℝ" begin
        model = VirtualModel()

        x = MOI.add_variable(MOI.get(model, VM.SourceModel()))
        a, b = (-2.0, 2.0)
        n = 5

        v = VM.encode!(VM.DomainWall, model, x, a, b, n)
        y = VM.target(v)

        @test length(y) == n - 1

        @test VM.source(v) == x
        @test VM.expansion(v) ≈ PBO.PBF{VI, Float64}(
            y[1] => -1.0,
            y[2] => -1.0,
            y[3] => -1.0,
            y[4] => -1.0,
        )
        @test VM.penaltyfn(v) ≈ PBO.PBF{VI, Float64}(
            y[2] => 2.0,
            y[3] => 2.0,
            y[4] => 2.0,
            [y[1], y[2]] => -2.0,
            [y[2], y[3]] => -2.0,
            [y[3], y[4]] => -2.0,
        )

        @test MOI.get(model, VM.Variables()) == [v]
        @test MOI.get(model, VM.Source(), VM.source(v)) == v
        @test MOI.get.(model, VM.Target(), VM.target(v)) == [v, v, v, v]
    end

    @testset "Bipartite"
end

end