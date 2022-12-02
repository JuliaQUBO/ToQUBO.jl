
function test_pbo_ma()
    @testset "PBO_MA" verbose = true begin
        # -*- Definitions -*-
        S = Symbol
        T = Float64

        # :: Canonical Constructor ::
        f = PBO.PBF{S,T}(
            Dict{Set{S},T}(
                Set{S}()             => 0.5,
                Set{S}([:x])         => 1.0,
                Set{S}([:y])         => 1.0,
                Set{S}([:z])         => 1.0,
                Set{S}([:x, :y])     => -2.0,
                Set{S}([:x, :z])     => -2.0,
                Set{S}([:y, :z])     => -2.0,
                Set{S}([:x, :y, :z]) => 3.0,
            ),
        )
        g = PBO.PBF{S,T}(Dict{Set{S},T}(Set{S}() => 1.0))
        h = PBO.PBF{S,T}(
            Dict{Set{S},T}(
                Set{S}([:x]) => 1.0,
                Set{S}([:y]) => 1.0,
                Set{S}([:z]) => 1.0,
                Set{S}([:w]) => 1.0,
                Set{S}()     => 1.0,
            ),
        )
        p = PBO.PBF{S,T}(
            Dict{Set{S},T}(Set{S}() => 0.5, Set{S}([:x]) => 1.0, Set{S}([:x, :y]) => -2.0),
        )
        q = PBO.PBF{S,T}(
            Dict{Set{S},T}(Set{S}() => 0.5, Set{S}([:y]) => 1.0, Set{S}([:x, :y]) => 2.0),
        )
        r = PBO.PBF{S,T}(Set{S}() => 1.0, Set{S}([:z]) => -1.0)
        s = PBO.PBF{S,T}(Set{S}() => 0.0, Set{S}([:x, :y, :z]) => 3.0)

        # @testset "Constructors" begin
            # @test MA.@rewrite(PBO.PBF{S,T}(Set{S}() => 0.0) == PBO.PBF{S,T}() == zero(PBO.PBF{S,T}))
        #     @test MA.@rewrite(f == PBO.PBF{S,T}(
        #         nothing      => 0.5,
        #         :x           => 1.0,
        #         :y           => 1.0,
        #         :z           => 1.0,
        #         [:x, :y]     => -2.0,
        #         [:x, :z]     => -2.0,
        #         [:y, :z]     => -2.0,
        #         [:x, :y, :z] => 3.0,
        #     ))
        #     @test MA.@rewrite(g == PBO.PBF{S,T}(1.0) == one(PBO.PBF{S,T}))
        #     @test MA.@rewrite(h == PBO.PBF{S,T}([:x, :y, :z, :w, nothing]))
        #     @test MA.@rewrite(p == PBO.PBF{S,T}((nothing, 0.5), :x, [:x, :y] => -2.0))
        #     @test MA.@rewrite(q == PBO.PBF{S,T}(nothing => 0.5, :y, [:x, :y] => 2.0))
        #     @test MA.@rewrite(r == PBO.PBF{S,T}(nothing, :z => -1.0))
        #     @test MA.@rewrite(s == PBO.PBF{S,T}(S[] => 0.0, Set{S}([:x, :y, :z]) => 3.0))
        # end

        @testset "Arithmetic" verbose = true begin

            @testset "+" begin
                @test MA.@rewrite((p + q)) ==
                      MA.@rewrite((q + p)) ==
                      PBO.PBF{S,T}(nothing => 1.0, :x => 1.0, :y => 1.0)

                @test MA.@rewrite((p + q + r)) ==
                      MA.@rewrite((r + q + p)) ==
                      PBO.PBF{S,T}(nothing => 2.0, :x => 1.0, :y => 1.0, :z => -1.0)

                @test MA.@rewrite((s + 3.0)) ==
                      MA.@rewrite((3.0 + s)) ==
                      PBO.PBF{S,T}(nothing => 3.0, [:x, :y, :z] => 3.0)
            end

            @testset "-" begin
                @test MA.@rewrite((p - q)) == PBO.PBF{S,T}(:x => 1.0, :y => -1.0, [:x, :y] => -4.0)
                @test MA.@rewrite((p - p)) == MA.@rewrite((q - q)) == MA.@rewrite((r - r)) == MA.@rewrite((s - s)) == PBO.PBF{S,T}()
                @test MA.@rewrite((s - 3.0)) == PBO.PBF{S,T}(nothing => -3.0, [:x, :y, :z] => 3.0)
                @test MA.@rewrite((3.0 - s)) == PBO.PBF{S,T}(nothing => 3.0, [:x, :y, :z] => -3.0)
            end

            @testset "*" begin
                @test MA.@rewrite((p * q)) ==
                      MA.@rewrite((q * p)) ==
                      PBO.PBF{S,T}(
                          nothing => 0.25,
                          [:x] => 0.5,
                          [:y] => 0.5,
                          [:x, :y] => -3.0,
                      )
                @test MA.@rewrite((p * (-0.5))) ==
                      MA.@rewrite(((-0.5) * p)) ==
                      PBO.PBF{S,T}(nothing => -0.25, :x => -0.5, [:x, :y] => 1.0)
                @test MA.@rewrite((0.25 * p + 0.75 * q)) ==
                      PBO.PBF{S,T}(nothing => 0.5, :x => 0.25, :y => 0.75, [:x, :y] => 1.0)
                @test MA.@rewrite(((p * q * r) - s)) == PBO.PBF{S,T}(
                    nothing  => 0.25,
                    :x       => 0.5,
                    :y       => 0.5,
                    :z       => -0.25,
                    [:x, :y] => -3.0,
                    [:x, :z] => -0.5,
                    [:y, :z] => -0.5,
                )
            end

            @testset "/" begin
                @test MA.@rewrite((p / 2.0)) ==
                      MA.@rewrite((p * 0.5)) ==
                      PBO.PBF{S,T}(nothing => 0.25, :x => 0.5, [:x, :y] => -1.0)
                @test_throws DivideError p / 0.0
            end

            @testset "^" begin
                @test MA.@rewrite(p^0) == MA.@rewrite(q^0) == MA.@rewrite(r^0) == MA.@rewrite(s^0) == one(PBO.PBF{S,T})
                
                @test MA.@rewrite(p^2) == PBO.PBF{S,T}(nothing => 0.25, :x => 2.0, [:x, :y] => -2.0)
                @test MA.@rewrite(q^2) == PBO.PBF{S,T}(nothing => 0.25, :y => 2.0, [:x, :y] => 10.0)
                @test MA.@rewrite(r^2) == PBO.PBF{S,T}(nothing => 1.0, :z => -1.0)
                @test MA.@rewrite(s^2) == PBO.PBF{S,T}([:x, :y, :z] => 9.0)

                @test MA.@rewrite(r^3) == PBO.PBF{S,T}(nothing => 1.0, :z => -1.0)
                @test MA.@rewrite(s^3) == PBO.PBF{S,T}([:x, :y, :z] => 27.0)

                @test MA.@rewrite(r^4) == PBO.PBF{S,T}(nothing => 1.0, :z => -1.0)
            end

        end

    end
end