function test_pbo_ma()
    @testset "PBO MutableArithmetics" verbose = true begin
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

        @testset "Arithmetic" verbose = true begin
            MA.Test.@test_rewrite(p + q)
            MA.Test.@test_rewrite(p + q + r)
            MA.Test.@test_rewrite(s + 3.0)
            MA.Test.@test_rewrite(p - q)
            MA.Test.@test_rewrite(s - 3.0)
            MA.Test.@test_rewrite(0.0 - f)
            MA.Test.@test_rewrite(3.0 - s)
            MA.Test.@test_rewrite(p + q - r)
            MA.Test.@test_rewrite(p * q)
            MA.Test.@test_rewrite(p + 2.0*q)
            MA.Test.@test_rewrite(p - 2.0*q)
            MA.Test.@test_rewrite(p*2.0)
            MA.Test.@test_rewrite(f*0.0)
            MA.Test.@test_rewrite(f*-2.0)
            MA.Test.@test_rewrite(p / 2.0)
            MA.Test.@test_rewrite(p^0)
            MA.Test.@test_rewrite(q^2)
            MA.Test.@test_rewrite(r^2)
            MA.Test.@test_rewrite(s^2)
            MA.Test.@test_rewrite(r^3)
            MA.Test.@test_rewrite(s^3)
            MA.Test.@test_rewrite(r^4)

        end

    end
end