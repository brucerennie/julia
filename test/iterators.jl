# This file is a part of Julia. License is MIT: https://julialang.org/license

using Base.Iterators
using Random
using Base: IdentityUnitRange
using Dates: Date, Day

@test (@inferred Base.IteratorSize(Any)) isa Base.SizeUnknown

# zip and filter iterators
# issue #4718
@test collect(Iterators.filter(x->x[1], zip([true, false, true, false],"abcd"))) == [(true,'a'),(true,'c')]

# issue #45085
@test_throws ArgumentError Iterators.reverse(zip("abc", "abcd"))
@test_throws ArgumentError Iterators.reverse(zip("abc", Iterators.cycle("ab")))

let z = zip(1:2)
    @test (@inferred size(z)) == (2,)
    @test collect(z) == [(1,), (2,)]
    # Issue #13979
    @test (@inferred eltype(z)) == Tuple{Int}
end

for z in (zip(1:2, 3:4), zip(1:2, 3:5))
    @test collect(z) == [(1,3), (2,4)]
    @test (@inferred eltype(z)) == Tuple{Int,Int}
    @test (@inferred size(z)) == (2,)
    @test (@inferred axes(z)) == (Base.OneTo(2),)
    @test (@inferred length(z)) == 2
end

let z = zip(1:2, Iterators.countfrom(3))
    @test collect(z) == [(1,3), (2,4)]
    @test (@inferred eltype(z)) == Tuple{Int,Int}
    @test_throws MethodError size(z) # by convention, the zip of a finite and
                         # an infinite iterator has only `length`
    @test_throws MethodError axes(z)
    @test (@inferred length(z)) == 2
end

let z = zip([i*j for i in 1:3, j in -1:2:1], 1:6)
    @test collect(z) == [(-1, 1)
                         (-2, 2)
                         (-3, 3)
                         (1, 4)
                         (2, 5)
                         (3, 6) ]
    @test (@inferred eltype(z)) == Tuple{Int,Int}
    @test_throws DimensionMismatch size(z)
    @test_throws DimensionMismatch axes(z)
    @test (@inferred length(z)) == 6
end

let z = zip([i*j for i in 1:3, j in -1:2:1], [i*j for i in 1:3, j in -1:2:1])
    @test collect(z) == [(-1, -1) (1, 1)
                        (-2, -2) (2, 2)
                        (-3, -3) (3, 3)]
    @test (@inferred eltype(z)) == Tuple{Int,Int}
    @test (@inferred size(z)) == (3, 2)
    @test (@inferred axes(z)) == (Base.OneTo(3), Base.OneTo(2))
    @test (@inferred length(z)) == 6
end

let z = zip(1:2, 3:4, 5:6)
    @test (@inferred size(z)) == (2,)
    @test collect(z) == [(1,3,5), (2,4,6)]
    @test (@inferred eltype(z)) == Tuple{Int,Int,Int}
end

@test (@inferred eltype(Iterators.filter(isodd, 1:5))) == Int

# typed `collect`
@test collect(Float64, Iterators.filter(isodd, [1,2,3,4]))[1] === 1.0

# check direct EachLine constructor
let b = IOBuffer("foo\n")
    @test collect(Base.EachLine(b)) == ["foo"]
    seek(b, 0)
    @test collect(Base.EachLine(b, keep=true)) == ["foo\n"]
    seek(b, 0)
    @test collect(Base.EachLine(b, ondone=()->0)) == ["foo"]
    seek(b, 0)
    @test collect(Base.EachLine(b, keep=true, ondone=()->0)) == ["foo\n"]
end

# enumerate (issue #6284)
let b = IOBuffer("1\n2\n3\n"), a = []
    for (i,x) in enumerate(eachline(b))
        push!(a, (i,x))
    end
    @test a == [(1,"1"),(2,"2"),(3,"3")]
end

# zip eachline (issue #7369)
let zeb = IOBuffer("1\n2\n3\n4\n5\n"),
    letters = ['a', 'b', 'c', 'd', 'e'],
    res     = []
    for (number, letter) in zip(eachline(zeb), letters)
        push!(res, (parse(Int,strip(number)), letter))
    end
    @test res == [(1, 'a'), (2, 'b'), (3, 'c'), (4, 'd'), (5, 'e')]
end

@test (@inferred length(zip(cycle(1:3), 1:7))) == 7
@test (@inferred length(zip(cycle(1:3), 1:7, cycle(1:3)))) == 7
@test (@inferred length(zip(1:3,product(1:7,cycle(1:3))))) == 3
@test (@inferred length(zip(1:3,product(1:7,cycle(1:3)),8))) == 1
@test_throws ArgumentError length(zip()) # length of zip of empty tuple

# map
# ----
@testset "Iterators.map" begin
    @test collect(Iterators.map(string, 1:3)::Base.Generator) == map(string, 1:3)
    @test collect(Iterators.map(tuple, 1:3, 4:6)::Base.Generator) == map(tuple, 1:3, 4:6)
end

# rest
# ----
let s = "hello"
    _, st = iterate(s)
    c = collect(rest(s, st))
    @test c == ['e','l','l','o']
    @test c isa Vector{Char}
    @test rest(s, st) == rest(rest(s,4),st)
end

@test_throws MethodError collect(rest(countfrom(1), 5))

# countfrom
# ---------
let i = 0, k = 1, l = 0
    for j = countfrom(0, 2)
        @test j == i*2
        i += 1
        i <= 10 || break
    end
    for j = countfrom()
        @test j == k
        k += 1
        k <= 10 || break
    end
    # test that `start` promotes to `typeof(start+step)`
    for j = countfrom(Int[0, 0], Float64[1.0, 2.0])
        @test j isa Vector{Float64}
        @test j == l*[1, 2]
        l += 1
        l <= 10 || break
    end
    # test with `start` and `step` having different types
    @test collect(take(countfrom(Date(2020,12,25), Day(1)), 12)) == range(Date(2020,12,25), step=Day(1), length=12)
end

# take
# ----
let t = take(0:2:8, 10), i = 0
    @test length(collect(t)) == 5 == @inferred length(t)

    for j = t
        @test j == i*2
        i += 1
    end
    @test i == 5
end

let i = 0
    for j = take(0:2:100, 10)
        @test j == i*2
        i += 1
    end
    @test i == 10
end

@test @inferred isempty(take(0:2:8, 0))
@test_throws ArgumentError take(0:2:8, -1)
@test (@inferred length(take(1:3,typemax(Int)))) == 3
@test (@inferred length(take(countfrom(1),3))) == 3
@test (@inferred length(take(1:6,3))) == 3

# drop
# ----
let i = 0
    for j = drop(0:2:10, 2)
        @test j == (i+2)*2
        i += 1
    end
    @test i == 4
end

