"""
    ManifoldCountObjective{E,P,O<:AbstractManifoldObjective,I<:Integer} <: AbstractDecoratedManifoldObjective{E,P}

A wrapper for any [`AbstractManifoldObjective`](@ref) of type `O` to count different calls
to parts of the objective.

# Fields

* `counts` a dictionary of symbols mapping to integers keeping the counted values
* `objective` the wrapped objective

# Supported Symbols

| Symbol                      | Counts calls to (incl. `!` variants)  | Comment                      |
| :-------------------------- | :------------------------------------- | :--------------------------- |
| `:Constraints`              | [`get_constraints`](@ref)              |                              |
| `:Cost`                     | [`get_cost`](@ref)                     |                              |
| `:EqualityConstraint`       | [`get_equality_constraint`](@ref)      | requires vector of counters  |
| `:EqualityConstraints`      | [`get_equality_constraints`](@ref)     | does not count single access |
| `:GradEqualityConstraint`   | [`get_grad_equality_constraint`](@ref) | requires vector of counters  |
| `:GradEqualityConstraints`  | [`get_grad_equality_constraints`](@ref)| does not count single access |
| `:GradInequalityConstraint` | [`get_inequality_constraint`](@ref)    | requires vector of counters  |
| `:GradInequalityConstraints`| [`get_inequality_constraints`](@ref)   | does not count single access |
| `:Gradient`                 | [`get_gradient`](@ref)`(M,p)`          |                              |
| `:Hessian`                  | [`get_hessian`](@ref)                  |                              |
| `:InequalityConstraint`     | [`get_inequality_constraint`](@ref)    | requires vector of counters  |
| `:InequalityConstraints`    | [`get_inequality_constraints`](@ref)   | does not count single access |
| `:Preconditioner`           | [`get_preconditioner`](@ref)           |                              |
| `:ProximalMap`              | [`get_proximal_map`](@ref)             |                              |
| `:StochasticGradients`      | [`get_gradients`](@ref)                |                              |
| `:StochasticGradient`       | [`get_gradient`](@ref)`(M, p, i)`      |                              |
| `:SubGradient`              | [`get_subgradient`](@ref)              |                              |
| `:SubtrahendGradient`       | [`get_subtrahend_gradient`](@ref)      |                              |

# Constructors

    ManifoldCountObjective(objective::AbstractManifoldObjective, counts::Dict{Symbol, <:Integer})

Initialise the `ManifoldCountObjective` to wrap `objective` initializing the set of counts

    ManifoldCountObjective(M::AbtractManifold, objective::AbstractManifoldObjective, count::AbstractVecor{Symbol}, init=0)

Count function calls on `objective` using the symbols in `count` initialising all entries to `init`.
"""
struct ManifoldCountObjective{
    E,P,O<:AbstractManifoldObjective,I<:Union{<:Integer,AbstractVector{<:Integer}}
} <: AbstractDecoratedManifoldObjective{E,P}
    counts::Dict{Symbol,I}
    objective::O
end
function ManifoldCountObjective(
    ::AbstractManifold, objective::O, counts::Dict{Symbol,I}
) where {
    E<:AbstractEvaluationType,
    I<:Union{<:Integer,AbstractVector{<:Integer}},
    O<:AbstractManifoldObjective{E},
}
    return ManifoldCountObjective{E,O,O,I}(counts, objective)
end
# Store the undecorated type of the input is decorated
function ManifoldCountObjective(
    ::AbstractManifold, objective::O, counts::Dict{Symbol,I}
) where {
    E<:AbstractEvaluationType,
    I<:Union{<:Integer,AbstractVector{<:Integer}},
    P<:AbstractManifoldObjective,
    O<:AbstractDecoratedManifoldObjective{E,P},
}
    return ManifoldCountObjective{E,P,O,I}(counts, objective)
end
function ManifoldCountObjective(
    M::AbstractManifold,
    objective::O,
    count::AbstractVector{Symbol},
    init::I=0;
    p::P=rand(M),
) where {P,I<:Integer,O<:AbstractManifoldObjective}
    # Infere the sizes of the counters from the symbols if possible
    counts = Pair{Symbol,Union{I,Vector{I}}}[]
    for symbol in count
        l = _get_counter_size(M, objective, symbol, p)
        push!(counts, Pair(symbol, l == 1 ? init : fill(init, l)))
    end

    return ManifoldCountObjective(M, objective, Dict(counts))
end

