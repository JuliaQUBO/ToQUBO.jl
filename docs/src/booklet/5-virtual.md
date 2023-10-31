# Virtual Mapping

During reformulation, `ToQUBO` holds two distinct models, namely the *Source Model* and the *Target Model*.
The source model is a generic `MOI` model restricted to the supported constraints.
The target one is on the QUBO form used during the solving process.
Both lie within a *Virtual Model*, which provides the necessary API integration and keeps all variable and constraint mapping tied together.

This is done in a transparent fashion for both agents since the user will mostly interact with the presented model, and the solvers will only access the generated one.

## Virtual Model

```@docs
ToQUBO.Virtual.Model
```

```@docs
ToQUBO.Virtual.source
ToQUBO.Virtual.target
```

## Virtual Variables

Every virtual model stores a collection of virtual variables, intended to provide a link between those in the source and those to be created in the target model.
Each virtual variable stores encoding information for later expansion and evaluation.

```@docs
ToQUBO.Virtual.Variable
```

```@docs
ToQUBO.Virtual.encoding
ToQUBO.Virtual.expansion
ToQUBO.Virtual.penaltyfn
```