@test @inferred isempty(drop(0:2:10, 100))
@test @inferred isempty(collect(drop(0:2:10, 100)))
@test_throws ArgumentError drop(0:2:8, -1)
@test (@inferred length(drop(1:3,typemax(Int)))) == 0
@test (@inferred length(drop(UInt(1):2, 3))) == 0
@test (@inferred length(drop(StepRangeLen(1, 1, UInt(2)), 3))) == 0
@test (@inferred Base.IteratorSize(drop(countfrom(1),3))) == Base.IsInfinite()
@test_throws MethodError length(drop(countfrom(1), 3))
@test (@inferred Base.IteratorSize(Iterators.drop(Iterators.filter(i -> i>0, 1:10), 2))) == Base.SizeUnknown()

let x = Iterators.drop(Iterators.Stateful("abc"), 2)
    @test !Base.isdone(x, nothing)
    iterate(x)
    @test Base.isdone(x, nothing)
end

# double take
# and take/drop canonicalization
# -----------
for xs in Any["abc", [1, 2, 3]]
    @test take(take(xs, 2), 3) === take(xs, 2)
    @test take(take(xs, 4), 2) === take(xs, 2)
    @test drop(drop(xs, 1), 1) === drop(xs, 2)
    @test take(drop(xs, 1), 1) === drop(take(xs, 2), 1)
    @test take(drop(xs, 3), 0) === drop(take(xs, 2), 3)
    @test @inferred isempty(drop(drop(xs, 2), 2))
    @test drop(take(drop(xs, 1), 2), 1) === take(drop(xs, 2), 1)
    @test take(drop(take(xs, 3), 1), 1) === take(drop(xs, 1), 1)
end

# takewhile
# --------
@testset begin
    @test collect(takewhile(<(4),1:10)) == [1,2,3]
    @test collect(takewhile(<(4),Iterators.countfrom(1))) == [1,2,3]
    @test collect(takewhile(<(4),5:10)) == []
    @test collect(takewhile(Returns(true),5:10)) == 5:10
    @test collect(takewhile(isodd,[1,1,2,3])) == [1,1]
    @test collect(takewhile(<(2), takewhile(<(3), [1,1,2,3]))) == [1,1]
    @test (@inferred Base.IteratorEltype(typeof(takewhile(<(4),Iterators.map(identity, 1:10))))) isa Base.EltypeUnknown
end

# dropwhile
# --------
@testset begin
    @test collect(dropwhile(<(4), 1:10)) == 4:10
    @test collect(dropwhile(<(4), 1:10)) isa Vector{Int}
    @test @inferred isempty(dropwhile(<(4), []))
    @test collect(dropwhile(Returns(false),1:3)) == 1:3
    @test @inferred isempty(dropwhile(Returns(true), 1:3))
    @test collect(dropwhile(isodd,[1,1,2,3])) == [2,3]
    @test collect(dropwhile(iseven,dropwhile(isodd,[1,1,2,3]))) == [3]
    @test (@inferred Base.IteratorEltype(typeof(dropwhile(<(4),Iterators.map(identity, 1:10))))) isa Base.EltypeUnknown
end

# cycle
# -----
let i = 0
    for j = cycle(0:3)
        @test j == i % 4
        i += 1
        i <= 10 || break
    end
    @test Base.isdone(cycle(0:3)) === Base.isdone(0:3) === missing
    @test !Base.isdone(cycle(0:3), 1)
end

@testset "cycle(iter, n)"  begin
    @test collect(cycle(0:3, 2)) == [0, 1, 2, 3, 0, 1, 2, 3]
    @test collect(cycle(Iterators.filter(iseven, 1:4), 2)) == [2, 4, 2, 4]
    @test collect(take(cycle(countfrom(11), 3), 4)) == 11:14

    @test (@inferred isempty(cycle(1:0))) == (@inferred isempty(cycle(1:0, 3))) == true
    @test @inferred isempty(cycle(1:5, 0))
    @test @inferred isempty(cycle(Iterators.filter(iseven, 1:4), 0))

    @test (@inferred eltype(cycle(0:3, 2))) === Int
    @test (@inferred Base.IteratorEltype(cycle(0:3, 2))) == Base.HasEltype()

    Base.haslength(cycle(0:3, 2)) == false  # but not sure we should test these
    (@inferred Base.IteratorSize(cycle(0:3, 2))) == Base.SizeUnknown()
end

# repeated
# --------
let i = 0
    for j = repeated(1, 10)
        @test j == 1
        i += 1
    end
    @test i == 10
end
let i = 0
    for j = repeated(1)
        @test j == 1
        i += 1
        i <= 10 || break
    end
end
@test (@inferred eltype(repeated(0)))    == Int
@test (@inferred eltype(repeated(0, 5))) == Int
@test (@inferred Base.IteratorSize(repeated(0)))      == Base.IsInfinite()
@test (@inferred Base.IteratorSize(repeated(0, 5)))   == Base.HasLength()
@test (@inferred Base.IteratorEltype(repeated(0)))    == Base.HasEltype()
@test (@inferred Base.IteratorEltype(repeated(0, 5))) == Base.HasEltype()
@test (@inferred Base.IteratorSize(zip(repeated(0), repeated(0)))) == Base.IsInfinite()

# product
# -------

# empty?
for itr in [product(1:0),
            product(1:2, 1:0),
            product(1:0, 1:2),
            product(1:0, 1:1, 1:2),
            product(1:1, 1:0, 1:2),
            product(1:1, 1:2 ,1:0)]
    @test @inferred isempty(itr)
    @test @inferred isempty(collect(itr))
end

# collect a product - first iterators runs faster
@test collect(product(1:2))           == [(i,)      for i=1:2]
@test collect(product(1:2, 3:4))      == [(i, j)    for i=1:2, j=3:4]
@test collect(product(1:2, 3:4, 5:6)) == [(i, j, k) for i=1:2, j=3:4, k=5:6]

# iteration order
let expected = [(1,3,5), (2,3,5), (1,4,5), (2,4,5), (1,3,6), (2,3,6), (1,4,6), (2,4,6)]
    actual = product(1:2, 3:4, 5:6)
    for (exp, act) in zip(expected, actual)
        @test exp == act
    end
end

# collect multidimensional array
let (a, b) = (1:3, [4 6;
                    5 7])
    p = product(a, b)
    @test (@inferred size(p))    == (3, 2, 2)
    @test (@inferred length(p))  == 12
    @test (@inferred ndims(p))   == 3
    @test (@inferred eltype(p))  == NTuple{2, Int}
    cp = collect(p)
    for i = 1:3
        @test cp[i, :, :] == [(i, 4) (i, 6);
                              (i, 5) (i, 7)]
    end
end

# collect stateful iterator
let itr
    itr = Iterators.Stateful(Iterators.map(identity, 1:5))
    @test collect(itr) == 1:5
    @test collect(itr) == Int[] # Stateful do not preserve shape
    itr = (i+1 for i in Base.Stateful([1, 2, 3]))
    @test collect(itr) == [2, 3, 4]
    @test collect(itr) == Int[] # Stateful do not preserve shape
    itr = (i-1 for i in Base.Stateful(zeros(Int, 0, 0)))
    @test collect(itr) == Int[] # Stateful do not preserve shape
    itr = Iterators.Stateful(Iterators.Stateful(1:1))
    @test collect(itr) == [1]
