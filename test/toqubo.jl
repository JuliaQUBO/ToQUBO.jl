@testset "ToQUBO" begin

    @testset "MOI UI - ILP" begin
    
    model = MOI.instantiate(
        ()->ToQUBO.Optimizer(SimulatedAnnealer.Optimizer),
        with_bridge_type = Float64,
    )

    @test MOI.is_empty(model) == true

    @test_broken MOI.get(model, ToQUBO.Tol()) ≈ 1e-6 # default value

    MOI.set(model, ToQUBO.Tol(), 1e-2)

    @test MOI.get(model, ToQUBO.Tol()) ≈ 1e-2

    x = MOI.add_variables(model, 3);
    v = [1.0, 2.0, 3.0] # value
    w = [0.3, 0.5, 1.0] # weight
    C = 3.2             # capacity

    # will work because ToQUBO.Optimizer will know how to expand an integer variables
    # into binaries
    for xᵢ in x
        MOI.add_constraint(model, xᵢ, MOI.Integer())
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

    sol = MOI.get.(model, MOI.VariablePrimal(), x)

    @test sol ≈ [2.0, 5.0, 0.0] || sol ≈ [4.0, 4.0, 0.0]

    end

    @testset "MOI UI - IQP" begin
    
    model = MOI.instantiate(
        ()->ToQUBO.Optimizer(SimulatedAnnealer.Optimizer),
        with_bridge_type = Float64,
    )

    @test MOI.is_empty(model)

    n = 3
    x = MOI.add_variables(model, n);
    v = [1.0 2.0 3.0] # value
    w = [0.5 0.0 0.0
         0.0 0.0 0.5
         0.0 0.5 1.0] # weights
    C = 6.4           # capacity

    # will work because ToQUBO.Optimizer will know how to expand an integer variables
    # into binaries
    for xᵢ in x
        MOI.add_constraint(model, xᵢ, MOI.Integer())
        MOI.add_constraint(model, xᵢ, MOI.Interval{Float64}(0.0, 3.0))
    end

    MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)

    MOI.set(
        model,
        MOI.ObjectiveFunction{MOI.ScalarAffineFunction{Float64}}(),
        MOI.ScalarAffineFunction{Float64}(
            [MOI.ScalarAffineTerm{Float64}(v[i], x[i]) for i = 1:n],
            0.0,
        ),
    );

    MOI.add_constraint(
        model,
        MOI.ScalarQuadraticFunction{Float64}(
            [MOI.ScalarQuadraticTerm{Float64}(w[i, j], x[i], x[j]) for i = 1:n for j = 1:n],
            [],
            0.0,
        ),
        MOI.LessThan{Float64}(C),
    )

    MOI.optimize!(model)

    sol = MOI.get.(model, MOI.VariablePrimal(), x)

    @test sol ≈ [2.0, 2.0, 1.0] || sol ≈ [2.0, 0.0, 2.0]

    end
end