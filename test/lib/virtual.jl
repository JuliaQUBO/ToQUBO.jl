@testset "VirtualMapping Module" begin

    struct VirtualModel{T} <: VM.AbstractVirtualModel{T}
        source_model::MOIU.Model{T}
        target_model::MOIU.Model{T}

        varvec::Vector{VM.VirtualMOIVariable{T}}
        source::Dict{VI, VM.VirtualMOIVariable{T}}
        target::Dict{VI, VM.VirtualMOIVariable{T}}

        function VirtualModel{T}(; kws...) where {T}
            return new{T}(
                MOIU.Model{T}(),
                MOIU.Model{T}(),

                VM.VirtualMOIVariable{T}[],
                Dict{VI, VM.VirtualMOIVariable{T}}(),
                Dict{VI, VM.VirtualMOIVariable{T}}(),
            )
        end

        function VirtualModel(; kws...)
            return VirtualModel{Float64}(; kws...)
        end
    end

    model = VirtualModel()

    @test MOI.is_empty(model)

    n = 3
    x = MOI.add_variables(model.source_model, n)
    I = [
        (-3.0, 5.0),
        (-1.0, 1.0),
        ( 0.0, 8.0),
    ]

    for (xᵢ, (aᵢ, bᵢ)) ∈ zip(x, I)
        VM.expandℤ!(
            model,
            xᵢ;
            name = Symbol("x$(xᵢ.value)"),
            α    = aᵢ,
            β    = bᵢ,
            semi = false,
        ) 
    end

    @test VM.name.(model.varvec) == [:x1, :x2, :x3]

    y = VM.target.(model.varvec)

    @test collect(model.varvec[1]) == Dict{Set{VI}, Float64}(
        Set{VI}()          => -3.0,
        Set{VI}([y[1][1]]) =>  1.0,
        Set{VI}([y[1][2]]) =>  2.0,
        Set{VI}([y[1][3]]) =>  4.0,
        Set{VI}([y[1][4]]) =>  1.0,
    )

    @test collect(model.varvec[2]) == Dict{Set{VI}, Float64}(
        Set{VI}()          => -1.0,
        Set{VI}([y[2][2]]) =>  1.0,
        Set{VI}([y[2][1]]) =>  1.0,
    )

    @test collect(model.varvec[3]) == Dict{Set{VI}, Float64}(
        Set{VI}()          =>  0.0,
        Set{VI}([y[3][1]]) =>  1.0,
        Set{VI}([y[3][2]]) =>  2.0,
        Set{VI}([y[3][3]]) =>  4.0,
        Set{VI}([y[3][4]]) =>  1.0,
    )
end