end

# with 1D inputs
let a = 1:2,
    b = 1.0:10.0,
    c = Int32(1):Int32(0)

    # length
    @test (@inferred length(product()))        == 1
    @test (@inferred length(product(a)))       == 2
    @test (@inferred length(product(a, b)))    == 20
    @test (@inferred length(product(a, b, c))) == 0

    # size
    @test (@inferred size(product()))          == tuple()
    @test (@inferred size(product(a)))         == (2,)
    @test (@inferred size(product(a, b)))      == (2, 10)
    @test (@inferred size(product(a, b, c)))   == (2, 10, 0)

    # eltype
    @test (@inferred eltype(product()))        == Tuple{}
    @test (@inferred eltype(product(a)))       == Tuple{Int}
    @test (@inferred eltype(product(a, b)))    == Tuple{Int, Float64}
    @test (@inferred eltype(product(a, b, c))) == Tuple{Int, Float64, Int32}

    # ndims
    @test (@inferred ndims(product()))         == 0
    @test (@inferred ndims(product(a)))        == 1
    @test (@inferred ndims(product(a, b)))     == 2
    @test (@inferred ndims(product(a, b, c)))  == 3
end

# with multidimensional inputs
let a = randn(4, 4),
    b = randn(3, 3, 3),
    c = randn(2, 2, 2, 2)

    args = Any[(a,),
               (a, a),
               (a, b),
               (a, a, a),
               (a, b, c)]
    sizes = Any[(4, 4),
                (4, 4, 4, 4),
                (4, 4, 3, 3, 3),
                (4, 4, 4, 4, 4, 4),
                (4, 4, 3, 3, 3, 2, 2, 2, 2)]
    for (method, fun) in zip([size, ndims, length], [x->x, length, prod])
        for i in 1:length(args)
            @test (@inferred method(product(args[i]...))) == method(collect(product(args[i]...))) == fun(sizes[i])
        end
    end
end

# more tests on product with iterators of various type
let iters = (1:2,
             rand(2, 2, 2),
             take(1:4, 2),
             product(1:2, 1:3),
             product(rand(2, 2), rand(1, 1, 1)),
             repeated([1, -1], 2)  # 28497
             )
    for method in [size, length, ndims, eltype]
        for i = 1:length(iters)
            args = (iters[i],)
            @test (@inferred method(product(args...))) == method(collect(product(args...)))
            for j = 1:length(iters)
                args = iters[i], iters[j]
                @test method(product(args...)) == method(collect(product(args...)))
                for k = 1:length(iters)
                    args = iters[i], iters[j], iters[k]
                    @test method(product(args...)) == method(collect(product(args...)))
                end
            end
        end
    end
end

# product of finite length and infinite length iterators
let a = 1:2,
    b = countfrom(1),
    ab = product(a, b),
    ba = product(b, a),
    abexp = [(1, 1), (2, 1), (1, 2), (2, 2), (1, 3), (2, 3)],
    baexp = [(1, 1), (2, 1), (3, 1), (4, 1), (5, 1), (6, 1)]
    for (expected, actual) in zip([abexp, baexp], [ab, ba])
        for (i, el) in enumerate(actual)
            @test el == expected[i]
            i == length(expected) && break
        end
        @test_throws ArgumentError length(actual)
        @test_throws ArgumentError size(actual)
        @test_throws ArgumentError ndims(actual)
    end

    # size infinite or unknown raises an error
    for itr in Any[countfrom(1), Iterators.filter(Returns(0), 1:10)]
        @test_throws ArgumentError length(product(itr))
        @test_throws ArgumentError   size(product(itr))
        @test_throws ArgumentError  ndims(product(itr))
    end

    @test_throws OverflowError length(product(1:typemax(Int), 1:typemax(Int)))
end

# IteratorSize trait business
let f1 = Iterators.filter(i->i>0, 1:10)
    @test (@inferred Base.IteratorSize(product(f1)))               == Base.SizeUnknown()
    @test (@inferred Base.IteratorSize(product(1:2, f1)))          == Base.SizeUnknown()
    @test (@inferred Base.IteratorSize(product(f1, 1:2)))          == Base.SizeUnknown()
    @test (@inferred Base.IteratorSize(product(f1, f1)))           == Base.SizeUnknown()
    @test (@inferred Base.IteratorSize(product(f1, countfrom(1)))) == Base.IsInfinite()
    @test (@inferred Base.IteratorSize(product(countfrom(1), f1))) == Base.IsInfinite()
end
@test (@inferred Base.IteratorSize(product(1:2, countfrom(1))))          == Base.IsInfinite()
@test (@inferred Base.IteratorSize(product(countfrom(2), countfrom(1)))) == Base.IsInfinite()
@test (@inferred Base.IteratorSize(product(countfrom(1), 1:2)))          == Base.IsInfinite()
@test (@inferred Base.IteratorSize(product(1:2)))                        == Base.HasShape{1}()
@test (@inferred Base.IteratorSize(product(1:2, 1:2)))                   == Base.HasShape{2}()
@test (@inferred Base.IteratorSize(product(take(1:2, 1), take(1:2, 1)))) == Base.HasShape{2}()
@test (@inferred Base.IteratorSize(product(take(1:2, 2))))               == Base.HasShape{1}()
@test (@inferred Base.IteratorSize(product([1 2; 3 4])))                 == Base.HasShape{2}()
@test (@inferred Base.IteratorSize(product((1,2,3,4), (5, 6, 7, 8))))    == Base.HasShape{2}()  # product of ::HasLength and ::HasLength
@test (@inferred Base.IteratorSize(product(1:2, 3:5, 5:6)))              == Base.HasShape{3}()  # product of 3 iterators
@test (@inferred Base.IteratorSize(product([1 2; 3 4], 1:4)))            == Base.HasShape{3}()  # product of ::HasShape{2} with ::HasShape{1}
@test (@inferred Base.IteratorSize(product([1 2; 3 4], (1,2))))          == Base.HasShape{3}()  # product of ::HasShape{2} with ::HasLength

# IteratorEltype trait business
let f1 = Iterators.filter(i->i>0, 1:10)
    @test (@inferred Base.IteratorEltype(product(f1)))               == Base.HasEltype() # FIXME? eltype(f1) is Any
    @test (@inferred Base.IteratorEltype(product(1:2, f1)))          == Base.HasEltype() # FIXME? eltype(f1) is Any
    @test (@inferred Base.IteratorEltype(product(f1, 1:2)))          == Base.HasEltype() # FIXME? eltype(f1) is Any
    @test (@inferred Base.IteratorEltype(product(f1, f1)))           == Base.HasEltype() # FIXME? eltype(f1) is Any
    @test (@inferred Base.IteratorEltype(product(f1, countfrom(1)))) == Base.HasEltype() # FIXME? eltype(f1) is Any
    @test (@inferred Base.IteratorEltype(product(countfrom(1), f1))) == Base.HasEltype() # FIXME? eltype(f1) is Any
