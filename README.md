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
<https://github.com/grayclhn/ParallelRNGs.jl/issues>.

This package is only supported on Julia version 0.3.0 or higher. Note
that Julia has a bug prior to commit 9c02c9d that may cause
`replicate` to miss the last few elements --- see issue #7727 in
JuliaLang/julia: <https://github.com/JuliaLang/julia/issues/7727>. As
of this writing, there is a release candidate of v0.3.0 and a
supported release should be available soon.

Example usage
-------------

To generate 400 draws from the distribution of the maximum of 500
independent Gaussian random variables:
```julia
replicate(400) do
    maximum(randn(500))
end
```

The `replicate` code will give essentially identical results to the loop
```julia
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
```julia
replicate(maximum, ()->randn(500), 400)
```

The difference between this version and the first version is that here
the `maximum` function is executed on different processes while it is
executed on the main process in the first call.

Motivation
----------
This part was originally a blog post called *Cobbling together
parallel random number generation in Julia*

I’m starting to work on some computationally demanding projects,
(Monte Carlo simulations of bootstraps of out-of-sample forecast
comparisons) so I thought I should look at Julia some
more. Unfortunately, since Julia’s so young (it’s almost at version
0.3.0 as I write this) a lot of code still needs to be written. Like
Random Number Generators (RNGs) that work in parallel. So this post
describes an approach that parallelizes computation using a standard
RNG; for convenience I’ve put the code (a single function) is in a
grotesquely ambitiously named package on GitHub:
ParallelRNGs.jl. (Also see [this thread][1] on the Julia Users mailing
list.)

A few quick points about RNGs and simulations. Most econometrics
papers have a section that examines the performance of a few
estimators in a known environment (usually the estimators proposed by
the paper and a few of the best preexisting estimators). We do this by
simulating data on a computer, using that data to produce estimates,
and then comparing those estimate to the parameters they’re
estimating. Since we’ve generated the data ourselves, we actually know
the true values of those parameters, so we can make a real
comparison. Do that for 5000 simulated data sets and you can get a
reasonably accurate view of how the statistics might perform in real
life.

For many reasons, it’s useful to be able to reproduce the exact same
simulations again in the future. (Two obvious reasons: it allows other
researchers to be able to reproduce your results, and it can make
debugging much faster when you discover errors.) So we almost always
use pseudo Random Number Generators that use a deterministic algorithm
to produce a stream of numbers that behaves in important ways like a
stream of independent random values. You initialize these RNGs by
setting a starting value (the “pseudo” aspect of the RNGs is implicit
from now on) and anyone who has that starting value can reproduce the
identical sequence of numbers that you generated. A popular RNG is the
“[Mersenne Twister][2],” and “popular” is probably an understatement:
it’s the default RNG in R, Matlab, and Julia. And (from what I’ve
read; this isn’t my field at all) it’s well regarded for producing a
sequence of random numbers for statistical simulations.

But it’s not necessarily appropriate for producing several independent
sequences of random numbers. Which is vitally important because I have
an 8 core workstation that needs to run lots of simulations, and I’d
like to execute 1/8th of the total simulations on each of its cores.

There’s a common misconception that you can get independent random
sequences just by choosing different initial values for each sequence,
but that’s not guaranteed to be true. There are algorithms for
choosing different starting values that are guaranteed to produce
independent streams for the Mersenne Twister ([see this research by
one of the MT’s inventors][3]), but they aren’t implemented in Julia
yet. (Or in R, as far as I can tell; they use a different RNG for
parallel applications.) And it turns out that Mersenne Twister is the
only RNG that’s included in Julia so far.

So, this would be a perfect opportunity for me to step up and
implement some of these advanced algorithms for the Mersenne
Twister. Or to implement some of the algorithms developed by [L’Ecuyer
and his coauthors][4], which are what R uses. And there’s already C
code for both options.

But I haven’t done that yet. :(

Instead, I’ve written an extremely small function that wraps Julia’s
default RNG, calls it from the main process alone to generate random
numbers, and then sends those random numbers to each of the other
processes/cores where the rest of the simulation code runs. The
function’s really simple:

```julia	
function replicate(sim::Function, dgp::Function, n::Integer)
    function rvproducer()
        for i=1:n
            produce(dgp())
        end
    end
    return(pmap(sim, Task(rvproducer)))
