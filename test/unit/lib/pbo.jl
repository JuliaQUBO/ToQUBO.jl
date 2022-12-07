function test_pbo()
    @testset "Pseudo-Boolean Optimization" verbose = true begin
        @testset "Operations" verbose = true begin
            @testset "$op" for (op::Function, data) in Assets.PBF_OP_LIST
                for (x, y) in data
                    if y isa Type{<:Exception}
                        @test_throws y op(x...)
                    else
                        @test op(x...) == y
                    end
                end
            end
        end
    end
end

# function test_pbo()
#     @testset "PBO" verbose = true begin
#         # -*- Definitions -*-
#         S = Symbol
#         T = Float64

#         # :: Canonical Constructor ::
#         @testset "Constructors" begin
#             @test PBO.PBF{S,T}(Set{S}() => 0.0) == PBO.PBF{S,T}() == zero(PBO.PBF{S,T})
#             @test Assets.f == PBO.PBF{S,T}(
#                 nothing      => 0.5,
#                 :x           => 1.0,
#                 :y           => 1.0,
#                 :z           => 1.0,
#                 [:x, :y]     => -2.0,
#                 [:x, :z]     => -2.0,
#                 [:y, :z]     => -2.0,
#                 [:x, :y, :z] => 3.0,
#             )
#             @test Assets.g == PBO.PBF{S,T}(1.0) == one(PBO.PBF{S,T})
#             @test Assets.h == PBO.PBF{S,T}([:x, :y, :z, :w, nothing])
#             @test Assets.p == PBO.PBF{S,T}((nothing, 0.5), :x, [:x, :y] => -2.0)
#             @test Assets.q == PBO.PBF{S,T}(nothing => 0.5, :y, [:x, :y] => 2.0)
#             @test Assets.r == PBO.PBF{S,T}(nothing, :z => -1.0)
#             @test Assets.s == PBO.PBF{S,T}(S[] => 0.0, Set{S}([:x, :y, :z]) => 3.0)
#         end

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

#         @testset "QUBOTools Interface" begin
#             @test PBO.variable_map(f) == Dict{Symbol,Int}(:x => 1, :y => 2, :z => 3)
#             @test PBO.variable_inv(f) == Dict{Int,Symbol}(1 => :x, 2 => :y, 3 => :z)
#             @test PBO.variable_set(f) == Set{Symbol}([:x, :y, :z])
#             @test PBO.variables(f)    == Symbol[:x, :y, :z]

#             @test PBO.variable_map(g) == Dict{Symbol,Int}()
#             @test PBO.variable_inv(g) == Dict{Int,Symbol}()
#             @test PBO.variable_set(g) == Set{Symbol}([])
#             @test PBO.variables(g)    == Symbol[]

#             @test PBO.variable_map(h) == Dict{Symbol,Int}(:x => 2, :y => 3, :z => 4, :w => 1)
#             @test PBO.variable_inv(h) == Dict{Int,Symbol}(2 => :x, 3 => :y, 4 => :z, 1 => :w)
#             @test PBO.variable_set(h) == Set{Symbol}([:x, :y, :z, :w])
#             @test PBO.variables(h)    == Symbol[:w, :x, :y, :z]
#         end
#     end
# end