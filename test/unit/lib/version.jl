function test_version()
    @testset "Version" begin
        proj_path = joinpath(@__DIR__, "..", "..", "..", "Project.toml")
        proj_data = TOML.parsefile(proj_path)

        @test MOI.get(ToQUBO.Optimizer(), MOI.SolverVersion()) == VersionNumber(proj_data["version"])
    end
end