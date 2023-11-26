function test_compiler_error()
    @testset "Compilation Error" begin
        model = ToQUBO.Optimizer()

        @test_throws(
            ToQUBO.Compiler.CompilationError,
            ToQUBO.Compiler.compilation_error!(
                model,
                "Test Message";
                status = "Testing Compilation Error",
            )
        )

        @test MOI.get(model, Attributes.CompilationStatus()) == MOI.OTHER_ERROR
        @test MOI.get(model, MOI.RawStatusString()) == "Testing Compilation Error"

        let e = ToQUBO.Compiler.CompilationError("Test Message")
            @test sprint(Base.showerror, e) == "Test Message"
        end
    end

    return nothing
end