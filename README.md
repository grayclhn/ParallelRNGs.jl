ParallelRNGs
============

[![Build Status](https://travis-ci.org/grayclhn/ParallelRNGs.jl.svg?branch=master)](https://travis-ci.org/grayclhn/ParallelRNGs.jl)

Basic support for Random Number Generators for Julia for simulations
that execute in parallel. Right now, the repository has a single
function, `replicate`, that uses a task to generate a stream of random
numbers on the main process that are used in calculations in a other
processes.

For discussion, see this thread on the Julia-Users mailing list:
<http://thread.gmane.org/gmane.comp.lang.julia.user/17383>

This package has almost nothing in it so far, and very little
documentation (i.e., this is it!) Use it at your own risk. When you
find errors, please file an issue on GitHub:
<https://github.com/grayclhn/ParallelRNGs.jl/issues>

Example usage
-------------

To generate 400 draws from the distribution of the maximum of 500
independent Gaussian random variables:
```
replicate(400) do
    maximum(randn(500))
end
```

The `replicate` code will give essentially identical results to the loop
```
A = Array(Float64, 400)
for i = 1:400
    A[i] = maximum(randn(500))
end
```
but will execute on other processes if they are available. It gives
"essentially identical" results because `replicate` will generally
order the results differently than the for loop, but each approach
will take the maximum of the exact same 500 random normals for each
element.

For more complicated statistics, we can provide a deterministic
processing step. The same code as above can be written as
```
replicate(maximum, ()->randn(500), 400)
```

The difference between this version and the first version is that here
the `maximum` function is executed on different processes while it is
executed on the main process in the first call.

License and copyright
---------------------

Copyright (c) 2014: Gray Calhoun <gray@clhn.co>. This package is
licensed under the MIT "Expat" License; see the file `LICENSE.md` for
details.
