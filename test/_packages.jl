using Test, AxisKeys

@testset "offset" begin
    using OffsetArrays

    o = OffsetArray(rand(1:99, 5), -2:2)
    w = wrapdims(o, i='a':'e')
    @test axiskeys(w,1) isa OffsetArray
    @test w[i=-2] == w('a')
    @test_throws ArgumentError KeyedArray(o, i='a':'e')

    w′ = wrapdims(o)
    @test axiskeys(w′,1) == -2:2

end
@testset "unique" begin
    using UniqueVectors

    u = wrapdims(rand(Int8,5,1), UniqueVector, [:a, :b, :c, :d, :e], nothing)
    @test axiskeys(u,1) isa UniqueVector
    @test u(:b) == u[2,:]

    n = wrapdims(rand(2,100), UniqueVector, x=nothing, y=rand(Int,100))
    @test axiskeys(n,1) isa UniqueVector
    k = axiskeys(n, :y)[7]
    @test n(y=k) == n[:,7]

end
@testset "tables" begin
    using Tables

    R = wrapdims(rand(2,3), 11:12, 21:23)
    N = wrapdims(rand(2,3), a=[11, 12], b=[21, 22, 23.0])

    @test keys(first(Tables.rows(R))) == (:dim_1, :dim_2, :value)
    @test keys(first(Tables.rows(N))) == (:a, :b, :value)

    @test Tables.columns(N).a == [11, 12, 11, 12, 11, 12]

end
@testset "stack" begin
    using LazyStack

    rin = [wrapdims(1:3, a='a':'c') for i=1:4]

    @test axiskeys(stack(rin), :a) == 'a':'c'
    @test axiskeys(stack(:b, rin...), :a) == 'a':'c' # tuple
    @test axiskeys(stack(z for z in rin), :a) == 'a':'c' # generator

    rout = wrapdims([[1,2], [3,4]], b=10:11)
    @test axiskeys(stack(rout), :b) == 10:11

    rboth = wrapdims(rin, b=10:13)
    @test axiskeys(stack(rboth), :a) == 'a':'c'
    @test axiskeys(stack(rboth), :b) == 10:13

    nts = [(i=i, j="j", k=33) for i=1:3]
    @test axiskeys(stack(nts), 1) == [:i, :j, :k]
    @test axiskeys(stack(:z, nts...), 1) == [:i, :j, :k]
    @test axiskeys(stack(n for n in nts), 1) == [:i, :j, :k]

end
@testset "dates" begin
    using Dates

    D = wrapdims(rand(2,53), row = [:one, :two], week = Date(2020):Week(1):Date(2021))
    w9 = axiskeys(D,:week)[9]
    @test w9 isa Date
    @test D(w9) == D[week=9]
    # But steps of Year(1) don't work, https://github.com/JuliaLang/julia/issues/35203

    @test D(==(Date(2020, 1, 8))) == D[:, 2:2]
    @test D(Near(Date(2020, 1, 10))) == D(Date(2020, 1, 8)) == D[:, 2]
    int = Interval(Date(2020, 1, 8), Date(2020, 1, 22))
    @test D(int) == D[:, 2:4]
    axiskeys(D[:,int],2) isa Array # ideally would be a range

end
@testset "inverted" begin
    using InvertedIndices

    K = wrapdims(rand(4,5))
    @test K[:, Not(4)] == K[:, vcat(1:3, 5)] == K(:, Base.Fix2(!=,4)) == K(:, Not(4))
    @test K[Not(1,4), :] == K[2:3, :] == K(r -> 2<=r<=3, :)

    N = wrapdims(rand(Int8, 2,3,4), a=[:one, :two], b='α':'γ', c=31:34)
    @test N[b=Not(2)] == N[:,[1,3],:] == N(b=Base.Fix2(!=,'β')) == N(:,['α','γ'],:)
    @test N[c=Not(2,4)] == N(c=Index[Not(2,4)]) == N(c=Not(2,4))