function _get_counter_size(
    M::AbstractManifold, o::O, s::Symbol, p::P=rand(M)
) where {P,O<:AbstractManifoldObjective}
    # vectorial counting cases
    (s === :EqualityConstraint) && (return length(get_equality_constraints(M, o, p)))
    (s === :GradEqualityConstraint) && (return length(get_equality_constraints(M, o, p)))
    (s === :InequalityConstraint) && (return length(get_inequality_constraints(M, o, p)))
    (s === :GradInequalityConstraint) &&
        (return length(get_inequality_constraints(M, o, p)))
    # For now this only appears in ProximalMapObjective – so we can access its field
    (s === :ProximalMap) && (return length(get_objective(o).proximal_maps!!))
    (s === :StochasticGradient) && (return length(get_gradients(M, o, p)))
    return 1 #number - default
end

function _count_if_exists(co::ManifoldCountObjective, s::Symbol)
    return haskey(co.counts, s) && (co.counts[s] += 1)
end
function _count_if_exists(co::ManifoldCountObjective, s::Symbol, i)
    if haskey(co.counts, s)
        if (i == 1) && (ndims(co.counts[s]) == 0)
            return co.counts[s] += 1
        elseif length(i) == ndims(co.counts[s]) && all(i .<= size(co.counts[s]))
            return co.counts[s][i] += 1
        end
    end
end

"""
    get_count(co::ManifoldCountObjective, s::Symbol, mode::Symbol=:None)

Get the number of counts for a certain symbel `s`.

Depending on the `mode` different results appear if the symbol does not exist in the dictionary

* `:None` – (default) silent mode, returns `-1` for non-existing entries
* `:warn` – issues a warning if a field does not exist
* `:error` – issues an error if a field does not exist
"""
function get_count(co::ManifoldCountObjective, s::Symbol, mode::Symbol=:None)
    if !haskey(co.counts, s)
        msg = "There is no recorded count for $s."
        (mode === :warn) && (@warn msg)
        (mode === :error) && (error(msg))
        return -1
    end
    return co.counts[s]
end
function get_count(o::AbstractManifoldObjective, s::Symbol, mode::Symbol=:None)
    return _get_count(o, dispatch_objective_decorator(o), s, mode)
end
function _get_count(o::AbstractManifoldObjective, ::Val{false}, s, m)
    return error("It seems $o does not provide access to a `ManifoldCountObjective`.")
end
function _get_count(o::AbstractManifoldObjective, ::Val{true}, s, m)
    return get_count(get_objective(o, false), s, m)
end

function get_count(co::ManifoldCountObjective, s::Symbol, i, mode::Symbol=:None)
    if !haskey(co.counts, s)
        msg = "There is no recorded count for :$s."
        (mode === :warn) && (@warn msg)
        (mode === :error) && (error(msg))
        return -1
    end
    if !(ndims(i) == 0 && ndims(co.counts[s]) == 1) && ndims(i) != ndims(co.counts[s])
        msg = "The entry for :$s has $(ndims(co.counts[s])) dimensions but the index you provided has $(ndims(i))"
        (mode === :warn) && (@warn msg)
        (mode === :error) && (error(msg))
        return -1
    end
    if ndims(i) == 0 && ndims(co.counts[s]) == 0
        if i > 1
            msg = "The entry for :$s is a number, but you provided the index $i > 1"
            (mode === :warn) && (@warn msg)
            (mode === :error) && (error(msg))
            return -1
        end
        return co.counts[s]
    end
    if any(i .> size(co.counts[s]))
        msg = "The index $i is out of range for the stored counts in :$s ($(size(co.counts[s])))."
        (mode === :warn) && (@warn msg)
        (mode === :error) && (error(msg))
        return -1
    end
    return co.counts[s][i...]
end
function get_count(o::AbstractManifoldObjective, s::Symbol, i, mode::Symbol=:None)
    return _get_count(o, dispatch_objective_decorator(o), s, i, mode)
end
function _get_count(o::AbstractManifoldObjective, ::Val{false}, s, i, m)
    return error("It seems $o does not provide access to a `ManifoldCountObjective`.")
end
function _get_count(o::AbstractManifoldObjective, ::Val{true}, s, i, m)
    return get_count(get_objective(o, false), s, i, m)
end

"""
    reset_counters(co::ManifoldCountObjective, value::Integer=0)

Reset all values in the count objective to `value`.
"""
function reset_counters!(co::ManifoldCountObjective, value::Integer=0)
    for s in keys(co.counts)
        if (ndims(co.counts[s]) == 0)
            co.counts[s] = value
        else
            co.counts[s] .= value
        end
    end
    return co
end
function reset_counters!(o::AbstractDecoratedManifoldObjective, value::Integer=0)
    return reset_counters!(get_objective(o, false), value)
end
function reset_counters!(o::AbstractManifoldObjective, value::Integer=0)
    return error("It seems $o does not provide access to a `ManifoldCountObjective`.")
end