end
@test (@inferred Base.IteratorEltype(product(1:2, countfrom(1))))          == Base.HasEltype()
@test (@inferred Base.IteratorEltype(product(countfrom(1), 1:2)))          == Base.HasEltype()
@test (@inferred Base.IteratorEltype(product(1:2)))                        == Base.HasEltype()
@test (@inferred Base.IteratorEltype(product(1:2, 1:2)))                   == Base.HasEltype()
@test (@inferred Base.IteratorEltype(product(take(1:2, 1), take(1:2, 1)))) == Base.HasEltype()
@test (@inferred Base.IteratorEltype(product(take(1:2, 2))))               == Base.HasEltype()
@test (@inferred Base.IteratorEltype(product([1 2; 3 4])))                 == Base.HasEltype()
@test (@inferred Base.IteratorEltype(product()))                           == Base.HasEltype()

@test collect(product(1:2,3:4)) == [(1,3) (1,4); (2,3) (2,4)]
@test @inferred isempty(collect(product(1:0,1:2)))
@test (@inferred length(product(1:2,1:10,4:6))) == 60
@test (@inferred Base.IteratorSize(product(1:2, countfrom(1)))) == Base.IsInfinite()

@test Base.iterate(product()) == ((), true)
@test Base.iterate(product(), 1) === nothing

# intersection
@test intersect(product(1:3, 4:6), product(2:4, 3:5)) == Iterators.ProductIterator((2:3, 4:5))
@test intersect(product(1:3, [4 5 ; 6 7]), product(2:4, [7 6 ; 5 4])).iterators == (2:3, [4, 6, 5, 7])

# flatten
# -------
@test collect(flatten(Any[1:2, 4:5])) == Any[1,2,4,5]
@test collect(flatten(Any[flatten(Any[1:2, 6:5]), flatten(Any[10:7, 10:9])])) == Any[1,2]
@test collect(flatten(Any[flatten(Any[1:2, 4:5]), flatten(Any[6:7, 8:9])])) == Any[1,2,4,5,6,7,8,9]
@test collect(flatten(Any[flatten(Any[1:2, 6:5]), flatten(Any[6:7, 8:9])])) == Any[1,2,6,7,8,9]
@test collect(flatten(Any[2:1])) == Any[]
@test (@inferred eltype(flatten(UnitRange{Int8}[1:2, 3:4]))) == Int8
@test (@inferred eltype(flatten(([1, 2], [3.0, 4.0])))) == Real
@test (@inferred eltype(flatten((a = [1, 2], b = Int8[3, 4])))) == Signed
@test (@inferred eltype(flatten((Int[], Nothing[], Int[])))) == Union{Int, Nothing}
@test (@inferred eltype(flatten((String[],)))) == String
@test (@inferred eltype(flatten((Int[], UInt[], Int8[],)))) == Integer
@test (@inferred eltype(flatten((; a = Int[], b = Nothing[], c = Int[])))) == Union{Int, Nothing}
@test (@inferred eltype(flatten((; a = String[],)))) == String
@test (@inferred eltype(flatten((; a = Int[], b = UInt[], c = Int8[],)))) == Integer
@test (@inferred eltype(flatten(()))) == Union{}
@test (@inferred eltype(flatten((;)))) == Union{}
@test (@inferred length(flatten(zip(1:3, 4:6)))) == 6
@test (@inferred length(flatten(1:6))) == 6
@test collect(flatten(Any[])) == Any[]
@test collect(flatten(())) == Union{}[]
@test_throws ArgumentError length(flatten(NTuple[(1,), ()])) # #16680
@test_throws ArgumentError length(flatten([[1], [1]]))

@testset "IteratorSize trait for flatten" begin
    @test (@inferred Base.IteratorSize(Base.Flatten((i for i=1:2) for j=1:1))) == Base.SizeUnknown()
    @test (@inferred Base.IteratorSize(Base.Flatten((1,2)))) == Base.HasLength()
    @test (@inferred Base.IteratorSize(Base.Flatten(1:2:4))) == Base.HasLength()
end

@test (@inferred Base.IteratorEltype(Base.Flatten((i for i=1:2) for j=1:1))) == Base.EltypeUnknown()
# see #29112, #29464, #29548
@test Base.return_types(Base.IteratorEltype, Tuple{Array}) == [Base.HasEltype]

# flatmap
# -------
@test flatmap(1:3) do j flatmap(1:3) do k
    j!=k ? ((j,k),) : ()
end end |> collect == [(j,k) for j in 1:3 for k in 1:3 if j!=k]
# Test inspired by the monad associativity law
fmf(x) = x<0 ? () : (x^2,)
fmg(x) = x<1 ? () : (x/2,)
fmdata = -2:0.75:2
fmv1 = flatmap(tuple.(fmdata)) do h
    flatmap(h) do x
        gx = fmg(x)
        flatmap(gx) do x
            fmf(x)
        end
    end
end
fmv2 = flatmap(tuple.(fmdata)) do h
    gh = flatmap(h) do x fmg(x) end
    flatmap(gh) do x fmf(x) end
end
@test all(fmv1 .== fmv2)

# partition(c, n)
let v = collect(partition([1,2,3,4,5], 1))
    @test all(i->v[i][1] == i, v)
end

let v1 = collect(partition([1,2,3,4,5], 2)),
    v2 = collect(partition(flatten([[1,2],[3,4],5]), 2)) # collecting partition with SizeUnknown
    @test v1[1] == v2[1] == [1,2]
    @test v1[2] == v2[2] == [3,4]
    @test v1[3] == v2[3] == [5]
end

let v = collect(partition([1,2,3,4,5], 2))
    @test v[1] == [1,2]
    @test v[2] == [3,4]
    @test v[3] == [5]
end

let v = collect(partition(enumerate([1,2,3,4,5]), 3))
    @test v[1] == [(1,1),(2,2),(3,3)]
    @test v[2] == [(4,4),(5,5)]
end

for n in [5,6]
    @test collect(partition([1,2,3,4,5], n))[1] == [1,2,3,4,5]
    @test collect(partition(enumerate([1,2,3,4,5]), n))[1] ==
          [(1,1),(2,2),(3,3),(4,4),(5,5)]
end

function iterate_length(iter)
    n=0
    for i in iter
        n += 1
    end
    return n
end
function simd_iterate_length(iter)
    n=0
    @simd for i in iter
        n += 1
    end
    return n
end
function simd_trip_count(iter)
    return sum(Base.SimdLoop.simd_inner_length(iter, i) for i in Base.SimdLoop.simd_outer_range(iter))
end
function iterate_elements(iter)
    vals = Vector{eltype(iter)}(undef, length(iter))
    i = 1
    for v in iter
        @inbounds vals[i] = v
        i += 1
    end
    return vals
end
function simd_iterate_elements(iter)
    vals = Vector{eltype(iter)}(undef, length(iter))
    i = 1
    @simd for v in iter
        @inbounds vals[i] = v
        i += 1
    end
    return vals
