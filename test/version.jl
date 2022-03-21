@testset "Version" begin
    @test MOI.get(ToQUBO.Optimizer(nothing), MOI.SolverVersion()) == VersionNumber(TOML.parsefile(joinpath("..", "Project.toml"))["version"])
end