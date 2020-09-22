using StatsBase


# Support some of the weighted statistics function in StatsBase
# NOTES:
# - Ambiguity errors are still possible for weights with overly specific methods (e.g., UnitWeights)
# - Ideally, when the weighted statistics is moved to Statistics.jl we can remove this entire file.
#   https://github.com/JuliaLang/Statistics.jl/pull/2
function Statistics.mean(A::KeyedArray, wv::AbstractWeights; dims=:, kwargs...)
    dims === Colon() && return mean(parent(A), wv; kwargs...)
    numerical_dims = AxisKeys.hasnames(A) ? NamedDims.dim(dimnames(A), dims) : dims
    data = mean(parent(A), wv; dims=numerical_dims, kwargs...)
    new_keys = ntuple(d -> d in numerical_dims ? Base.OneTo(1) : axiskeys(A,d), ndims(A))
    return KeyedArray(data, map(copy, new_keys))#, copy(A.meta))
end

function Statistics.mean(A::KeyedArray, wv::KeyedVector; kwargs...)
    return mean(A, hasnames(wv) ? parent(parent(wv)) : parent(wv); kwargs...)
end

# var and std are separate cause they don't use the dims keyword and we need to set corrected=true
for fun in [:var, :std]
    @eval function Statistics.$fun(A::KeyedArray, wv::AbstractWeights; dims=:, corrected=true, kwargs...)
        dims === Colon() && return $fun(parent(A), wv; kwargs...)
        numerical_dims = AxisKeys.hasnames(A) ? NamedDims.dim(dimnames(A), dims) : dims
        data = $fun(parent(A), wv, numerical_dims; corrected=corrected, kwargs...)
        new_keys = ntuple(d -> d in numerical_dims ? Base.OneTo(1) : axiskeys(A,d), ndims(A))
        return KeyedArray(data, map(copy, new_keys))#, copy(A.meta))
    end

    @eval function Statistics.$fun(A::KeyedArray, wv::KeyedVector; kwargs...)
        return $fun(A, hasnames(wv) ? parent(parent(wv)) : parent(wv); kwargs...)
    end
end

function Statistics.cov(A::KeyedMatrix, wv::AbstractWeights; dims=1, corrected=true, kwargs...)
    # A little awkward, but the weighted `cov` method from statsbase only works
    # on dense matrices, so we need to unwrap this twice and completely rebuild the
    # array
    if AxisKeys.hasnames(A)
        numerical_dim = NamedDims.dim(dimnames(A), dims)
        data = cov(parent(parent(A)), wv, numerical_dim; corrected=corrected, kwargs...)
        rem_dim = first(setdiff(ndims(A), numerical_dim))
        rem_name = dimnames(A, rem_dim)
        rem_key = axiskeys(A, rem_dim)
        return KeyedArray(
            NamedDimsArray(data, (rem_name, rem_name)),
            (copy(rem_key), copy(rem_key))
        )
    else
        data = cov(parent(A), wv, dims; corrected=corrected, kwargs...)
        # Use same remaining axis for both dimensions of data
        rem_dim = first(setdiff(ndims(A), dims))
        new_keys = Tuple(copy(axiskeys(A, rem_dim)) for i in 1:2)
        return KeyedArray(data, new_keys)
    end
end

function Statistics.cov(A::KeyedArray, wv::KeyedVector; kwargs...)
    return cov(A, hasnames(wv) ? parent(parent(wv)) : parent(wv); kwargs...)
end

function Statistics.cor(A::KeyedMatrix, wv::AbstractWeights; dims=1, kwargs...)
    # A little awkward, but the weighted `cov` method from statsbase only works
    # on dense matrices, so we need to unwrap this twice and completely rebuild the
    # array
    if AxisKeys.hasnames(A)
        numerical_dim = NamedDims.dim(dimnames(A), dims)
        data = cor(parent(parent(A)), wv, numerical_dim; kwargs...)
        rem_dim = first(setdiff((1, 2), numerical_dim))
        rem_name = dimnames(A, rem_dim)
        rem_key = axiskeys(A, rem_dim)
        return KeyedArray(
            NamedDimsArray(data, (rem_name, rem_name)),
            (copy(rem_key), copy(rem_key))
        )
    else
        data = cor(parent(A), wv, dims; kwargs...)
        # Use same remaining axis for both dimensions of data
        rem_dim = first(setdiff((1, 2), dims))
        new_keys = Tuple(copy(axiskeys(A, rem_dim)) for i in 1:2)
        return KeyedArray(data, new_keys)
    end
end

function Statistics.cor(A::KeyedArray, wv::KeyedVector; kwargs...)
    return cor(A, hasnames(wv) ? parent(parent(wv)) : parent(wv); kwargs...)
end

