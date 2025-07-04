# Sorting and Related Functions

Julia has an extensive, flexible API for sorting and interacting with already-sorted arrays
of values. By default, Julia picks reasonable algorithms and sorts in ascending order:

```jldoctest
julia> sort([2,3,1])
3-element Vector{Int64}:
 1
 2
 3
```

You can sort in reverse order as well:

```jldoctest
julia> sort([2,3,1], rev=true)
3-element Vector{Int64}:
 3
 2
 1
```

`sort` constructs a sorted copy leaving its input unchanged. Use the "bang" version of
the sort function to mutate an existing array:

```jldoctest
julia> a = [2,3,1];

julia> sort!(a);

julia> a
3-element Vector{Int64}:
 1
 2
 3
```

Instead of directly sorting an array, you can compute a permutation of the array's
indices that puts the array into sorted order:

```jldoctest sort_example
julia> v = [0.297288, 0.382396, -0.597634, -0.0104452, -0.839027]
5-element Vector{Float64}:
  0.297288
  0.382396
 -0.597634
 -0.0104452
 -0.839027

julia> p = sortperm(v)
5-element Vector{Int64}:
 5
 3
 4
 1
 2

julia> v[p]
5-element Vector{Float64}:
 -0.839027
 -0.597634
 -0.0104452
  0.297288
  0.382396
```

Arrays can be sorted according to an arbitrary transformation of their values:

```jldoctest sort_example
julia> sort(v, by=abs)
5-element Vector{Float64}:
 -0.0104452
  0.297288
  0.382396
 -0.597634
 -0.839027
```

Or in reverse order by a transformation:

```jldoctest sort_example
julia> sort(v, by=abs, rev=true)
5-element Vector{Float64}:
 -0.839027
 -0.597634
  0.382396
  0.297288
 -0.0104452
```

If needed, the sorting algorithm can be chosen:

```jldoctest sort_example
julia> sort(v, alg=InsertionSort)
5-element Vector{Float64}:
 -0.839027
 -0.597634
 -0.0104452
  0.297288
  0.382396
```

All the sorting and order related functions rely on a "less than" relation defining a
[strict weak order](https://en.wikipedia.org/wiki/Weak_ordering#Strict_weak_orderings)
on the values to be manipulated. The `isless` function is invoked by default, but the
relation can be specified via the `lt` keyword, a function that takes two array elements
and returns `true` if and only if the first argument is "less than" the second. See
[`sort!`](@ref) and [Alternate Orderings](@ref) for more information.

## Sorting Functions

```@docs
Base.sort!
Base.sort
Base.sortperm
Base.InsertionSort
Base.MergeSort
Base.QuickSort
Base.PartialQuickSort
Base.Sort.sortperm!
Base.Sort.sortslices
```

## Order-Related Functions

```@docs
Base.issorted
Base.Sort.searchsorted
Base.Sort.searchsortedfirst
Base.Sort.searchsortedlast
Base.Sort.insorted
Base.Sort.partialsort!
Base.Sort.partialsort
Base.Sort.partialsortperm
Base.Sort.partialsortperm!
```

## Sorting Algorithms

There are currently four sorting algorithms publicly available in base Julia:

  * [`InsertionSort`](@ref)
  * [`QuickSort`](@ref)
  * [`PartialQuickSort(k)`](@ref)
  * [`MergeSort`](@ref)

By default, the `sort` family of functions uses stable sorting algorithms that are fast
on most inputs. The exact algorithm choice is an implementation detail to allow for
future performance improvements. Currently, a hybrid of `RadixSort`, `ScratchQuickSort`,
`InsertionSort`, and `CountingSort` is used based on input type, size, and composition.
Implementation details are subject to change but currently available in the extended help
of `??Base.DEFAULT_STABLE` and the docstrings of internal sorting algorithms listed there.

You can explicitly specify your preferred algorithm with the `alg` keyword
(e.g. `sort!(v, alg=PartialQuickSort(10:20))`) or reconfigure the default sorting algorithm
for custom types by adding a specialized method to the `Base.Sort.defalg` function.
For example, [InlineStrings.jl](https://github.com/JuliaStrings/InlineStrings.jl/blob/v1.3.2/src/InlineStrings.jl#L903)
defines the following method:
```julia
Base.Sort.defalg(::AbstractArray{<:Union{SmallInlineStrings, Missing}}) = InlineStringSort
```

!!! compat "Julia 1.9"
    The default sorting algorithm (returned by `Base.Sort.defalg`) is guaranteed to
    be stable since Julia 1.9. Previous versions had unstable edge cases when
    sorting numeric arrays.

## Alternate Orderings

By default, `sort`, `searchsorted`, and related functions use [`isless`](@ref) to compare
two elements in order to determine which should come first. The
[`Base.Order.Ordering`](@ref) abstract type provides a mechanism for defining alternate
orderings on the same set of elements: when calling a sorting function like
`sort!`, an instance of `Ordering` can be provided with the keyword argument `order`.

Instances of `Ordering` define an order through the [`Base.Order.lt`](@ref)
function, which works as a generalization of `isless`.
This function's behavior on custom `Ordering`s must satisfy all the conditions of a
[strict weak order](https://en.wikipedia.org/wiki/Weak_ordering#Strict_weak_orderings).
See [`sort!`](@ref) for details and examples of valid and invalid `lt` functions.

```@docs
Base.Order.Ordering
Base.Order.lt
Base.Order.ord
Base.Order.Forward
Base.Order.ReverseOrdering
Base.Order.Reverse
Base.Order.By
Base.Order.Lt
Base.Order.Perm
```