end
@testset "fourier" begin
    using FFTW

    times = 0.1:0.1:10
    data = rand(100) ./ 10; data[1:5:end] .= 1;
    A = KeyedArray(data, times)
    Atil = fft(A)
    @test axiskeys(Atil,1)[end] == -0.1

    Ashift = fftshift(Atil)
    @test axiskeys(Ashift,1)[end] == +4.9

    Ar = rfft(A) # different size, different freqencies
    @test axiskeys(Ar,1)[end] == 5.0

    A2 = ifft(ifftshift(Ashift))
    A ≈ A2
    @test all(mod.(axiskeys(A,1) .- axiskeys(A2,1),10) .≈ 0.1) # that's OK I think?

    data2 = randn(32,2);
    B = wrapdims(data2, time=100:10:410.0, col=[:a, :b])
    @test_skip Btil = fftshift(fft(B, :time), :time) # result does not have names
    Btil = fftshift(fft(B, :time), 1)
    @test parent(Btil) ≈ fftshift(fft(data2,1),1)

end
@testset "unitful fourier" begin
    using FFTW
    using Unitful: s

    times = 0.1s:0.1s:10s
    A = wrapdims(rand(100), t=times)

    ifft(fft(A))
    fft(ifft(A))
    irfft(rfft(A), 100)

    abs.(fft(A)) # keys remain Frequencies thanks to copy method

    fftshift(fft(A))
    ifftshift(A) # keys become a Vector here, unavoidable I think

    @test axiskeys(sortkeys(fft(A)),1) ≈ axiskeys(fftshift(fft(A)),1)
    @test_broken sortkeys(fft(A)) ≈ fftshift(fft(A)) # isapprox should be used for keys

end

