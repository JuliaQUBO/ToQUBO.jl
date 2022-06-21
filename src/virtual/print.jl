function Base.show(io::IO, model::AbstractVirtualModel)
    print(io, 
    """
    Virtual Model
    with source:
    $(MOI.get(model, VM.SourceModel()))
    with target:
    $(MOI.get(model, VM.TargetModel()))
    """
    )
end