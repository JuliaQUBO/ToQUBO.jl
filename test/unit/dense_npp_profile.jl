include(joinpath(@__DIR__, "..", "..", "benchmarks", "dense_npp_profile.jl"))

function test_dense_npp_profile_benchmark()
    @testset "Dense NPP profile benchmark" begin
        n = 4

        npp_model = DenseNPPProfile.build_npp_model(n)
        @test JuMP.num_variables(npp_model) == n
        optimize!(npp_model)
        @test QUBOTools.backend(npp_model) isa QUBOTools.Model

        dense_model = DenseNPPProfile.build_dense_quadratic_model(n)
        @test JuMP.num_variables(dense_model) == n
        optimize!(dense_model)
        @test QUBOTools.backend(dense_model) isa QUBOTools.Model

        rows = DenseNPPProfile.profile_fixture(
            "small NPP-like",
            DenseNPPProfile.build_npp_model,
            3;
            modes = (:cached,),
            repeats = 1,
            warmup = false,
        )

        @test length(rows) == 3
        @test [row.phase for row in rows] ==
              ["model construction", "optimize!", "QUBOTools.backend"]
        @test all(row.summary.samples == 1 for row in rows)
        @test all(
            isfinite(row.summary.min_time) && isfinite(row.summary.median_time) for row in rows
        )
        @test isfinite(rows[2].summary.median_compile_time)
    end

    return nothing
end
