@testset "Exact Sampling" begin
    @testset "Regular UI + Attributes" begin
        sampler = ExactSampler.Optimizer{Float64}()

        # -*- Model -*-
        @test (MOI.is_empty(sampler) == true)

        model = MOIU.Model{Float64}()

        MOI.set(model, MOI.ObjectiveSense(), MOI.MIN_SENSE)

        x₁ = MOI.add_variable(model)
        x₂ = MOI.add_variable(model)

        @test (Anneal.isqubo(model) == false)

        @test_throws Anneal.QUBOError MOI.copy_to(sampler, model)

        MOI.add_constraint(model, x₁, MOI.ZeroOne())
        MOI.add_constraint(model, x₂, MOI.ZeroOne())

        MOI.set(model, MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{Float64}}(),
            MOI.ScalarQuadraticFunction{Float64}([
                MOI.ScalarQuadraticTerm{Float64}(3.0, x₁, x₂),
            ], [
                MOI.ScalarAffineTerm{Float64}(-1.0, x₁),
                MOI.ScalarAffineTerm{Float64}(-2.0, x₂)
            ], 3.0)
        )

        @test (Anneal.isqubo(model) == true)

        # -*- copy_to -*-
        MOI.copy_to(sampler, model)

        @test (MOI.is_empty(sampler) == false)

        @test sampler.x == Dict{MOI.VariableIndex, Int}(x₁ => 1, x₂ => 2)
        @test sampler.Q == Dict{Tuple{Int, Int}, Float64}(
            (1, 1) => -1.0,
            (1, 2) =>  3.0,
            (2, 2) => -2.0,
        )
        @test sampler.c == 3.0

        MOI.empty!(sampler)

        @test (MOI.is_empty(sampler) == true)
    end # testset

    @testset "MOI UI" begin
        model = MOI.instantiate(ExactSampler.Optimizer, with_bridge_type = Float64)
    
        # -*- Model -*-
        @test (MOI.is_empty(model) == true)
    
        n = 2
    
        x = MOI.add_variables(model, n)
    
        for xᵢ in x
            MOI.add_constraint(model, xᵢ, MOI.ZeroOne())
        end
        
        MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    
        MOI.set(
            model,
            MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{Float64}}(),
            MOI.ScalarQuadraticFunction(MOI.ScalarQuadraticTerm{Float64}[], MOI.ScalarAffineTerm.([1.0, 1.2], x), 0.0),
        )
    
        MOI.optimize!(model)
    
        @test MOI.get.(model, MOI.VariablePrimal(), x[1:2]) == [1, 1]
        @test MOI.get(model, MOI.ObjectiveValue()) ≈ 2.2
    end
    
    @testset "MOI UI + Extra Variable" begin
        model = MOI.instantiate(ExactSampler.Optimizer, with_bridge_type = Float64)
    
        # -*- Model -*-
        @test (MOI.is_empty(model) == true)
    
        n = 3
    
        x = MOI.add_variables(model, n)
    
        for xᵢ in x
            MOI.add_constraint(model, xᵢ, MOI.ZeroOne())
        end
        
        MOI.set(model, MOI.ObjectiveSense(), MOI.MAX_SENSE)
    
        MOI.set(
            model,
            MOI.ObjectiveFunction{MOI.ScalarQuadraticFunction{Float64}}(),
            MOI.ScalarQuadraticFunction(MOI.ScalarQuadraticTerm{Float64}[], MOI.ScalarAffineTerm.([1.0, 1.2], x[1:2]), 0.0),
        )
    
        MOI.optimize!(model)
    
        @test MOI.get.(model, MOI.VariablePrimal(), x[1:3]) == [1, 1, 0]
        @test MOI.get(model, MOI.ObjectiveValue()) ≈ 2.2
    end
end