end
function index_elements(iter)
    vals = Vector{eltype(iter)}(undef, length(iter))
    i = 1
    for j in eachindex(iter)
        @inbounds vals[i] = iter[j]
        i += 1
    end
    return vals
end

@testset "CartesianPartition optimizations" for dims in ((1,), (64,), (101,),
                                                         (1,1), (8,8), (11, 13),
                                                         (1,1,1), (8, 4, 2), (11, 13, 17)),
                                                part in (1, 7, 8, 11, 63, 64, 65, 142, 143, 144)
    for fun in (i -> 1:i, i -> 1:2:2i, i -> Base.IdentityUnitRange(-i:i))
        iter = CartesianIndices(map(fun, dims))
        P = partition(iter, part)
        for I in P
            @test length(I) == iterate_length(I) == simd_iterate_length(I) == simd_trip_count(I)
            @test collect(I) == iterate_elements(I) == simd_iterate_elements(I) == index_elements(I)
        end
        @test all(Base.splat(==), zip(Iterators.flatten(map(collect, P)), iter))
    end
end
@testset "empty/invalid partitions" begin
    @test_throws ArgumentError partition(1:10, 0)
    @test_throws ArgumentError partition(1:10, -1)
    @test_throws ArgumentError partition(1:0, 0)
    @test_throws ArgumentError partition(1:0, -1)
    @test @inferred isempty(partition(1:0, 1))
    @test @inferred isempty(partition(CartesianIndices((0,1)), 1))
end
@testset "exact partition eltypes" for a in (Base.OneTo(24), 1:24, 1:1:24, LinRange(1,10,24), .1:.1:2.4, Vector(1:24),
                                             CartesianIndices((4, 6)), Dict((1:24) .=> (1:24)))
    P = partition(a, 2)
    @test (@inferred eltype(P)) === typeof(first(P))
    @test (@inferred Iterators.IteratorEltype(P)) == Iterators.HasEltype()
    if a isa AbstractArray
        P = partition(vec(a), 2)
        @test (@inferred eltype(P)) === typeof(first(P))
        P = partition(reshape(a, 6, 4), 2)
        @test (@inferred eltype(P)) === typeof(first(P))
        P = partition(reshape(a, 2, 3, 4), 2)
        @test (@inferred eltype(P)) === typeof(first(P))
    end
end

@test join(map(x->string(x...), partition("Hello World!", 5)), "|") ==
      "Hello| Worl|d!"

let s = "Monkey 🙈🙊🙊"
    tf = (n)->join(map(x->string(x...), partition(s,n)), "|")
    @test tf(10) == s
    @test tf(9) == "Monkey 🙈🙊|🙊"
    @test tf(8) == "Monkey 🙈|🙊🙊"
    @test tf(7) == "Monkey |🙈🙊🙊"
    @test tf(6) == "Monkey| 🙈🙊🙊"
    @test tf(5) == "Monke|y 🙈🙊🙊"
    @test tf(4) == "Monk|ey 🙈|🙊🙊"
    @test tf(3) == "Mon|key| 🙈🙊|🙊"
    @test tf(2) == "Mo|nk|ey| 🙈|🙊🙊"
    @test tf(1) == "M|o|n|k|e|y| |🙈|🙊|🙊"
end

@test (@inferred Base.IteratorEltype(partition([1,2,3,4], 2))) == Base.HasEltype()
@test (@inferred Base.IteratorEltype(partition((2x for x in 1:3), 2))) == Base.EltypeUnknown()

# take and friends with arbitrary integers (#19214)
for T in (UInt8, UInt16, UInt32, UInt64, UInt128, Int8, Int16, Int128, BigInt)
    @test (@inferred length(take(1:6, T(3)))) == 3
    @test (@inferred length(drop(1:6, T(3)))) == 3
    @test (@inferred length(repeated(1, T(5)))) == 5
    @test collect(partition(1:5, T(5)))[1] == 1:5
end

@testset "collect finite iterators issue #12009" begin
    @test (@inferred eltype(collect(enumerate(Iterators.Filter(x -> x>0, randn(10)))))) == Tuple{Int, Float64}
end

@testset "product iterator infinite loop" begin
    @test collect(product(1:1, (1, "2"))) == [(1, 1) (1, "2")]
end

@testset "filter empty iterable #16704" begin
    arr = filter(Returns(true), 1:0)
    @test (@inferred length(arr)) == 0
    @test (@inferred eltype(arr)) == Int
end

@testset "Pairs type" begin
    for A in ([4.0 5.0 6.0],
              [],
              (4.0, 5.0, 6.0),
              (a=4.0, b=5.0, c=6.0),
              (),
              NamedTuple(),
              (a=1.1, b=2.0),
             )
        d = pairs(A)
        @test d === pairs(d)
        @test (@inferred isempty(d)) == isempty(A)
        @test (@inferred length(d)) == length(A)
        @test keys(d) == keys(A)
        @test values(d) == A
        @test (@inferred Base.IteratorSize(d)) == Base.IteratorSize(A)
        @test (@inferred Base.IteratorEltype(d)) == Base.HasEltype()
        @test (@inferred Base.IteratorSize(pairs([1 2;3 4]))) isa Base.HasShape{2}
        @test (@inferred isempty(d)) || haskey(d, first(keys(d)))
        @test collect(v for (k, v) in d) == collect(A)
        if A isa NamedTuple
            K = Symbol
            V = isempty(d) ? Union{} : Float64
            @test (@inferred isempty(d)) || haskey(d, :a)
            @test !haskey(d, :abc)
            @test !haskey(d, 1)
            @test get(A, :key) do; 99; end == 99
        elseif A isa Tuple
            K = Int
            V = isempty(d) ? Union{} : Float64
        else
            K = A isa AbstractVector ? Int : CartesianIndex{2}
            V = isempty(d) ? Any : Float64
            @test get(A, 4, "not found") === "not found"
            if !isempty(A)
                @test get(A, 2, "not found") === 5.0
                @test getindex(d, 3) === 6.0
                @test setindex!(d, 9, 3) === d
                @test A[3] === 9.0
            end
        end
        @test keytype(d) == K
        @test valtype(d) == V
        @test (@inferred eltype(d)) == Pair{K, V}
    end

    let io = IOBuffer()
        Base.showarg(io, pairs([1,2,3]), true)
        @test String(take!(io)) == "pairs(::Vector{$Int})"
        Base.showarg(io, pairs((a=1, b=2)), true)
        @test String(take!(io)) == "pairs(::NamedTuple)"
        Base.showarg(io, pairs(IndexLinear(), zeros(3,3)), true)
        @test String(take!(io)) == "pairs(IndexLinear(), ::Matrix{Float64})"
        Base.showarg(io, pairs(IndexCartesian(), zeros(3)), true)
        @test String(take!(io)) == "pairs(IndexCartesian(), ::Vector{Float64})"
    end
end

