# ToQUBO.jl Booklet

This page contains information about ToQUBO's inner functions and theoretical overview.

## QUBO

*In in auctor nunc, nec commodo dolor. Fusce vel mi semper libero imperdiet luctus in vel nisl. Nullam sed urna pharetra, rhoncus diam vel, fringilla ipsum. In tempus ligula vel enim condimentum tristique. Nulla blandit congue laoreet. Aenean sagittis ipsum a imperdiet suscipit. Duis in interdum augue, vel volutpat odio. Donec lorem risus, malesuada id consequat in, pretium ut sem. Vestibulum suscipit tempor nibh, nec sodales quam. Curabitur quis condimentum ipsum, quis tincidunt lorem. Sed aliquet ex fermentum, rutrum dolor quis, lacinia elit.*

```@docs
isqubo
toqubo
```

## Pseudo-Boolean Optimization

Internally, problems are represented through a Pseudo-Boolean Optimization (PBO) framework. The main goal is to represent a given problem using a Pseudo-Boolean Function (PBF) since there is an imediate correspondence between PBFs and QUBO forms.

```@docs
PseudoBooleanFunction
gap
Δ
Θ
discretize
```

### Quadratization
```@docs
@quadratization
quadratize
```

## Virtual Mapping

*Proin at felis eu odio fringilla maximus a a diam. Sed sit amet lorem a ex finibus ultrices. Praesent mattis neque eu neque venenatis, nec congue enim mollis. Suspendisse urna tellus, aliquet ut orci a, vulputate vulputate sapien.*

### Virtual Variables

*Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aliquam aliquet nec mauris nec mattis. Aenean pretium mauris elementum nisl sodales elementum. Etiam urna sapien, vehicula ac enim non, egestas accumsan orci.*

```@docs
VirtualVariable
mapvar!
expandℝ!
expandℤ!
slackℤ!
mirror𝔹!
```

### Virtual Models

*Aenean condimentum a libero a condimentum. Aliquam ac nisi id risus malesuada placerat at et diam. Nam eget nibh elit. Cras nec mollis elit, sit amet imperdiet magna. Suspendisse tempor est eu tortor sodales porta.*

```@docs
VirtualQUBOModel
```

## MIP Solvers

*Nam justo dui, dignissim eget interdum eget, fermentum fermentum lectus. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Quisque urna enim, semper at elit non, consequat tempus lorem. Phasellus placerat mi ipsum, eu pellentesque erat imperdiet in. Fusce nec mauris ac purus auctor porttitor at nec ligula. Suspendisse vitae molestie felis. In hac habitasse platea dictumst. Vestibulum leo lectus, rutrum sit amet molestie vel, posuere vel ex. Vestibulum imperdiet sollicitudin metus ut venenatis.*

## Annealing

*Aliquam auctor placerat massa, sed posuere leo volutpat eget. Donec quis feugiat nulla, vitae porta eros.*

### Simulated Annealing
*Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc a congue tortor. Praesent vestibulum sapien id nunc pulvinar feugiat. Mauris at turpis vel lacus pretium accumsan.*

### Quantum Annealing
*Curabitur pretium consectetur lobortis. Nunc pretium ornare arcu, et accumsan metus aliquet et. Quisque efficitur nunc justo, vitae eleifend tortor rhoncus a. Sed nec maximus orci.*
