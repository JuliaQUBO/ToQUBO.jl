@doc raw"""
    AbstractArchitecture
""" abstract type AbstractArchitecture end

@doc raw"""
    GenericArchitecture()

This type is used to reach fallback implementations for [`AbstractArchitecture`](@ref) and, therefore,
should not have any methods directely related to it.
""" struct GenericArchitecture <: AbstractArchitecture end

@doc raw"""
""" function infer_architecture end

infer_architecture(::Any) = GenericArchitecture()
