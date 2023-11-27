function test_compiler_setup_callback()
    @testset "Setup Callback" begin
        model = Model(() -> ToQUBO.Optimizer()) # compilation mode
        nvars = [0]

        @variable(model, x[1:3], Bin)

        @objective(model, Min, sum(x))

        setup_callback!(m::ToQUBO.Optimizer) = begin
            nvars[] = MOI.get(m.source_model, MOI.NumberOfVariables())

            return m
        end

        let virtual_model = unsafe_backend(model)
            virtual_model.compiler_settings[:setup_callback] = setup_callback!
        end

        @test nvars[] == 0

        optimize!(model)

        @test nvars[] == 3
    end

    return nothing
end