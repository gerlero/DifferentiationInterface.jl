"""
    value_and_derivative(backend, f, x, [extras]) -> (y, der)

Compute the primal value `y = f(x)` and the derivative `der = f'(x)` of a scalar-to-scalar function.
"""
function value_and_derivative(backend::AbstractADType, f, x::Number, extras=nothing)
    return value_and_derivative_aux(backend, f, x, extras, mode(backend))
end

function value_and_derivative_aux(
    backend::AbstractADType, f, x::Number, extras, ::ForwardMode
)
    return value_and_pushforward(backend, f, x, one(x), extras)
end

function value_and_derivative_aux(
    backend::AbstractADType, f, x::Number, extras, ::ReverseMode
)
    return value_and_pullback(backend, f, x, one(x), extras)
end

"""
    derivative(backend, f, x, [extras]) -> der

Compute the derivative `der = f'(x)` of a scalar-to-scalar function.
"""
function derivative(backend::AbstractADType, f, x::Number, extras=nothing)
    return derivative_aux(backend, f, x, extras, mode(backend))
end

function derivative_aux(backend::AbstractADType, f, x::Number, extras, ::ForwardMode)
    return pushforward(backend, f, x, one(x), extras)
end

function derivative_aux(backend::AbstractADType, f, x::Number, extras, ::ReverseMode)
    return pullback(backend, f, x, one(x), extras)
end