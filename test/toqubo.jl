@testset "ToQUBO" begin

    @testset "UI" begin
    
    model = MOI.instantiate(
        ()->ToQUBO.Optimizer(SimulatedAnnealer.Optimizer; tol=1e-3),
        with_bridge_type = Float64,
    )

    x = MOI.add_variables(model, 3);
    v = [1.0, 2.0, 3.0] # value
    w = [0.3, 0.5, 1.0] # weight
    C = 3.2             # capacity

    # will work because ToQUBO.Optimizer will know how to expand an integer variables
    # into binaries
    for xᵢ in x
        # MOI.add_constraint(model, xᵢ, MOI.Integer())
        MOI.add_constraint(model, xᵢ, MOI.Interval{Float64}(0.0, 5.0))
    end

    MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)

    MOI.set(
        model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction{Float64}(MOI.ScalarAffineTerm{Float64}.(v, x), 0.0),
    );

    MOI.add_constraint(
        model,
        MOI.ScalarAffineFunction{Float64}(MOI.ScalarAffineTerm{Float64}.(w, x), 0.0),
        MOI.LessThan{Float64}(C),
    )

    MOI.optimize!(model)

    println(model)
    println(model.model.optimizer.target_model)

    println(MOI.get.(model, MOI.VariablePrimal(), x))
    end
end