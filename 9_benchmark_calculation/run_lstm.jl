using Zygote, Flux, BenchmarkTools, Test, DataFrames, GLM, Statistics
using Plots

function build_model(num_layers::Int, size::Int)
    layers = Any[]
    for layer_idx in 1:num_layers
        push!(layers, LSTM(size, size))
    end
    return mapleaves(Flux.data, Chain(layers...))
end

@info "Reporting (num_layers, seq_len, feature_size, batch_size, time)"
function sweep_batchsizes(batch_sizes, num_layers = 1, seq_len = 4, feature_size = 4)
    timings = Float64[]
    for batch_size in batch_sizes
        model = build_model(num_layers, feature_size)
        x = randn(feature_size, batch_size)
        y, back = Zygote.forward(m -> begin
            x_t = x
            for idx in 1:seq_len
                x_t = m(x_t)
            end
            return sum(x_t)
        end, model)
        push!(timings, minimum(@benchmark $back(1f0)).time/(seq_len*num_layers))
        @info num_layers, seq_len, feature_size, batch_size, timings[end]
    end
    return timings
end


batch_sizes = 1:4
timings = Dict()
for num_layers in 1:3,
    seq_len in (4, 8),
    feature_size in (4, 8)

    timings[(num_layers, seq_len, feature_size, batch_sizes)] = sweep_batchsizes(batch_sizes, num_layers, seq_len, feature_size)
end

overhead_estimates = Dict()
for k in keys(timings)
    data = DataFrame(X=batch_sizes, Y=timings[k])
    ols = lm(@formula(Y ~ X), data)
    overhead_estimates[k] = coeftable(ols).cols[1][1]
end
@show overhead_estimates
println("Mean overhead: $(mean(values(overhead_estimates)))ns")

#gr()
#ENV["GKSwstype"]="100"
#p = plot()
#for num_layers in layers
#    plot!(p, seq_lens, [minimum(t).time for t in timings[num_layers]]; title="LSTM Runtime", ylabel="Runtime (μs)", xlabel="Sequence Length", label="$(num_layers) layers")
#end
#savefig(p, joinpath(@__DIR__, "lstm_runtime.png"))
