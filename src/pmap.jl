# Additional method for pmap. This one adds hooks to call before and
# after each parallel execution. See julia/base/multi.jl for the
# original versions of pmap; most of our version is copied and pasted
# from the original (as of 7/25/2014)
#
# * pre_call is a function that is called just before f is executed on
#   another process and takes the worker id as a single argument.
# * post_call is called just after f is executed and takes the worker
#   id and the result as its arguments.

function pmap(f, pre_call::Function, post_call::Function, lsts...;
              err_retry=true, err_stop=false)
    len = length(lsts)

    results = Dict{Int,Any}()

    retryqueue = {}
    task_in_err = false
    is_task_in_error() = task_in_err
    set_task_in_error() = (task_in_err = true)

    nextidx = 0
    getnextidx() = (nextidx += 1)

    states = [start(lsts[idx]) for idx in 1:len]
    function getnext_tasklet()
        if is_task_in_error() && err_stop
            return nothing
        elseif !any(idx->done(lsts[idx],states[idx]), 1:len)
            nxts = [next(lsts[idx],states[idx]) for idx in 1:len]
            for idx in 1:len; states[idx] = nxts[idx][2]; end
            nxtvals = [x[1] for x in nxts]
            return (getnextidx(), nxtvals)
            
        elseif !isempty(retryqueue)
            return shift!(retryqueue)
        else    
            return nothing
        end
    end

    @sync begin
        for wpid in workers()
            @async begin
                tasklet = getnext_tasklet()
                while (tasklet != nothing)
                    (idx, fvals) = tasklet
                    pre_call(wpid)
                    try
                        result = remotecall_fetch(wpid, f, fvals...)
                        post_call(wpid, result)
                        if isa(result, Exception)
                            ((wpid == myid()) ? rethrow(result) : throw(result))                         else 
                            results[idx] = result
                        end
                    catch ex
                        if err_retry 
                            push!(retryqueue, (idx,fvals, ex))
                        else
                            results[idx] = ex
                        end
                        set_task_in_error()
                         break # remove this worker from accepting any more tasks 
                    end
                    tasklet = getnext_tasklet()
                end
            end
        end
    end

    for failure in retryqueue
        results[failure[1]] = failure[3]
    end
    [results[x] for x in 1:nextidx]
end
