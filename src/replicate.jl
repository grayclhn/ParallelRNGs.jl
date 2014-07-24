# `replicate` calls `sim` on the output of the `dgp` function `n`
# times.

function replicate(sim::Function, dgp::Function, n::Integer;
                   err_retry=true, err_stop=false)
    function rvproducer()
        for i = 1:n
            produce(dgp())
        end
    end

    pmap(sim, Task(rvproducer), err_retry=err_retry, err_stop=err_stop)
end

replicate(dgp::Function, n::Integer; err_retry=true, err_stop=false) =
    replicate(identity, dgp, n, err_retry=err_retry, err_stop=err_stop)
