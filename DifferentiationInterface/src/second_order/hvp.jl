## Docstrings

"""
    prepare_hvp(f, backend, x, v) -> extras

Create an `extras` object that can be given to [`hvp`](@ref) and its variants.

!!! warning
    If the function changes in any way, the result of preparation will be invalidated, and you will need to run it again.
"""
function prepare_hvp end

"""
    prepare_hvp_same_point(f, backend, x, v) -> extras_same

Create an `extras_same` object that can be given to [`hvp`](@ref) and its variants _if they are applied at the same point `x`_.

!!! warning
    If the function or the point changes in any way, the result of preparation will be invalidated, and you will need to run it again.
"""
function prepare_hvp_same_point end

"""
    hvp(f, backend, x, v, [extras]) -> p

Compute the Hessian-vector product of `f` at point `x` with seed `v`.
"""
function hvp end

"""
    hvp!(f, p, backend, x, v, [extras]) -> p

Compute the Hessian-vector product of `f` at point `x` with seed `v`, overwriting `p`.
"""
function hvp! end

## Preparation

"""
    HVPExtras

Abstract type for additional information needed by [`hvp`](@ref) and its variants.
"""
abstract type HVPExtras <: Extras end

struct NoHVPExtras <: HVPExtras end

#=
Source: https://arxiv.org/abs/2403.14606 (section 8.1)

By order of preference:
- forward on reverse
- reverse on forward
- reverse on reverse
- forward on forward
=#

struct ForwardOverForwardHVPExtras{C,E} <: HVPExtras
    inner_gradient_closure::C
    outer_pushforward_extras::E
end

struct ForwardOverReverseHVPExtras{C,E} <: HVPExtras
    inner_gradient_closure::C
    outer_pushforward_extras::E
end

struct ReverseOverForwardHVPExtras{C,E} <: HVPExtras
    inner_pushforward_closure_generator::C
    outer_gradient_extras::E
end

struct ReverseOverReverseHVPExtras{C,E} <: HVPExtras
    inner_gradient_closure::C
    outer_pullback_extras::E
end

function prepare_hvp(f::F, backend::AbstractADType, x, v) where {F}
    return prepare_hvp(f, SecondOrder(backend, backend), x, v)
end

function prepare_hvp(f::F, backend::SecondOrder, x, v) where {F}
    return prepare_hvp_aux(f, backend, x, v, hvp_mode(backend))
end

function prepare_hvp_aux(f::F, backend::SecondOrder, x, v, ::ForwardOverForward) where {F}
    # pushforward of many pushforwards in theory, but pushforward of gradient in practice
    inner_backend = nested(inner(backend))
    inner_gradient_closure(z) = gradient(f, inner_backend, z)
    outer_pushforward_extras = prepare_pushforward(
        inner_gradient_closure, outer(backend), x, v
    )
    return ForwardOverForwardHVPExtras(inner_gradient_closure, outer_pushforward_extras)
end

function prepare_hvp_aux(f::F, backend::SecondOrder, x, v, ::ForwardOverReverse) where {F}
    # pushforward of gradient
    inner_backend = nested(inner(backend))
    inner_gradient_closure(z) = gradient(f, inner_backend, z)
    outer_pushforward_extras = prepare_pushforward(
        inner_gradient_closure, outer(backend), x, v
    )
    return ForwardOverReverseHVPExtras(inner_gradient_closure, outer_pushforward_extras)
end

function prepare_hvp_aux(f::F, backend::SecondOrder, x, v, ::ReverseOverForward) where {F}
    # gradient of pushforward
    # uses v in the closure
    inner_backend = nested(inner(backend))
    function inner_pushforward_closure_generator(v)
        inner_pushforward_closure(z) = pushforward(f, inner_backend, z, v)
        return inner_pushforward_closure
    end
    outer_gradient_extras = prepare_gradient(
        inner_pushforward_closure_generator(v), outer(backend), x
    )
    return ReverseOverForwardHVPExtras(
        inner_pushforward_closure_generator, outer_gradient_extras
    )
end