@testset "reverse iterators" begin
    squash(x::Number) = x
    squash(A) = reshape(A, length(A))
    Z = Array{Int,0}(undef); Z[] = 17 # zero-dimensional test case
    for itr in (2:10, "∀ϵ>0", 1:0, "", (2,3,5,7,11), [2,3,5,7,11], rand(5,6), Z, 3, true, 'x', 4=>5,
                eachindex("∀ϵ>0"), view(Z), view(rand(5,6),2:4,2:6), (x^2 for x in 1:10),
                Iterators.Filter(isodd, 1:10), flatten((1:10, 50:60)), enumerate("foo"),
                pairs(50:60), zip(1:10,21:30,51:60), product(1:3, 10:12), repeated(3.14159, 5),
                (a=2, b=3, c=5, d=7, e=11))
        arr = reverse(squash(collect(itr)))
        itr = Iterators.reverse(itr)
        @test squash(collect(itr)) == arr
        if !isempty(arr)
            @test first(itr) == first(arr)
            @test last(itr) == last(arr)
        end
    end
    @test collect(take(Iterators.reverse(cycle(1:3)), 7)) == collect(take(cycle(3:-1:1), 7))
    let r = repeated(3.14159)
        @test Iterators.reverse(r) === r
        @test last(r) === 3.14159
    end
    for t in [(1,), (2, 3, 5, 7, 11), (a=1,), (a=2, b=3, c=5, d=7, e=11)]
        @test Iterators.reverse(Iterators.reverse(t)) === t
        @test first(Iterators.reverse(t)) === last(t)
        @test last(Iterators.reverse(t)) === first(t)
        @test collect(Iterators.reverse(t)) == reverse(collect(t))
    end
end

@testset "Iterators.Stateful" begin
    let a = @inferred(Iterators.Stateful("abcdef"))
        @test !(@inferred isempty(a))
        @test popfirst!(a) == 'a'
        @test collect(Iterators.take(a, 3)) == ['b','c','d']
        @test collect(a) == ['e', 'f']
        @test_throws EOFError popfirst!(a) # trying to pop from an empty stateful iterator.
    end
    let a = @inferred(Iterators.Stateful([1, 1, 1, 2, 3, 4]))
        for x in a; x == 1 || break; end
        @test peek(a) == 3
        @test sum(a) == 7
    end
    @test (@inferred eltype(Iterators.Stateful("a"))) == Char
    # Interaction of zip/Stateful
    let a = Iterators.Stateful("a"), b = ""
    @test @inferred isempty(collect(zip(a,b)))
    @test !(@inferred isempty(a))
    @test @inferred isempty(collect(zip(b,a)))
    @test !(@inferred isempty(a))
    end
    let a = Iterators.Stateful("a"), b = "", c = Iterators.Stateful("c")
        @test @inferred isempty(collect(zip(a,b,c)))
        @test !(@inferred isempty(a))
        @test !(@inferred isempty(c))
        @test @inferred isempty(collect(zip(a,c,b)))
        @test !(@inferred isempty(a))
        @test !(@inferred isempty(c))
        @test @inferred isempty(collect(zip(b,a,c)))
        @test !(@inferred isempty(a))
        @test !(@inferred isempty(c))
        @test @inferred isempty(collect(zip(b,c,a)))
        @test !(@inferred isempty(a))
        @test !(@inferred isempty(c))
        @test @inferred isempty(collect(zip(c,a,b)))
        @test !(@inferred isempty(a))
        @test !(@inferred isempty(c))
        @test @inferred isempty(collect(zip(c,b,a)))
        @test !(@inferred isempty(a))
        @test !(@inferred isempty(c))
    end
    let a = Iterators.Stateful("aa"), b = "b", c = Iterators.Stateful("cc")
        @test (@inferred length(collect(zip(a,b,c)))) == 1
        @test !(@inferred isempty(a))
        @test !(@inferred isempty(c))
    end
    let a = Iterators.Stateful("aa"), b = "b", c = Iterators.Stateful("cc")
        @test (@inferred length(collect(zip(a,c,b)))) == 1
        @test !(@inferred isempty(a))
        @test !(@inferred isempty(c))
    end
    let a = Iterators.Stateful("aa"), b = "b", c = Iterators.Stateful("cc")
        @test (@inferred length(collect(zip(b,a,c)))) == 1
        @test !(@inferred isempty(a))
        @test !(@inferred isempty(c))
    end
    let a = Iterators.Stateful("aa"), b = "b", c = Iterators.Stateful("cc")
        @test (@inferred length(collect(zip(b,c,a)))) == 1
        @test !(@inferred isempty(a))
        @test !(@inferred isempty(c))
    end
    let a = Iterators.Stateful("aa"), b = "b", c = Iterators.Stateful("cc")
        @test (@inferred length(collect(zip(c,a,b)))) == 1
        @test !(@inferred isempty(a))
        @test !(@inferred isempty(c))
    end
    let a = Iterators.Stateful("aa"), b = "b", c = Iterators.Stateful("cc")
        @test (@inferred length(collect(zip(c,b,a)))) == 1
        @test !(@inferred isempty(a))
        @test !(@inferred isempty(c))
    end
    let z = zip(Iterators.Stateful("ab"), Iterators.Stateful("b"), Iterators.Stateful("c"))
        v, s = iterate(z)
        @test Base.isdone(z, s)
    end
    # Stateful does not define length
    let s = Iterators.Stateful(Iterators.Stateful(1:5))
        @test_throws MethodError length(s)
    end
end

@testset "pair for Svec" begin
    ps = pairs(Core.svec(:a, :b))
    @test ps isa Iterators.Pairs
    @test collect(ps) == [1 => :a, 2 => :b]
end

@testset "inference for large zip #26765" begin
    x = zip(1:2, ["a", "b"], (1.0, 2.0), Base.OneTo(2), Iterators.repeated("a"), 1.0:0.2:2.0,
            (1 for i in 1:2), Iterators.Stateful(["a", "b", "c"]), (1.0 for i in 1:2, j in 1:3))
    @test (@inferred Base.IteratorSize(x)) isa Base.SizeUnknown
    x = zip(1:2, ["a", "b"], (1.0, 2.0), Base.OneTo(2), Iterators.repeated("a"), 1.0:0.2:2.0,
            (1 for i in 1:2), Iterators.cycle(Iterators.Stateful(["a", "b", "c"])), (1.0 for i in 1:2, j in 1:3))
    @test (@inferred Base.IteratorSize(x)) isa Base.HasLength
    @test @inferred(length(x)) == 2
    z = Iterators.filter(x -> x[1] >= 1, x)
    @test @inferred(eltype(z)) <: Tuple{Int,String,Float64,Int,String,Float64,Any,String,Any}
    @test @inferred(first(z)) == (1, "a", 1.0, 1, "a", 1.0, 1, "a", 1.0)
    @test @inferred(first(Iterators.drop(z, 1))) == (2, "b", 2.0, 2, "a", 1.2, 1, "c", 1.0)
end

