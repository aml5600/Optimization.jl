struct AutoModelingToolkit <: AbstractADType
    obj_sparse::Bool
    cons_sparse::Bool
end

AutoModelingToolkit() = AutoModelingToolkit(false, false)

function instantiate_function(f, x, ad::AutoModelingToolkit, p, num_cons=0)
    p = isnothing(p) ? SciMLBase.NullParameters() : p
    sys = ModelingToolkit.modelingtoolkitize(OptimizationProblem(f, x, p))

    if f.grad === nothing
        grad_oop, grad_iip = ModelingToolkit.generate_gradient(sys, expression=Val{false})
        grad(J, u) = (grad_iip(J, u, p); J)
    else
        grad = f.grad
    end

    if f.hess === nothing
        hess_oop, hess_iip = ModelingToolkit.generate_hessian(sys, expression=Val{false}, sparse = ad.obj_sparse)
        hess(H, u) = (hess_iip(H, u, p); H)
    else
        hess = f.hess
    end

    if f.hv === nothing
        hv = function (H, θ, v, args...)
            res = ArrayInterfaceCore.zeromatrix(θ)
            hess(res, θ, args...)
            H .= res * v
        end
    else
        hv = f.hv
    end

    if f.cons === nothing
        cons = nothing
    else
        cons = (θ) -> f.cons(θ, p)
        cons_sys = ModelingToolkit.modelingtoolkitize(NonlinearProblem(f.cons, x, p))
    end

    if f.cons !== nothing && f.cons_j === nothing
        jac_oop, jac_iip = ModelingToolkit.generate_jacobian(cons_sys, expression=Val{false}, sparse=ad.cons_sparse)
        cons_j = function (J, θ)
            jac_iip(J, θ, p)
        end
    else
        cons_j = f.cons_j
    end

    if f.cons !== nothing && f.cons_h === nothing
        cons_hess_oop, cons_hess_iip = ModelingToolkit.generate_hessian(cons_sys, expression=Val{false}, sparse=ad.cons_sparse)
        cons_h = function (res, θ)
            cons_hess_iip(res, θ, p)
        end
    else
        cons_h = f.cons_h
    end

    return OptimizationFunction{true,AutoModelingToolkit,typeof(f.f),typeof(grad),typeof(hess),typeof(hv),typeof(cons),typeof(cons_j),typeof(cons_h)}(f.f, AutoModelingToolkit(), grad, hess, hv, cons, cons_j, cons_h)
end