function prepare_hvp_aux(f::F, backend::SecondOrder, x, v, ::ReverseOverReverse) where {F}
    # pullback of the gradient
    inner_backend = nested(inner(backend))
    inner_gradient_closure(z) = gradient(f, inner_backend, z)
    outer_pullback_extras = prepare_pullback(inner_gradient_closure, outer(backend), x, v)
    return ReverseOverReverseHVPExtras(inner_gradient_closure, outer_pullback_extras)
end

## Preparation (same point)

function prepare_hvp_same_point(
    f::F, backend::AbstractADType, x, v, extras::HVPExtras
) where {F}
    return extras
end

function prepare_hvp_same_point(f::F, backend::AbstractADType, x, v) where {F}
    extras = prepare_hvp(f, backend, x, v)
    return prepare_hvp_same_point(f, backend, x, v, extras)
end

## One argument

function hvp(
    f::F, backend::AbstractADType, x, v, extras::HVPExtras=prepare_hvp(f, backend, x, v)
) where {F}
    return hvp(f, SecondOrder(backend, backend), x, v, extras)
end

function hvp(
    f::F, backend::SecondOrder, x, v, extras::HVPExtras=prepare_hvp(f, backend, x, v)
) where {F}
    return hvp_aux(f, backend, x, v, extras)
end

function hvp_aux(f::F, backend, x, v, extras::ForwardOverForwardHVPExtras) where {F}
    @compat (; inner_gradient_closure, outer_pushforward_extras) = extras
    return pushforward(
        inner_gradient_closure, outer(backend), x, v, outer_pushforward_extras
    )
end

function hvp_aux(f::F, backend, x, v, extras::ForwardOverReverseHVPExtras) where {F}
    @compat (; inner_gradient_closure, outer_pushforward_extras) = extras
    return pushforward(
        inner_gradient_closure, outer(backend), x, v, outer_pushforward_extras
    )
end

function hvp_aux(f::F, backend, x, v, extras::ReverseOverForwardHVPExtras) where {F}
    @compat (; inner_pushforward_closure_generator, outer_gradient_extras) = extras
    inner_pushforward_closure = inner_pushforward_closure_generator(v)
    return gradient(inner_pushforward_closure, outer(backend), x, outer_gradient_extras)
end

function hvp_aux(f::F, backend, x, v, extras::ReverseOverReverseHVPExtras) where {F}
    @compat (; inner_gradient_closure, outer_pullback_extras) = extras
    return pullback(inner_gradient_closure, outer(backend), x, v, outer_pullback_extras)
end

function hvp!(
    f::F, p, backend::AbstractADType, x, v, extras::HVPExtras=prepare_hvp(f, backend, x, v)
) where {F}
    return hvp!(f, p, SecondOrder(backend, backend), x, v, extras)
end

function hvp!(
    f::F, p, backend::SecondOrder, x, v, extras::HVPExtras=prepare_hvp(f, backend, x, v)
) where {F}
    return hvp_aux!(f, p, backend, x, v, extras)
end

function hvp_aux!(f::F, p, backend, x, v, extras::ForwardOverForwardHVPExtras) where {F}
    @compat (; inner_gradient_closure, outer_pushforward_extras) = extras
    return pushforward!(
        inner_gradient_closure, p, outer(backend), x, v, outer_pushforward_extras
    )
end

function hvp_aux!(f::F, p, backend, x, v, extras::ForwardOverReverseHVPExtras) where {F}
    @compat (; inner_gradient_closure, outer_pushforward_extras) = extras
    return pushforward!(
        inner_gradient_closure, p, outer(backend), x, v, outer_pushforward_extras
    )
end

function hvp_aux!(f::F, p, backend, x, v, extras::ReverseOverForwardHVPExtras) where {F}
    @compat (; inner_pushforward_closure_generator, outer_gradient_extras) = extras
    inner_pushforward_closure = inner_pushforward_closure_generator(v)
    return gradient!(inner_pushforward_closure, p, outer(backend), x, outer_gradient_extras)
end

function hvp_aux!(f::F, p, backend, x, v, extras::ReverseOverReverseHVPExtras) where {F}
    @compat (; inner_gradient_closure, outer_pullback_extras) = extras
    return pullback!(inner_gradient_closure, p, outer(backend), x, v, outer_pullback_extras)
end