#
# Overwrite accessors
#
function get_cost(M::AbstractManifold, co::ManifoldCountObjective, p)
    _count_if_exists(co, :Cost)
    return get_cost(M, co.objective, p)
end
function get_cost(
    M::AbstractManifold, co::ManifoldCountObjective{E,<:ManifoldCostGradientObjective}, p
) where {E<:AbstractEvaluationType}
    c, _ = get_cost_and_gradient(M, co, p)
    return c
end
get_cost_function(co::ManifoldCountObjective) = (M, p) -> get_cost(M, co, p)

function get_cost_and_gradient(M::AbstractManifold, co::ManifoldCountObjective, p)
    _count_if_exists(co, :Cost)
    _count_if_exists(co, :Gradient)
    return get_cost_and_gradient(M, co.objective, p)
end

function get_cost_and_gradient!(M::AbstractManifold, X, co::ManifoldCountObjective, p)
    _count_if_exists(co, :Cost)
    _count_if_exists(co, :Gradient)
    return get_cost_and_gradient!(M, X, co.objective, p)
end

get_gradient_function(co::ManifoldCountObjective) = (M, p) -> get_gradient(M, co, p)
function get_gradient(M::AbstractManifold, co::ManifoldCountObjective, p)
    _count_if_exists(co, :Gradient)
    return get_gradient(M, co.objective, p)
end
function get_gradient!(M::AbstractManifold, X, co::ManifoldCountObjective, p)
    _count_if_exists(co, :Gradient)
    get_gradient!(M, X, co.objective, p)
    return X
end
function get_gradient(
    M::AbstractManifold, co::ManifoldCountObjective{E,<:ManifoldCostGradientObjective}, p
) where {E<:AbstractEvaluationType}
    _, X = get_cost_and_gradient(M, co, p)
    return X
end
function get_gradient!(
    M::AbstractManifold, X, co::ManifoldCountObjective{E,<:ManifoldCostGradientObjective}, p
) where {E<:AbstractEvaluationType}
    get_cost_and_gradient!(M, X, co, p)
    return X
end

function get_hessian(M::AbstractManifold, co::ManifoldCountObjective, p, X)
    _count_if_exists(co, :Hessian)
    return get_hessian(M, co.objective, p, X)
end
function get_hessian!(M::AbstractManifold, Y, co::ManifoldCountObjective, p, X)
    _count_if_exists(co, :Hessian)
    get_hessian!(M, Y, co.objective, p, X)
    return Y
end

function get_preconditioner(M::AbstractManifold, co::ManifoldCountObjective, p, X)
    _count_if_exists(co, :Preconditioner)
    return get_preconditioner(M, co.objective, p, X)
end
function get_preconditioner!(M::AbstractManifold, Y, co::ManifoldCountObjective, p, X)
    _count_if_exists(co, :Preconditioner)
    get_preconditioner!(M, Y, co.objective, p, X)
    return Y
end

#
# Constraint
function get_constraints(M::AbstractManifold, co::ManifoldCountObjective, p)
    _count_if_exists(co, :Constraints)
    return get_constraints(M, co.objective, p)
end
function get_equality_constraints(M::AbstractManifold, co::ManifoldCountObjective, p)
    _count_if_exists(co, :EqualityConstraints)
    return get_equality_constraints(M, co.objective, p)
end
function get_equality_constraint(M::AbstractManifold, co::ManifoldCountObjective, p, i)
    _count_if_exists(co, :EqualityConstraint, i)
    return get_equality_constraint(M, co.objective, p, i)
end
function get_inequality_constraints(M::AbstractManifold, co::ManifoldCountObjective, p)
    _count_if_exists(co, :InequalityConstraints)
    return get_inequality_constraints(M, co.objective, p)
end
function get_inequality_constraint(M::AbstractManifold, co::ManifoldCountObjective, p, i)
    _count_if_exists(co, :InequalityConstraint, i)
    return get_inequality_constraint(M, co.objective, p, i)
end

function get_grad_equality_constraints(M::AbstractManifold, co::ManifoldCountObjective, p)
    _count_if_exists(co, :GradEqualityConstraints)
    return get_grad_equality_constraints(M, co.objective, p)
end
function get_grad_equality_constraints!(
    M::AbstractManifold, X, co::ManifoldCountObjective, p
)
    _count_if_exists(co, :GradEqualityConstraints)
    return get_grad_equality_constraints!(M, X, co.objective, p)
end
function get_grad_equality_constraint(M::AbstractManifold, co::ManifoldCountObjective, p, i)
    _count_if_exists(co, :GradEqualityConstraint, i)
    return get_grad_equality_constraint(M, co.objective, p, i)
end
function get_grad_equality_constraint!(
    M::AbstractManifold, X, co::ManifoldCountObjective, p, i
)
    _count_if_exists(co, :GradEqualityConstraint, i)
    return get_grad_equality_constraint!(M, X, co.objective, p, i)
