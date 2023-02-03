function test_pbo()
    @testset "Pseudo-Boolean Optimization" verbose = true begin
        @testset "Constructors" begin
            for (x, y) in Assets.PBF_CONSTRUCTOR_LIST
                @test x == y
            end
        end

        @testset "Operators" verbose = true begin
            @testset "$op" for (op::Function, data) in Assets.PBF_OPERATOR_LIST
                for (x, y) in data
                    if y isa Type{<:Exception}
                        @test_throws y op(x...)
                    else
                        @test op(x...) == y
                    end
                end
            end
        end

        @testset "Evaluation" verbose = true begin
            @testset "$tag" for (tag::String, data) in Assets.PBF_EVALUATION_LIST
                for ((f, x), y) in data
                    @test f(x) == y
                end
            end
        end

        @testset "QUBOTools Interface" verbose = true begin
            @testset "$fn" for (fn::Function, data) in Assets.PBF_QUBOTOOLS_LIST
                for (x, y) in data
                    if y isa Type{<:Exception}
                        @test_throws y op(x...)
                    else
                        @test fn(x...) == y
                    end
                end
            end
        end
    end
end

# function test_pbo()
#     @testset "PBO" verbose = true begin
#         #  Definitions 
#         S = Symbol
#         T = Float64

#         # :: Canonical Constructor ::
#         

#         @testset "QUBO" begin
#             x       = PBO.variable_map(p)
#             Q, α, β = PBO.qubo(p, Dict)
#             @test Q == Dict{Tuple{Int,Int},T}((x[:x], x[:x]) => 1.0, (x[:x], x[:y]) => -2.0)
#             @test α == 1.0
#             @test β == 0.5

#             x       = PBO.variable_map(q)
#             Q, α, β = PBO.qubo(q, Dict)
#             @test Q == Dict{Tuple{Int,Int},T}((x[:y], x[:y]) => 1.0, (x[:x], x[:y]) => 2.0)
#             @test α == 1.0
#             @test β == 0.5

#             x       = PBO.variable_map(r)
#             Q, α, β = PBO.qubo(r, Dict)
#             @test Q == Dict{Tuple{Int,Int},T}((x[:z], x[:z]) => -1.0)
#             @test α == 1.0
#             @test β == 1.0

#             Q, α, β = PBO.qubo(p, Matrix)
#             @test Q == Matrix{T}([1.0 -1.0; -1.0 0.0])
#             @test β == 0.5

#             Q, α, β = PBO.qubo(q, Matrix)
#             @test Q == Matrix{T}([0.0 1.0; 1.0 1.0])
#             @test β == 0.5

#             Q, α, β = PBO.qubo(r, Matrix)
#             @test Q == Matrix{T}([-1.0][:, :])
#             @test β == 1.0

#             @test_throws Exception PBO.qubo(s, Dict)
#             @test_throws Exception PBO.qubo(s, Matrix)
#         end

#         @testset "Evaluation" begin
#             for x = 0:1, y = 0:1, z = 0:1
#                 @test f(:x => x, :y => y, :z => z) == 0.5 + (x + y + z == 1.0)
#             end

#             @test g() == 1.0

#             for x = 0:1, y = 0:1, z = 0:1, w = 0:1
#                 @test h(:x => x, :y => y, :z => z, :w => w) == 1.0 + x + y + z + w
#             end    
#         end

#         @testset "Calculus" begin
#             @test PBO.gap(f; bound = :loose) ==
#                   (PBO.upperbound(f; bound = :loose) - PBO.lowerbound(f; bound = :loose))
#             @test PBO.gap(g; bound = :loose) ==
#                   (PBO.upperbound(g; bound = :loose) - PBO.lowerbound(g; bound = :loose))
#             @test PBO.gap(h; bound = :loose) ==
#                   (PBO.upperbound(h; bound = :loose) - PBO.lowerbound(h; bound = :loose))
#         end

#         @testset "Quadratization" begin
#             function aux(n::Union{Integer,Nothing})
#                 if isnothing(n)
#                     return :w
#                 else
#                     return [:w, :t, :u, :v][1:n]
#                 end
#             end

#             @test PBO.quadratize(aux, p) == p
#             @test PBO.quadratize(aux, q) == q
#             @test PBO.quadratize(aux, r) == r
#             @test PBO.quadratize(aux, s) == PBO.PBF{S,T}(
#                 :w => 3.0,
#                 [:x, :w] => 3.0,
#                 [:y, :w] => -3.0,
#                 [:z, :w] => -3.0,
#                 [:y, :z] => 3.0,
#             )
#         end

#         @testset "Discretization" begin
#             @test PBO.discretize(p; tol = 0.1) ==
#                   PBO.PBF{S,T}(nothing => 1.0, :x => 2.0, [:x, :y] => -4.0)
#             @test PBO.discretize(q; tol = 0.1) ==
#                   PBO.PBF{S,T}(nothing => 1.0, :y => 2.0, [:x, :y] => 4.0)
#             @test PBO.discretize(r; tol = 0.1) == PBO.PBF{S,T}(nothing => 1.0, :z => -1.0)
#         end

#         @testset "Print" begin
#             @test "$(r)" == "1.0 - 1.0z" || "$(r)" == "-1.0z + 1.0"
#             @test "$(s)" == "3.0x*y*z"
#         end
# end