@testset "Stateful fix #30643" begin
    @test (@inferred Base.IteratorSize(1:10)) isa Base.HasShape{1}
    a = Iterators.Stateful(1:10)
    @test (@inferred Base.IteratorSize(a)) isa Base.SizeUnknown
    @test !Base.isdone(a)
    @test length(collect(a)) == 10
    @test Base.isdone(a)
    b = Iterators.Stateful(Iterators.take(1:10,3))
    @test (@inferred Base.IteratorSize(b)) isa Base.SizeUnknown
    @test !Base.isdone(b)
    @test length(collect(b)) == 3
    @test Base.isdone(b)
    c = Iterators.Stateful(Iterators.countfrom(1))
    @test (@inferred Base.IteratorSize(c)) isa Base.IsInfinite
    @test !Base.isdone(Iterators.take(c,3))
    @test length(collect(Iterators.take(c,3))) == 3
    d = Iterators.Stateful(Iterators.filter(isodd,1:10))
    @test (@inferred Base.IteratorSize(d)) isa Base.SizeUnknown
    @test length(collect(Iterators.take(d,3))) == 3
    @test length(collect(d)) == 2
    @test length(collect(d)) == 0
end

@testset "only" begin
    @test only([3]) === 3
    @test_throws ArgumentError only([])
    @test_throws ArgumentError only([3, 2])

    @test only(fill(42)) === 42 # zero dimensional array containing a single value.

    @test @inferred(only((3,))) === 3
    @test_throws ArgumentError only(())
    @test_throws ArgumentError only((3, 2))

    @test only(Dict(1=>3)) === (1=>3)
    @test_throws ArgumentError only(Dict{Int,Int}())
    @test_throws ArgumentError only(Dict(1=>3, 2=>2))

    @test only(Set([3])) === 3
    @test_throws ArgumentError only(Set(Int[]))
    @test_throws ArgumentError only(Set([3,2]))

    @test @inferred(only((;a=1))) === 1
    @test_throws ArgumentError only(NamedTuple())
    @test_throws ArgumentError only((a=3, b=2.0))

    @test @inferred(only(1)) === 1
    @test @inferred(only('a')) === 'a'
    @test @inferred(only(Ref([1, 2]))) == [1, 2]
    @test_throws ArgumentError only(Pair(10, 20))

    @test only(1 for ii in 1:1) === 1
    @test only(1 for ii in 1:10 if ii < 2) === 1
    @test_throws ArgumentError only(1 for ii in 1:10)
    @test_throws ArgumentError only(1 for ii in 1:10 if ii > 2)
    @test_throws ArgumentError only(1 for ii in 1:10 if ii > 200)
end

@testset "flatten empty tuple" begin
    @test @inferred isempty(collect(Iterators.flatten(())))
end

@testset "Iterators.accumulate" begin
    @test collect(Iterators.accumulate(+, [])) == []
    @test collect(Iterators.accumulate(+, [1])) == [1]
    @test collect(Iterators.accumulate(+, [1,2])) == [1,3]
    @test collect(Iterators.accumulate(+, [1,2,3])) == [1,3,6]
    @test collect(Iterators.accumulate(=>, [:a,:b,:c])) == [:a, :a => :b, (:a => :b) => :c]
    @test collect(Iterators.accumulate(+, (x for x in [true])))::Vector{Int} == [1]
    @test collect(Iterators.accumulate(+, (x for x in [true, true, false])))::Vector{Int} == [1, 2, 2]
    @test collect(Iterators.accumulate(+, (x for x in [true]), init=10.0))::Vector{Float64} == [11.0]
    @test (@inferred length(Iterators.accumulate(+, [10,20,30]))) == 3
    @test (@inferred size(Iterators.accumulate(max, rand(2,3)))) == (2,3)
    @test (@inferred Base.IteratorSize(Iterators.accumulate(max, rand(2,3)))) === Base.IteratorSize(rand(2,3))
    @test (@inferred Base.IteratorEltype(Iterators.accumulate(*, ()))) isa Base.EltypeUnknown
end

@testset "Base.accumulate" begin
    @test cumsum(x^2 for x in 1:3) == [1, 5, 14]
    @test cumprod(x + 1 for x in 1:3) == [2, 6, 24]
    @test accumulate(+, (x^2 for x in 1:3); init=100) == [101, 105, 114]
end

@testset "issue #58109" begin
    i = Iterators.map(identity, 3)
    j = Iterators.map(sqrt, 7)
    @test (@inferred Base.IteratorSize(i)) === @inferred Base.IteratorSize(eltype([i, j]))
end

@testset "IteratorSize trait for zip" begin
    @test (@inferred Base.IteratorSize(zip())) == Base.IsInfinite()                     # for zip of empty tuple
    @test (@inferred Base.IteratorSize(zip((1,2,3), repeated(0)))) == Base.HasLength()  # for zip of ::HasLength and ::IsInfinite
    @test (@inferred Base.IteratorSize(zip( 1:5, repeated(0) ))) == Base.HasLength()    # for zip of ::HasShape and ::IsInfinite
    @test (@inferred Base.IteratorSize(zip(repeated(0), (1,2,3)))) == Base.HasLength()  # for zip of ::IsInfinite and ::HasLength
    @test (@inferred Base.IteratorSize(zip(repeated(0), 1:5 ))) == Base.HasLength()     # for zip of ::IsInfinite and ::HasShape
    @test (@inferred Base.IteratorSize(zip((1,2,3), 1:5) )) == Base.HasLength()         # for zip of ::HasLength and ::HasShape
    @test (@inferred Base.IteratorSize(zip(1:5, (1,2,3)) )) == Base.HasLength()         # for zip of ::HasShape and ::HasLength
end

@testset "foldability inference" begin
    functions = (eltype, Base.IteratorSize, Base.IteratorEltype)
    helper(type::UnionAll) = (type{n} for n ∈ 1:10) # helper for trying with multiple iterator counts
    iterator_types = (  # each element here takes an iterator type as first parameter
        Base.Generator,
        Iterators.Reverse,
        Iterators.Enumerate,
        Iterators.Filter{F, I} where {I, F},
        Iterators.Accumulate{F, I} where {I, F},
        Iterators.Rest,
        Iterators.Count,
        Iterators.Take,
        Iterators.Drop,
        Iterators.TakeWhile,
        Iterators.DropWhile,
        Iterators.Cycle,
        Iterators.Repeated,
        Iterators.PartitionIterator,
        Iterators.Stateful,
        helper(Iterators.ProductIterator{Tuple{Vararg{I, N}}} where {N, I})...,
    )
    iterator_types_extra = (
        iterator_types...,
        helper(Iterators.Zip{Tuple{Vararg{I, N}}} where {N, I})...,
        helper(Iterators.Flatten{Tuple{Vararg{I, N}}} where {N, I})...,
    )
    simple_types = (Vector, NTuple, NamedTuple{X, Y} where {X, Y <: NTuple})
    example_type = Tuple{Bool, Int8, Vararg{Int16, 20}}
    function test_foldability_inference(f, S::Type)
        @test Core.Compiler.is_foldable(Base.infer_effects(f, Tuple{S}))
        @test Core.Compiler.is_foldable(Base.infer_effects(f, Tuple{Type{<:S}}))
    end
    @testset "concrete" begin  # weaker test, only checks foldability for certain concrete types
        @testset "f: $f" for f ∈ functions
            for U ∈ iterator_types_extra
                test_foldability_inference(f, U{example_type})
            end
        end
    end
    @testset "nonconcrete" begin  # stronger test, checks foldability for large families of types
        @testset "f: $f" for f ∈ functions
            for V ∈ simple_types
                test_foldability_inference(f, V)  # sanity check
                for U ∈ iterator_types
                    test_foldability_inference(f, U{<:V})
                end
            end
        end
    end
