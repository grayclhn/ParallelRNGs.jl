# `replicate` calls `sim` on the output of the `dgp` function `n`
# times.

function replicate(sim::Function, dgp::Function, n::Integer)
    function rvproducer()
        for i = 1:n
            produce(dgp())
        end
    end

    pmap(sim, Task(rvproducer))
end

replicate(dgp::Function, n::Integer) = replicate(identity, dgp, n)
