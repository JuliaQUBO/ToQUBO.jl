@doc raw"""
    AbstractArchitecture
""" abstract type AbstractArchitecture end

struct GenericArchitecture <: AbstractArchitecture end

@doc raw"""
""" function infer_architecture end

infer_architecture(::Any) = GenericArchitecture()
