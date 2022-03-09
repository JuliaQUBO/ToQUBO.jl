# ToQUBO.jl Booklet

This booklet aims to explain in great detail

## QUBO

```math
\begin{array}{rl}
   \min        & \mathbf{x}^{\intercal} Q\,\mathbf{x} \\
   \text{s.t.} & \mathbf{x} \in \mathbb{B}^{n}
\end{array}
```

```@docs
ToQUBO.isqubo
ToQUBO.toqubo
ToQUBO.toqubo!
```

```@docs
ToQUBO.toqubo_sense!
ToQUBO.toqubo_variables!
ToQUBO.toqubo_constraint!
ToQUBO.toqubo_objective!
```

## Pseudo-Boolean Optimization

Internally, problems are represented through a Pseudo-Boolean Optimization (PBO) framework. The main goal is to represent a given problem using a Pseudo-Boolean Function (PBF) since there is an imediate correspondence between PBFs and QUBO forms.

```@docs
ToQUBO.PBO.PseudoBooleanFunction
ToQUBO.PBO.residual
ToQUBO.PBO.derivative
ToQUBO.PBO.gradient
ToQUBO.PBO.gap
ToQUBO.PBO.sharpness
ToQUBO.PBO.discretize
```

### Quadratization
```@docs
ToQUBO.PBO.quadratize
ToQUBO.PBO.@quadratization
```

## Virtual Mapping

*Proin at felis eu odio fringilla maximus a a diam. Sed sit amet lorem a ex finibus ultrices. Praesent mattis neque eu neque venenatis, nec congue enim mollis. Suspendisse urna tellus, aliquet ut orci a, vulputate vulputate sapien.*

### Virtual Variables

*Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aliquam aliquet nec mauris nec mattis. Aenean pretium mauris elementum nisl sodales elementum. Etiam urna sapien, vehicula ac enim non, egestas accumsan orci.*

```@docs
ToQUBO.VirtualMapping.VirtualVariable
ToQUBO.VirtualMapping.mapvar!
ToQUBO.VirtualMapping.expandℝ!
ToQUBO.VirtualMapping.slackℝ!
ToQUBO.VirtualMapping.expandℤ!
ToQUBO.VirtualMapping.slackℤ!
ToQUBO.VirtualMapping.mirror𝔹!
ToQUBO.VirtualMapping.slack𝔹!
```

### Virtual Models

*Aenean condimentum a libero a condimentum. Aliquam ac nisi id risus malesuada placerat at et diam. Nam eget nibh elit. Cras nec mollis elit, sit amet imperdiet magna. Suspendisse tempor est eu tortor sodales porta.*


```@docs
ToQUBO.VirtualMapping.AbstractVirtualModel
```

*Aenean condimentum a libero a condimentum. Aliquam ac nisi id risus malesuada placerat at et diam. Nam eget nibh elit. Cras nec mollis elit, sit amet imperdiet magna. Suspendisse tempor est eu tortor sodales porta.*

```@docs
ToQUBO.VirtualQUBOModel
```

## MIP Solvers

*Nam justo dui, dignissim eget interdum eget, fermentum fermentum lectus. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Quisque urna enim, semper at elit non, consequat tempus lorem. Phasellus placerat mi ipsum, eu pellentesque erat imperdiet in. Fusce nec mauris ac purus auctor porttitor at nec ligula. Suspendisse vitae molestie felis. In hac habitasse platea dictumst. Vestibulum leo lectus, rutrum sit amet molestie vel, posuere vel ex. Vestibulum imperdiet sollicitudin metus ut venenatis.*

## Annealing

*Aliquam auctor placerat massa, sed posuere leo volutpat eget. Donec quis feugiat nulla, vitae porta eros.*

### Simulated Annealing
*Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc a congue tortor. Praesent vestibulum sapien id nunc pulvinar feugiat. Mauris at turpis vel lacus pretium accumsan.*

### Quantum Annealing
*Curabitur pretium consectetur lobortis. Nunc pretium ornare arcu, et accumsan metus aliquet et. Quisque efficitur nunc justo, vitae eleifend tortor rhoncus a. Sed nec maximus orci.*

### Errors
```@docs
ToQUBO.QUBOError
```