# Similar to cov and cor, but we aren't extending Statistics
function StatsBase.scattermat(A::KeyedMatrix, wv::Vararg{<:AbstractWeights}; dims=1, kwargs...)
    # A little awkward, but the weighted `cov` method from statsbase only works
    # on dense matrices, so we need to unwrap this twice and completely rebuild the
    # array
    if AxisKeys.hasnames(A)
        numerical_dim = NamedDims.dim(dimnames(A), dims)
        data = scattermat(parent(parent(A)), wv...; dims=numerical_dim, kwargs...)
        rem_dim = first(setdiff((1, 2), numerical_dim))
        rem_name = dimnames(A, rem_dim)
        rem_key = axiskeys(A, rem_dim)
        return KeyedArray(
            NamedDimsArray(data, (rem_name, rem_name)),
            (copy(rem_key), copy(rem_key))
        )
    else
        data = scattermat(parent(A), wv...; dims=dims, kwargs...)
        # Use same remaining axis for both dimensions of data
        rem_dim = first(setdiff((1, 2), dims))
        new_keys = Tuple(copy(axiskeys(A, rem_dim)) for i in 1:2)
        return KeyedArray(data, new_keys)
    end
end

function StatsBase.scattermat(A::KeyedArray, wv::KeyedVector; kwargs...)
    return scattermat(A, hasnames(wv) ? parent(parent(wv)) : parent(wv); kwargs...)
end

function StatsBase.mean_and_std(A::KeyedMatrix, wv::Vararg{<:AbstractWeights}; dims=:, corrected::Bool=true, kwargs...)
    return (
        mean(A, wv...; dims=dims, kwargs...),
        std(A, wv...; dims=dims, corrected=corrected, kwargs...)
    )
end
function StatsBase.mean_and_std(A::KeyedArray, wv::KeyedVector; kwargs...)
    return mean_and_std(A, hasnames(wv) ? parent(parent(wv)) : parent(wv); kwargs...)
end

function StatsBase.mean_and_var(A::KeyedMatrix, wv::Vararg{<:AbstractWeights}; dims=:, corrected::Bool=true, kwargs...)
    return (
        mean(A, wv...; dims=dims, kwargs...),
        var(A, wv...; dims=dims, corrected=corrected, kwargs...)
    )
end
function StatsBase.mean_and_var(A::KeyedArray, wv::KeyedVector; kwargs...)
    return mean_and_var(A, hasnames(wv) ? parent(parent(wv)) : parent(wv); kwargs...)
end

function StatsBase.mean_and_cov(A::KeyedMatrix, wv::Vararg{<:AbstractWeights}; dims=:, corrected::Bool=true, kwargs...)
    return (
        mean(A, wv...; dims=dims, kwargs...),
        cov(A, wv...; dims=dims, corrected=corrected, kwargs...)
    )
end
function StatsBase.mean_and_cov(A::KeyedArray, wv::KeyedVector; kwargs...)
    return mean_and_cov(A, hasnames(wv) ? parent(parent(wv)) : parent(wv); kwargs...)
end

# Since we get ambiguity errors with specific implementations we need to wrap each supported method
# A better approach might be to add `NamedDims` support to CovarianceEstimators.jl in the future.
using CovarianceEstimation
estimators = [
    :SimpleCovariance,
    :LinearShrinkage,
    :DiagonalUnitVariance,
    :DiagonalCommonVariance,
    :DiagonalUnequalVariance,
    :CommonCovariance,
    :PerfectPositiveCorrelation,
    :ConstantCorrelation,
    :AnalyticalNonlinearShrinkage,
]
for estimator in estimators
    @eval function Statistics.cov(ce::$estimator, A::KeyedMatrix, wv::Vararg{<:AbstractWeights}; dims=:, kwargs...)
        if AxisKeys.hasnames(A)
            numerical_dim = NamedDims.dim(dimnames(A), dims)
            data = cov(ce, parent(parent(A)), wv...; dims=numerical_dim, kwargs...)
            rem_dim = first(setdiff(ndims(A), numerical_dim))
            rem_name = dimnames(A, rem_dim)
            rem_key = axiskeys(A, rem_dim)
            return KeyedArray(
                NamedDimsArray(data, (rem_name, rem_name)),
                (copy(rem_key), copy(rem_key))
            )
        else
            data = cov(ce, parent(A), wv...; dims=dims, kwargs...)
            # Use same remaining axis for both dimensions of data
            rem_dim = first(setdiff(ndims(A), dims))
            new_keys = Tuple(copy(axiskeys(A, rem_dim)) for i in 1:2)
            return KeyedArray(data, new_keys)
        end
    end

    @eval function Statistics.cov(ce::$estimator, A::KeyedArray, wv::KeyedVector; kwargs...)
        return cov(ce, A, hasnames(wv) ? parent(parent(wv)) : parent(wv); kwargs...)
    end
end