end

@testset "proper partition for non-1-indexed vector" begin
    @test partition(IdentityUnitRange(11:19), 5) |> collect == [11:15,16:19] # IdentityUnitRange
end

@testset "Iterators.peel" begin
    @test Iterators.peel([]) === nothing
    @test Iterators.peel(1:10)[1] == 1
    @test Iterators.peel(1:10)[2] |> collect == 2:10
    @test Iterators.peel(x^2 for x in 2:4)[1] == 4
    @test Iterators.peel(x^2 for x in 2:4)[2] |> collect == [9, 16]
end

@testset "last for iterators" begin
    @test last(Iterators.map(identity, 1:3)) == 3
    @test last(Iterators.filter(iseven, (Iterators.map(identity, 1:3)))) == 2
end

@testset "isempty and isdone for Generators" begin
    itr = eachline(IOBuffer("foo\n"))
    gen = (x for x in itr)
    @test !(@inferred isempty(gen))
    @test !Base.isdone(gen)
    @test collect(gen) == ["foo"]
end

@testset "empty product iterators" begin
    v = nothing
    for (z,) in zip(Iterators.product())
        v = z
    end
    @test v == ()
end

@testset "collect partition substring" begin
    @test collect(Iterators.partition(lstrip("01111", '0'), 2)) == ["11", "11"]
end

@testset "IterableStringPairs" begin
    for s in ["", "a", "abcde", "γ", "∋γa"]
        for T in (String, SubString, GenericString)
            sT = T(s)
            p = pairs(sT)
            @test collect(p) == [k=>v for (k,v) in zip(keys(sT), sT)]
            rv = Iterators.reverse(p)
            @test collect(rv) == reverse([k=>v for (k,v) in zip(keys(sT), sT)])
            rrv = Iterators.reverse(rv)
            @test collect(rrv) == collect(p)
        end
    end
end

let itr = (i for i in 1:9) # Base.eltype == Any
    @test first(Iterators.partition(itr, 3)) isa Vector{Any}
    @test collect(zip(repeat([Iterators.Stateful(itr)], 3)...)) == [(1, 2, 3), (4, 5, 6), (7, 8, 9)]
end

@testset "map/reduce/mapreduce without an iterator argument" begin
    maps = map(Returns, (nothing, 3, 3:2, 3:3, (), (3,)))
    mappers1 = (Iterators.map, map, foreach, reduce, foldl, foldr)
    mappers2 = (mapreduce, mapfoldl, mapfoldr)

    @testset "map/reduce" begin
        @testset "r: $r" for r ∈ mappers1
            @testset "f: $f" for f ∈ maps
                @test_throws MethodError r(f)
                @test !applicable(r, f)
                @test !hasmethod(r, Tuple{typeof(f)})
            end
        end
    end

    @testset "mapreduce" begin
        @testset "mr: $mr" for mr ∈ mappers2
            @testset "f: $f" for f ∈ maps
                @testset "g: $g" for g ∈ maps
                    @test_throws MethodError mr(f, g)
                    @test !applicable(mr, f, g)
                    @test !hasmethod(mr, Tuple{typeof(f),typeof(g)})
                end
            end
        end
    end
end

@testset "nth" begin

    Z = Array{Int,0}(undef)
    Z[] = 17
    it_result_pairs = Dict(
        (Z, 1) => 17,
        (collect(1:100), 23) => 23,
        (10:6:1000, 123) => 10 + 6 * 122,
        ("∀ϵ>0", 3) => '>',
        ((1, 3, 5, 10, 78), 2) => 3,
        (reshape(1:30, (5, 6)), 21) => 21,
        (3, 1) => 3,
        (true, 1) => true,
        ('x', 1) => 'x',
        (4 => 5, 2) => 5,
        (view(Z), 1) => 17,
        (view(reshape(1:30, (5, 6)), 2:4, 2:6), 10) => 22,
        ((x^2 for x in 1:10), 9) => 81,
        (Iterators.Filter(isodd, 1:10), 3) => 5,
        (Iterators.flatten((1:10, 50:60)), 15) => 54,
        (pairs(50:60), 7) => 7 => 56,
        (zip(1:10, 21:30, 51:60), 6) => (6, 26, 56),
        (Iterators.product(1:3, 10:12), 3) => (3, 10),
        (Iterators.repeated(3.14159, 5), 4) => 3.14159,
        ((a=2, b=3, c=5, d=7, e=11), 4) => 7,
        (Iterators.cycle(collect(1:100)), 9999) => 99,
        (Iterators.cycle([1, 2, 3, 4, 5], 5), 25) => 5,
        (Iterators.cycle("String", 10), 16) => 'i',
        (Iterators.cycle(((),)), 1000) => ()
    )


    @testset "iter: $IT" for (IT, n) in keys(it_result_pairs)
        @test it_result_pairs[(IT, n)] == nth(IT, n)
        @test_throws BoundsError nth(IT, -42)

        IT isa Iterators.Cycle && continue # cycles are infinite so never OOB
        @test_throws BoundsError nth(IT, 999999999)
    end

    empty_cycle = Iterators.cycle([])
    @test_throws BoundsError nth(empty_cycle, 42)

    # test the size unknown branch for cycles
    # only generate odd numbers so we know the actual length
    # but the iterator is still SizeUnknown()
    it_size_unknown = Iterators.filter(isodd, 1:2:10)
    @test Base.IteratorSize(it_size_unknown) isa Base.SizeUnknown
    @test length(collect(it_size_unknown)) == 5

    cycle_size_unknown = Iterators.cycle(it_size_unknown)
    finite_cycle_size_unknown = Iterators.cycle(it_size_unknown, 5)
    @test nth(cycle_size_unknown, 2) == 3
    @test nth(cycle_size_unknown, 20) == 9 # mod1(20, 5) = 5, wraps 4 times
    @test nth(finite_cycle_size_unknown, 2) == 3
    @test nth(finite_cycle_size_unknown, 20) == 9
    @test_throws BoundsError nth(finite_cycle_size_unknown, 30) # only wraps 5 times, max n is 5 * 5 = 25
end

@testset "Iterators docstrings" begin
    @test isempty(Docs.undocumented_names(Iterators))
end

# Filtered list comprehension (`Filter` construct) type inference
@test Base.infer_return_type((Vector{Any},)) do xs
    [x for x in xs if x isa Int]
end == Vector{Int}
