module Assets
using ToQUBO: PBO

const S = Symbol
const T = Float64

const f = PBO.PBF{S,T}(
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
const g = PBO.PBF{S,T}(Dict{Set{S},T}(Set{S}() => 1.0))
const h = PBO.PBF{S,T}(
    Dict{Set{S},T}(
        Set{S}([:x]) => 1.0,
        Set{S}([:y]) => 1.0,
        Set{S}([:z]) => 1.0,
        Set{S}([:w]) => 1.0,
        Set{S}()     => 1.0,
    ),
)
const p = PBO.PBF{S,T}(
    Dict{Set{S},T}(Set{S}() => 0.5, Set{S}([:x]) => 1.0, Set{S}([:x, :y]) => -2.0),
)
const q = PBO.PBF{S,T}(
    Dict{Set{S},T}(Set{S}() => 0.5, Set{S}([:y]) => 1.0, Set{S}([:x, :y]) => 2.0),
)
const r = PBO.PBF{S,T}(Set{S}() => 1.0, Set{S}([:z]) => -1.0)
const s = PBO.PBF{S,T}(Set{S}() => 0.0, Set{S}([:x, :y, :z]) => 3.0)
const t = PBO.PBF{S,T}(:x, :y, -1.0)
const u = PBO.PBF{S,T}(:x, :y)
const v = PBO.PBF{S,T}(:y, :z)
const w = PBO.PBF{S,T}(:x, -100.0)
const α = PBO.PBF{S,T}(:w, :x)
const β = PBO.PBF{S,T}(:x)

x = Set{Symbol}([:x])
y = Set{Symbol}([:y])
z = Set{Symbol}([:z])

function call(f::Function, args)
    return f(args...)
end

const PBF_OP_LIST = [
    (+) => [
        (u, v)    => PBO.PBF{S,T}(:x, :y => 2.0, :z),
        (w, β)    => PBO.PBF{S,T}(:x => 2.0, -100.0),
        (u, 4.0)  => PBO.PBF{S,T}(:x, :y, 4.0),
        (p, q)    => PBO.PBF{S,T}(1.0, :x, :y),
        (q, p)    => PBO.PBF{S,T}(1.0, :x, :y),
        (p, q, r) => PBO.PBF{S,T}(2.0, :x => 1.0, :y => 1.0, :z => -1.0),
        (r, q, p) => PBO.PBF{S,T}(2.0, :x => 1.0, :y => 1.0, :z => -1.0),
        (s, 3.0)  => PBO.PBF{S,T}(3.0, [:x, :y, :z] => 3.0),
        (3.0, s)  => PBO.PBF{S,T}(3.0, [:x, :y, :z] => 3.0),
    ],
    (-) => [
        (u, v)    => PBO.PBF{S,T}(:x, :z => -1.0),
        (β, w)    => PBO.PBF{S,T}(100.0),
        (u, -2.0) => PBO.PBF{S,T}(:x, :y, 2.0),
    ],
    (*) => [
        (u, v)    => PBO.PBF{S,T}([:x, :y], [:x, :z], :y, [:y, :z]),
        (α, v)    => PBO.PBF{S,T}([:w, :y], [:w, :z], [:x, :y], [:x, :z]),
        (β, w)    => PBO.PBF{S,T}(:x => -99.0),
        (u, -2.0) => PBO.PBF{S,T}(:x => -2.0, :y => -2.0),
        (t, t)    => PBO.PBF{S,T}([:x, :y] => 2.0, :x => -1.0, :y => -1.0, 1.0),
        (p, q)    => PBO.PBF{S,T}(0.25, :x => 0.5, :y => 0.5, [:x, :y] => -3.0),
        (q, p)    => PBO.PBF{S,T}(0.25, :x => 0.5, :y => 0.5, [:x, :y] => -3.0),
        (p, -0.5) => PBO.PBF{S,T}(-0.25, :x => -0.5, [:x, :y] => 1.0),
        (-0.5, p) => PBO.PBF{S,T}(-0.25, :x => -0.5, [:x, :y] => 1.0),
    ],
    (/) => [
        (p, 2.0) => PBO.PBF{S,T}(0.25, :x => 0.5, [:x, :y] => -1.0),
        (p, 0.0) => DivideError,
    ],
    (^) => [
        (p, 0) => one(PBO.PBF{S,T}),
        (q, 0) => one(PBO.PBF{S,T}),
        (r, 0) => one(PBO.PBF{S,T}),
        (s, 0) => one(PBO.PBF{S,T}),
        (t, 0) => one(PBO.PBF{S,T}),
        (u, 0) => one(PBO.PBF{S,T}),
        (v, 0) => one(PBO.PBF{S,T}),
        (w, 0) => one(PBO.PBF{S,T}),
        (β, 0) => one(PBO.PBF{S,T}),
        (α, 0) => one(PBO.PBF{S,T}),
        (p, 1) => p,
        (q, 1) => q,
        (r, 1) => r,
        (s, 1) => s,
        (t, 1) => t,
        (u, 1) => u,
        (v, 1) => v,
        (w, 1) => w,
        (β, 1) => β,
        (α, 1) => α,
        (p, 2) => PBO.PBF{S,T}(0.25, :x => 2.0, [:x, :y] => -2.0),
        (q, 2) => PBO.PBF{S,T}(0.25, :y => 2.0, [:x, :y] => 10.0),
        (r, 2) => PBO.PBF{S,T}(1.0, :z => -1.0),
        (s, 2) => PBO.PBF{S,T}([:x, :y, :z] => 9.0),
        (r, 3) => PBO.PBF{S,T}(1.0, :z => -1.0),
        (s, 3) => PBO.PBF{S,T}([:x, :y, :z] => 27.0),
        (r, 4) => PBO.PBF{S,T}(1.0, :z => -1.0),
    ],
    (|>) => [
        (x, q) => 0.5,
        (y, q) => 1.5,
        (z, q) => 0.5,
        (x, r) => 1.0,
        (y, r) => 1.0,
        (z, r) => 0.0,
        (x, s) => 0.0,
        (y, s) => 0.0,
        (z, s) => 0.0,
        (x, p) => 1.5,
        (y, p) => 0.5,
        (z, p) => 0.5,
    ]
]
end