@testset "statsbase" begin
    using CovarianceEstimation, StatsBase

    A = rand(4, 3)
    A_ka = KeyedArray(A, (0:3, [:a, :b, :c]))
    A_kanda = KeyedArray(A; time = 0:3, id = [:a, :b, :c])
    wv = aweights(rand(4))
    kwv = KeyedArray(wv; time = 0:3)

    @testset "$f" for f in (mean, std, var)
        R = f == mean ? f(A, wv; dims=1) : f(A, wv, 1; corrected=true)

        R_ka = f(A_ka, wv; dims=1)
        R_kanda_int = f(A_kanda, wv; dims=1)
        R_kanda_sym = f(A_kanda, wv; dims=:time)
        R_kanda_kwv = f(A_kanda, kwv; dims=:time)
        expected_keys = (Base.OneTo(1), [:a, :b, :c])
        expected_names = (:time, :id)

        @test dimnames(R_kanda_int) == dimnames(R_kanda_sym) == dimnames(R_kanda_kwv) == expected_names
        @test axiskeys(R_ka) == axiskeys(R_kanda_int) == axiskeys(R_kanda_sym) == axiskeys(R_kanda_kwv) == expected_keys
        @test parent(R_ka) ≈ parent(parent(R_kanda_int)) ≈ parent(parent(R_kanda_sym)) ≈ parent(parent(R_kanda_kwv)) ≈ R
    end

    @testset "$f" for f in (cov, cor, scattermat)
        # Inconsistent statsbase behaviour
        R = if f == cov
            f(A, wv, 1; corrected=true)
        elseif f == scattermat
            f(A, wv; dims=1)
        else
            f(A, wv, 1)
        end

        R_ka = f(A_ka, wv; dims=1)
        R_kanda_int = f(A_kanda, wv; dims=1)
        R_kanda_sym = f(A_kanda, wv; dims=:time)
        R_kanda_kwv = f(A_kanda, kwv; dims=:time)
        expected_keys = ([:a, :b, :c], [:a, :b, :c])
        expected_names = (:id, :id)

        @test dimnames(R_kanda_int) == dimnames(R_kanda_sym) == dimnames(R_kanda_kwv) == expected_names
        @test axiskeys(R_ka) == axiskeys(R_kanda_int) == axiskeys(R_kanda_sym) == axiskeys(R_kanda_kwv) == expected_keys
        @test parent(R_ka) ≈ parent(parent(R_kanda_int)) ≈ parent(parent(R_kanda_sym)) ≈ parent(parent(R_kanda_kwv)) ≈ R
    end

    @testset "$f" for f in (mean_and_var, mean_and_std, mean_and_cov)
        R1, R2 = f(A, wv, 1; corrected=true)
        R1_ka, R2_ka = f(A_ka, wv; dims=1)
        R1_kanda_int, R2_kanda_int = f(A_kanda, wv; dims=1)
        R1_kanda_sym, R2_kanda_sym = f(A_kanda, wv; dims=:time)
        R1_kanda_kwv, R2_kanda_kwv = f(A_kanda, kwv; dims=:time)

        @test parent(R1_ka) ≈ parent(parent(R1_kanda_int)) ≈ parent(parent(R1_kanda_sym)) ≈ parent(parent(R1_kanda_kwv)) ≈ R1
        @test parent(R2_ka) ≈ parent(parent(R2_kanda_int)) ≈ parent(parent(R2_kanda_sym)) ≈ parent(parent(R2_kanda_kwv)) ≈ R2
    end

    @testset "conversions" begin
        @testset "cov2cor" begin
            @test cov2cor(cov(A_ka; dims=1), std(A_ka; dims=1)) ≈ cor(A_ka; dims=1)
            @test cov2cor(cov(A_ka; dims=2), std(A_ka; dims=2)) ≈ cor(A_ka; dims=2)
            @test cov2cor(cov(A_kanda; dims=:time), std(A_kanda; dims=:time)) ≈ cor(A_kanda; dims=:time)
            @test cov2cor(cov(A_kanda; dims=:id), std(A_kanda; dims=:id)) ≈ cor(A_kanda; dims=:id)
        end
        @testset "cor2cov" begin
            @test cor2cov(cor(A_ka; dims=1), std(A_ka; dims=1)) ≈ cov(A_ka; dims=1)
            @test cor2cov(cor(A_ka; dims=2), std(A_ka; dims=2)) ≈ cov(A_ka; dims=2)
            @test cor2cov(cor(A_kanda; dims=:time), std(A_kanda; dims=:time)) ≈ cov(A_kanda; dims=:time)
            @test cor2cov(cor(A_kanda; dims=:id), std(A_kanda, dims=:id)) ≈ cov(A_kanda; dims=:id)
        end
    end

    @testset "covariance estimation" begin
        ce = SimpleCovariance()

        @testset "unweighted" begin
            R = cov(ce, A; dims=1)
            R_ka = cov(ce, A_ka; dims=1)
            R_kanda_int = cov(ce, A_kanda; dims=1)
            R_kanda_sym = cov(ce, A_kanda; dims=:time)
            expected_keys = ([:a, :b, :c], [:a, :b, :c])
            expected_names = (:id, :id)

            @test dimnames(R_kanda_int) == dimnames(R_kanda_sym) == expected_names
            @test axiskeys(R_ka) == axiskeys(R_kanda_int) == axiskeys(R_kanda_sym) == expected_keys
            @test parent(R_ka) ≈ parent(parent(R_kanda_int)) ≈ parent(parent(R_kanda_sym)) ≈ R
        end

        @testset "weighted" begin
            R = cov(ce, A, wv; dims=1)
            R_ka = cov(ce, A_ka, wv; dims=1)
            R_kanda_int = cov(ce, A_kanda, wv; dims=1)
            R_kanda_sym = cov(ce, A_kanda, wv; dims=:time)
            R_kanda_kwv = cov(ce, A_kanda, kwv; dims=:time)
            expected_keys = ([:a, :b, :c], [:a, :b, :c])
            expected_names = (:id, :id)

            @test dimnames(R_kanda_int) == dimnames(R_kanda_sym) == dimnames(R_kanda_kwv) == expected_names
            @test axiskeys(R_ka) == axiskeys(R_kanda_int) == axiskeys(R_kanda_sym) == axiskeys(R_kanda_kwv) == expected_keys
            @test parent(R_ka) ≈ parent(parent(R_kanda_int)) ≈ parent(parent(R_kanda_sym)) ≈ parent(parent(R_kanda_kwv)) ≈ R
        end
    end
end
