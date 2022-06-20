const VM = VirtualMapping

@testset "VirtualMapping Module" verbose = true begin

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

        v, y = VM.encode!(VM.Linear, model, x, γ, α)

        @test VM.source(v) == x
        @test VM.target(v) == y

        @test MOI.get(model, VM.Variables()) == [v]
        @test MOI.get(model, VM.Source(), VM.source(v)) == v
        @test MOI.get.(model, VM.Target(), VM.target(v)) == [v, v, v]
        
        
    end
end

# @test collect(model.varvec[1]) == Dict{Set{VI}, Float64}(
#     Set{VI}()          => -3.0,
#     Set{VI}([y[1][1]]) =>  1.0,
#     Set{VI}([y[1][2]]) =>  2.0,
#     Set{VI}([y[1][3]]) =>  4.0,
#     Set{VI}([y[1][4]]) =>  1.0,
# )

# @test collect(model.varvec[2]) == Dict{Set{VI}, Float64}(
#     Set{VI}()          => -1.0,
#     Set{VI}([y[2][2]]) =>  1.0,
#     Set{VI}([y[2][1]]) =>  1.0,
# )

# @test collect(model.varvec[3]) == Dict{Set{VI}, Float64}(
#     Set{VI}()          =>  0.0,
#     Set{VI}([y[3][1]]) =>  1.0,
#     Set{VI}([y[3][2]]) =>  2.0,
#     Set{VI}([y[3][3]]) =>  4.0,
#     Set{VI}([y[3][4]]) =>  1.0,
# )

end