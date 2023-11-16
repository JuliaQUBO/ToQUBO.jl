"""
 (x11 + x12 + x21 + x22 + x31 + x32 - 4 - s1 - s2)^2
 x11*x11 + x11*x12 + x11*x21 + x11*x22 + x11*x31 + x11*x32 - 4*x11 - s1*x11 - s2*x11 +
  x12*x11 + x12*x12 + x12*x21 + x12*x22 + x12*x31 + x12*x32 - 4*x12 - s1*x12 - s2*x12 +
  x21*x11 + x21*x12 + x21*x21 + x21*x22 + x21*x31 + x21*x32 - 4*x21 - s1*x21 - s2*x21 +
  x22*x11 + x22*x12 + x22*x21 + x22*x22 + x22*x31 + x22*x32 - 4*x22 - s1*x22 - s2*x22 +
  x31*x11 + x31*x12 + x31*x21 + x31*x22 + x31*x31 + x31*x32 - 4*x31 - s1*x31 - s2*x31 +
  x32*x11 + x32*x12 + x32*x21 + x32*x22 + x32*x31 + x32*x32 - 4*x32 - s1*x32 - s2*x32 +
 -4*x11 - 4*x12 - 4*x21 - 4*x22 - 4*x31 - 4*x32 + 16 + 4*s1 + 4*s2 +
 -s1*x11 - s1*x12 - s1*x21 - s1*x22 - s1*x31 - s1*x32 + 4*s1 + s1*s1 + s1*s2 +
 -s2*x11 - s2*x12 - s2*x21 - s2*x22 - s2*x31 - s2*x32 + 4*s2 + s1*s2 + s2*s2

"""
function test_continuous_2()
    @testset "Greater than constraint penalty hint" begin
        
        ρ = 3.0 
        
        Q = [
              1-7ρ 2ρ 2ρ 2ρ 2ρ 2ρ -2ρ -2ρ
            0   1-7ρ  2ρ 2ρ 2ρ 2ρ -2ρ -2ρ
            0 0   1-7ρ   2ρ 2ρ 2ρ -2ρ -2ρ
            0 0 0   1-7ρ    2ρ 2ρ -2ρ -2ρ
            0 0 0 0   1-7ρ     2ρ -2ρ -2ρ
            0 0 0 0 0   1-7ρ      -2ρ -2ρ
            0 0 0     0     0  0   9ρ   0
            0 0 0 0 0 0             0  9ρ    
        ]

        model = Model(() -> ToQUBO.Optimizer(ExactSampler.Optimizer))

        @variable(model, 0 <= x[1:3] <= 2, Int)
        @constraint(model, c, sum(x) >= 4)
        @objective(model, Min, sum(x))

        
        JuMP.set_attribute(c, ToQUBO.Attributes.ConstraintEncodingPenaltyHint(), 3.0)
        

        optimize!(model)

    
        n, L, Q, α, β = QUBOTools.qubo(model, :dense)

        Q̂ = Q + diagm(L)

        @test n == 8
        @test α ≈ ᾱ
        @test β ≈ β̄
        @test Q̂ ≈ Q̄

        # Solutions
        x̂ = value.(x)
        ŷ = objective_value(model)

        @test x̂ ≈ x̄
        @test ŷ ≈ ȳ

    end
    return
end