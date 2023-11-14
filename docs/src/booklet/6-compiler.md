# The Compiler

!!! warning "Work in progress"
    We hope to write this part of the documentation soon.
    Please come back later!

## Compilation Steps

### Setup

```@docs
ToQUBO.Compiler.reset!
ToQUBO.Compiler.setup!
```

### Parsing

```@docs
ToQUBO.Compiler.parse!
ToQUBO.Compiler._parse
```

### Reformulation

```@docs
ToQUBO.Compiler.sense!
ToQUBO.Compiler.variable!
ToQUBO.Compiler.variables!
ToQUBO.Compiler.constraint
ToQUBO.Compiler.constraints!
ToQUBO.Compiler.objective!
ToQUBO.Compiler.penalties!
```

#### Copying

```@docs
ToQUBO.Compiler.isqubo
ToQUBO.Compiler.copy!
```

### Hamiltonian Assembly

```@docs
ToQUBO.Compiler.build!
ToQUBO.Compiler.quadratize!
```
