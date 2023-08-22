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

const PBF_CONSTRUCTOR_LIST = [
    (PBO.PBF{S,T}(0.0), PBO.PBF{S,T}()),
    (zero(PBO.PBF{S,T}), PBO.PBF{S,T}()),
    (
        f,
        PBO.PBF{S,T}(
            nothing      => 0.5,
            :x           => 1.0,
            :y           => 1.0,
            :z           => 1.0,
            [:x, :y]     => -2.0,
            [:x, :z]     => -2.0,
            [:y, :z]     => -2.0,
            [:x, :y, :z] => 3.0,
        ),
    ),
    (g, PBO.PBF{S,T}(1.0)),
    (g, one(PBO.PBF{S,T})),
    (h, PBO.PBF{S,T}([:x, :y, :z, :w, nothing])),
    (p, PBO.PBF{S,T}((nothing, 0.5), :x, [:x, :y] => -2.0)),
    (q, PBO.PBF{S,T}(nothing => 0.5, :y, [:x, :y] => 2.0)),
    (r, PBO.PBF{S,T}(nothing, :z => -1.0)),
    (s, PBO.PBF{S,T}(S[] => 0.0, Set{S}([:x, :y, :z]) => 3.0)),
]

const PBF_OPERATOR_LIST = [
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
]

const PBF_EVALUATION_LIST = [
    "dict" => [],
    "set"  => [(q, x) => 0.5, (q, y) => 1.5, (q, z) => 0.5, (r, x) => 1.0, (r, y) => 1.0, (r, z) => 0.0, (s, x) => 0.0, (s, y) => 0.0, (s, z) => 0.0, (p, x) => 1.5, (p, y) => 0.5, (p, z) => 0.5],
]

const PBF_QUBOTOOLS_LIST = [
    (PBO.variable_map) => [
        (f,) => Dict{Symbol,Int}(:x => 1, :y => 2, :z => 3),
        (g,) => Dict{Symbol,Int}(),
        (h,) => Dict{Symbol,Int}(:x => 2, :y => 3, :z => 4, :w => 1),
    ],
    (PBO.variable_inv) => [
        (f,) => Dict{Int,Symbol}(1 => :x, 2 => :y, 3 => :z),
        (g,) => Dict{Int,Symbol}(),
        (h,) => Dict{Int,Symbol}(2 => :x, 3 => :y, 4 => :z, 1 => :w),
    ],
    (PBO.variable_set) => [
        (f,) => Set{Symbol}([:x, :y, :z]),
        (g,) => Set{Symbol}([]),
        (h,) => Set{Symbol}([:x, :y, :z, :w]),
    ],
    (PBO.variables) =>
        [(f,) => Symbol[:x, :y, :z], (g,) => Symbol[], (h,) => Symbol[:w, :x, :y, :z]],
]

end