end
function get_grad_inequality_constraints(M::AbstractManifold, co::ManifoldCountObjective, p)
    _count_if_exists(co, :GradInequalityConstraints)
    return get_grad_inequality_constraints(M, co.objective, p)
end
function get_grad_inequality_constraints!(
    M::AbstractManifold, X, co::ManifoldCountObjective, p
)
    _count_if_exists(co, :GradInequalityConstraints)
    return get_grad_inequality_constraints!(M, X, co.objective, p)
end
function get_grad_inequality_constraint(
    M::AbstractManifold, co::ManifoldCountObjective, p, i
)
    _count_if_exists(co, :GradInequalityConstraint, i)
    return get_grad_inequality_constraint(M, co.objective, p, i)
end
function get_grad_inequality_constraint!(
    M::AbstractManifold, X, co::ManifoldCountObjective, p, i
)
    _count_if_exists(co, :GradInequalityConstraint, i)
    return get_grad_inequality_constraint!(M, X, co.objective, p, i)
end

#
# proxes
function get_proximal_map(M::AbstractManifold, co::ManifoldCountObjective, λ, p)
    _count_if_exists(co, :ProximalMap)
    return get_proximal_map(M, co.objective, λ, p)
end
function get_proximal_map!(M::AbstractManifold, q, co::ManifoldCountObjective, λ, p)
    _count_if_exists(co, :ProximalMap)
    return get_proximal_map!(M, q, co.objective, λ, p)
end
function get_proximal_map(M::AbstractManifold, co::ManifoldCountObjective, λ, p, i)
    _count_if_exists(co, :ProximalMap, i)
    return get_proximal_map(M, co.objective, λ, p, i)
end
function get_proximal_map!(M::AbstractManifold, q, co::ManifoldCountObjective, λ, p, i)
    _count_if_exists(co, :ProximalMap, i)
    return get_proximal_map!(M, q, co.objective, λ, p, i)
end

#
# DC
function get_subtrahend_gradient(M::AbstractManifold, co::ManifoldCountObjective, p)
    _count_if_exists(co, :SubtrahendGradient)
    return get_subtrahend_gradient(M, co.objective, p)
end
function get_subtrahend_gradient!(M::AbstractManifold, X, co::ManifoldCountObjective, p)
    _count_if_exists(co, :SubtrahendGradient)
    return get_subtrahend_gradient!(M, X, co.objective, p)
end

#
# Subgradient
function get_subgradient(M::AbstractManifold, co::ManifoldCountObjective, p)
    _count_if_exists(co, :SubGradient)
    return get_subgradient(M, co.objective, p)
end
function get_subgradient!(M::AbstractManifold, X, co::ManifoldCountObjective, p)
    _count_if_exists(co, :SubGradient)
    return get_subgradient!(M, X, co.objective, p)
end

#
# Stochastic Gradient
function get_gradients(M::AbstractManifold, co::ManifoldCountObjective, p)
    _count_if_exists(co, :StochasticGradients)
    return get_gradients(M, co.objective, p)
end
function get_gradients!(M::AbstractManifold, X, co::ManifoldCountObjective, p)
    _count_if_exists(co, :StochasticGradients)
    return get_gradients!(M, X, co.objective, p)
end
function get_gradient(M::AbstractManifold, co::ManifoldCountObjective, p, i)
    _count_if_exists(co, :StochasticGradient, i)
    return get_gradient(M, co.objective, p, i)
end
function get_gradient!(M::AbstractManifold, X, co::ManifoldCountObjective, p, i)
    _count_if_exists(co, :StochasticGradient, i)
    return get_gradient!(M, X, co.objective, p, i)
end

function objective_count_factory(
    M::AbstractManifold, o::AbstractManifoldCostObjective, counts::Vector{<:Symbol}
)
    return ManifoldCountObjective(M, o, counts)
end

function status_summary(co::ManifoldCountObjective)
    longest_key_length = max(length.(["$c" for c in keys(co.counts)])...)
    s = "## Statistics on function calls\n"
    count_strings = [
        "  * :$(rpad("$(c[1])",longest_key_length)) : $(c[2])" for c in co.counts
    ]
    s2 = status_summary(co.objective)
    (length(s2) > 0) && (s2 = "\n$(s2)")
    return "$(s)$(join(count_strings,"\n"))$s2"
end

function show(io::IO, co::ManifoldCountObjective)
    return print(io, "$(status_summary(co))")
end
function show(
    io::IO, t::Tuple{<:ManifoldCountObjective,S}
) where {S<:AbstractManoptSolverState}
    return print(io, "$(t[2])\n\n$(t[1])")
end