end
```

That’s all. If you’re not used to Julia, you can ignore the
`::Function` and the `::Integer` parts of the arguments. Those just
identify the datatype of the argument and you can read it as
`dgp_function` if you want (and explicitly providing the types like
this is optional anyway). So, you give `replicate` two functions:
`dgp` generates the random numbers and `sim` does the remaining
calculations; `n` is the number of simulations to do. All of the work
is done in `[pmap][5]` which parcels out the random numbers and sends
them to different processors. (There’s a simplified version of the
source code for `pmap` at that link.)

And that’s it. Each time a processor finishes one iteration, pmap
calls `dgp()` again to generate more random numbers and passes them
along. It automatically waits for `dgp()` to finish, so there are no
race conditions and it produces the exact same sequence of random
numbers every time. The code is shockingly concise. (It shocked me! I
wrote it up assuming it would fail so I could understand pmap better
and I was pretty surprised when it worked.)

A quick example might help clear up it’s usage. We’ll write a DGP for
the bootstrap:

```julia
const n = 200     # Number of observations for each simulation
const nboot = 299 # Number of bootstrap replications
addprocs(7)       # Start the other 7 cores
dgp() = (randn(n), rand(1:n, (n, nboot)))
```

The data are iid Normal, (the “randn(n)” component) and it’s an iid
nonparametric bootstrap (the “rand(1:n, (n, nboot))”, which draws
independent values from 1 to n and fills them into an n by nboot
matrix).

We’ll use a proxy for some complicated processing step:

```julia	
@everywhere function sim(x)
    nboot = size(x[2], 2)
    bootvals = Array(Float64, nboot)
    for i=1:nboot
        bootvals[i] = mean(x[1][x[2][:,i]])
    end
    confint = quantile(bootvals, [0.05, 0.95])
    sleep(3) # not usually recommended!
    return(confint[1] < 0 < confint[2])
end
```

So `sim` calculates the mean of each bootstrap sample and calculates
the 5th and 95th percentile of those simulated means, giving a
two-sided 90% confidence interval for the true mean. Then it checks
whether the interval contains the true mean (0). And it also wastes 3
seconds sleeping, which is a proxy for more complicated calculations
but usually shouldn’t be in your code. The initial `@everywhere` is a
Julia macro that loads this function into each of the separate
processes so that it’s available for parallelization. (This is
probably as good a place as any to link to Julia’s “Parallel
Computing” documentation.)

Running a short Monte Carlo is simple:

```julia	
julia> srand(84537423); # Initialize the default RNG!!!
julia> @time mc1 = mean(replicate(sim, dgp, 500))
 
elapsed time: 217.705639 seconds (508892580 bytes allocated, 0.13% gc time)
0.896 # = 448/500
```

So, about 3.6 minutes and the confidence intervals have coverage
almost exactly 90%.

It’s also useful to compare the execution time to a purely sequential
approach. We can do that by using a simple for loop:

```julia	
function dosequential(nsims)
    boots = Array(Float64, nsims)
    for i=1:nsims
        boots[i] = sim(dgp())
    end
    return boots
end
```

And, to time it:

```julia	
julia> dosequential(1); # Force compilation before timing
julia> srand(84537423); # Reinitialize the default RNG!!!
julia> @time mc2 = mean(dosequential(500))
 
elapsed time: 1502.038961 seconds (877739616 bytes allocated, 0.03% gc time)
0.896 # = 448/500
```

This takes a lot longer: over 25 minutes, 7 times longer than the
parallel approach (exactly what we’d hope for, since the parallel
approach runs the simulations on 7 cores). And it gives exactly the
same results since we started the RNG at the same initial value.

So this approach to parallelization is great… sometimes.

This approach should work pretty well when there aren’t that many
random numbers being passed to each processor, and when there aren’t
that many simulations being run; i.e. when `sim` is an inherently
complex calculation. Otherwise, the overhead of passing the random
numbers to each process can start to matter a lot. In extreme cases,
`dosequential` can be faster than `replicate` because the overhead of
managing the simulations and passing around random variables dominates
the other calculations. In those applications, a real parallel RNG
becomes a lot more important.

If you want to play with this code yourself, I made a small package
for the replicate function: ParallelRNGs.jl on GitHub (this one). The
name is misleadingly ambitious (ambitiously misleading?), but if I do
add real parallel RNGs to Julia, I’ll put them there too. The code is
still buggy, so use it at your own risk and let me know if you run
into problems. (Filing an issue on GitHub is the best way to report
bugs.)

P.S. I should mention again that Julia is an absolute joy of a
language. Package development isn’t quite as nice as in Clojure, where
it’s straightforward to load and unload variables from the package
namespace (again, there’s lots of code that still needs to be
written). But the actual language is just spectacular and I’d probably
want to use it for simulations even if it were slow. Seriously: seven
lines of new code to get an acceptable parallel RNG.

[1]: http://thread.gmane.org/gmane.comp.lang.julia.user/17383
[2]: http://en.wikipedia.org/wiki/Mersenne_twister
[3]: http://www.math.sci.hiroshima-u.ac.jp/~m-mat/MT/emt.html
[4]: http://www.iro.umontreal.ca/~lecuyer/
[5]: http://julia.readthedocs.org/en/latest/manual/parallel-computing/#scheduling

License and copyright
---------------------

Copyright (c) 2014: Gray Calhoun <gray@clhn.co>. This package is
licensed under the MIT "Expat" License; see the file `LICENSE.md` for
details.
