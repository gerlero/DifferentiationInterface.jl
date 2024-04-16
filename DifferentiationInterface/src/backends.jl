"""
    check_available(backend)

Check whether `backend` is available (i.e. whether the extension is loaded).
"""
check_available(backend::AbstractADType) = false

"""
    check_mutation(backend)

Check whether `backend` supports differentiation of mutating functions.
"""
check_mutation(backend::AbstractADType) = Bool(supports_mutation(backend))

sqnorm(x::AbstractArray) = sum(abs2, x)

"""
    check_hessian(backend)

Check whether `backend` supports second order differentiation by trying to compute a hessian.

!!! warning
    Might take a while due to compilation time.
"""
function check_hessian(backend::AbstractADType)
    try
        x = [3.0]
        hess = hessian(sqnorm, backend, x)
        return isapprox(hess, [2.0;;]; rtol=1e-3)
    catch exception
        @warn "Backend $backend does not support hessian" exception
        return false
    end
end
