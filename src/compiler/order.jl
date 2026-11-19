# Deterministic traversal of the compiler's constraint- and variable-keyed maps.
#
# `model.g`, `model.h`, `model.s` and the penalty-factor maps are `Dict`s keyed by
# `MOI.ConstraintIndex` or `MOI.VariableIndex`. Their iteration order follows
# hashes that can differ between Julia versions and precompile caches
# (`MOI.ConstraintIndex` has no custom `hash`). Every result that depends on the
# visiting order (floating-point accumulation into the Hamiltonian, the first
# reported certification failure, recorded penalty-policy lists, the first
# matching candidate of a search) therefore traverses these maps in the order
# below: constraints by index value, then function type, then set type;
# variables by index value.
#
# Types are named canonically (defining module path, type name, parameters), not
# with `string(T)` or `repr`: their display depends on which names are imported
# into `Main`, so it can change between sessions of the same installation.
# Names record defining module paths and tag value parameters with their type,
# so for the built-in parameter structures below (types, unions, binders,
# varargs, enums, numbers, characters, symbols, tuples) they do not depend on
# `Main`'s imports. Other parameter values use a type-tagged `repr` fallback and
# are only as stable as their `show` method. Type variables are identified by
# name and bounds, not by binder identity (distinct same-named variables can
# share a name); concrete MOI constraint types do not contain type variables.
function _canonical_type_name(T::DataType)
    name = join((string.(fullname(parentmodule(T)))..., string(nameof(T))), ".")
    isempty(T.parameters) && return name
    return name * "{" * join(map(_canonical_type_name, T.parameters), ",") * "}"
end

function _canonical_type_name(T::Union)
    return "Union{" * join(sort!(map(_canonical_type_name, Base.uniontypes(T))), ",") * "}"
end

_canonical_type_name(::Type{Union{}}) = "Union{}"

# Binders stay explicit so correlated and independent type variables differ.
_canonical_type_name(T::UnionAll) =
    "UnionAll(" * _canonical_type_name(T.var) * "," * _canonical_type_name(T.body) * ")"

_canonical_type_name(x::TypeVar) =
    "TypeVar(" * string(x.name) * "," * _canonical_type_name(x.lb) * "," * _canonical_type_name(x.ub) * ")"

function _canonical_type_name(x::Core.TypeofVararg)
    isdefined(x, :T) || return "Vararg"
    isdefined(x, :N) || return "Vararg(" * _canonical_type_name(x.T) * ")"
    return "Vararg(" * _canonical_type_name(x.T) * "," * _canonical_type_name(x.N) * ")"
end

# Value parameters (as in `MOI.Indicator{MOI.ACTIVATE_ON_ONE}`): tagged with their
# canonical type; enums by integer value, other values by their literal text.
_canonical_type_name(x::Base.Enum) = _canonical_type_name(typeof(x)) * "(" * string(Integer(x)) * ")"
_canonical_type_name(x::Symbol) = "Core.Symbol(" * repr(string(x)) * ")"
_canonical_type_name(x::Tuple) = "Core.Tuple(" * join(map(_canonical_type_name, x), ",") * ")"
_canonical_type_name(x::Union{Integer,AbstractFloat,AbstractChar}) =
    _canonical_type_name(typeof(x)) * "(" * repr(x) * ")"
# Any other value: tagged by type, text from `repr` (see the contract above).
_canonical_type_name(x) = _canonical_type_name(typeof(x)) * "(" * repr(x) * ")"

_traversal_key(ci::MOI.ConstraintIndex{F,S}) where {F,S} =
    (ci.value, _canonical_type_name(F), _canonical_type_name(S))
_traversal_key(vi::VI) = (vi.value, "", "")

function _ordered_pairs(d::AbstractDict)
    entries = collect(d)
    length(entries) <= 1 && return entries
    order = sortperm(map(entry -> _traversal_key(first(entry)), entries))
    return entries[order]
end

# Deterministic key of a pseudo-Boolean term: its variable indices.
_term_order_key(ω::PBO.Term) = Int[v.value for v in ω.ω]
