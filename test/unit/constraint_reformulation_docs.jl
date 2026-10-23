function test_constraint_reformulation_docs()
    root = normpath(joinpath(@__DIR__, "..", ".."))
    booklet = replace(
        read(joinpath(root, "docs", "src", "booklet", "4-encoding.md"), String),
        "\r\n" => "\n",
    )
    settings = replace(
        read(joinpath(root, "docs", "src", "manual", "4-settings.md"), String),
        "\r\n" => "\n",
    )
    encoding_module = replace(
        read(joinpath(root, "src", "encoding", "encoding.jl"), String),
        "\r\n" => "\n",
    )
    empty_stub = joinpath(root, "src", "encoding", "constraints", "constraints.jl")

    @testset "Constraint reformulation docs" begin
        @test !isfile(empty_stub)
        @test !occursin("include(\"constraints/constraints.jl\")", encoding_module)

        @test occursin("## Constraint Reformulation", booklet)
        for constraint_type in ("`EqualTo`", "`LessThan`", "`GreaterThan`", "`Interval`")
            @test occursin(constraint_type, booklet)
        end
        @test occursin("The `EqualTo` row shows the default", booklet)
        @test occursin("### Boolean Logic Gadgets and Indicator Formulations", booklet)
        for gate in ("`NOT`", "`AND`", "`OR`", "`XOR`")
            @test occursin(gate, booklet)
        end
        @test occursin("MOI.Indicator{MOI.ACTIVATE_ON_ONE}", booklet)
        @test occursin("SlackVariableEncodingBits", booklet)
        @test occursin("SlackVariableEncodingATol", booklet)
        @test occursin("[Constraint Reformulation](@ref)", settings)
    end

    return nothing
end
