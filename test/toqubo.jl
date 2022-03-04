@testset "ToQUBO" begin

    @testset "UI" begin
    
    model = MOI.instantiate(
        ()->ToQUBO.Optimizer(Anneal.SimulatedAnnealer.Optimizer),
        with_bridge_type = Float64,
    )

    x = MOI.add_variables(model, 2);

    # will work because ToQUBO.Optimizer will know how to expand an integer variables
    # into binaries
    for xᵢ in x
        MOI.add_constraint(model, xᵢ, MOI.Integer())
    end

    MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)

    MOI.set(
        model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([1.0, 1.2], x), 0.0),
    );

    optimize!(model)

    end
end