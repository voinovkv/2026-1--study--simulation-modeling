using ResumableFunctions
using ConcurrentSim
using Distributions
using Random
using StableRNGs
using Plots

const S = 3              # The reservoir of spare machines waiting in the wings.
const LAMBDA = 100.0     # The average interval between the whispers of failure.
const MU = 10.0         # The duration of a craftsman's dedicated labor.
const NUM_REPAIRMEN = 2  # The number of masters available in the repair guild.
const rng = StableRNG(42) # A seed to ensure our destiny is repeatable.
const F = Exponential(LAMBDA)
const G = Exponential(MU)

time_history = Float64[]
working_machines_history = Int[]

@resumable function machine(env::Environment, repair_facility::Resource, spares::Store{Process}, n_machines::Int)
    while true

        try @yield timeout(env, Inf) catch end

        @yield timeout(env, rand(rng, F))

        push!(time_history, now(env))
        push!(working_machines_history, n_machines + length(spares.items) - 1)

        get_spare = take!(spares)
        @yield get_spare | timeout(env)

        if state(get_spare) != ConcurrentSim.idle
            @yield interrupt(value(get_spare))
        else

            throw(StopSimulation("No more spares!"))
        end

        @yield request(repair_facility)

        @yield timeout(env, rand(rng, G))

        @yield unlock(repair_facility)

        @yield put!(spares, active_process(env))

        push!(time_history, now(env))
        push!(working_machines_history, n_machines + length(spares.items))
    end
end

@resumable function monitor_resource(env::Environment, res::Resource, q_length::Vector{Float64}, q_times::Vector{Float64}, usage::Vector{Float64}, usage_times::Vector{Float64})
    while true

        push!(q_length, Float64(length(res.put_queue)))
        push!(q_times, now(env))
        push!(usage, Float64(res.level))
        push!(usage_times, now(env))
        @yield timeout(env, 0.5)
    end
end

@resumable function start_sim(env::Environment, repair_facility::Resource, spares::Store{Process}, n::Int)
    for i = 1:n
        proc = @process machine(env, repair_facility, spares, n)
        @yield interrupt(proc)
    end
    for i = 1:S
        proc = @process machine(env, repair_facility, spares, n)
        @yield put!(spares, proc)
    end
end

function time_weighted_avg(values, times, end_time)
    if isempty(values) return 0.0 end
    sum_val = 0.0
    for i in 1:(length(values)-1)
        sum_val += values[i] * (times[i+1] - times[i])
    end
    sum_val += values[end] * (end_time - times[end])
    return sum_val / end_time
end

function analytical_repairman(N_working, S_spares, s_repairmen, lambda_val, mu_val)
    K = N_working + S_spares
    rho = lambda_val / mu_val
    p0_inv = sum(0:K) do n
        if n <= s_repairmen
            binomial(K, n) * (rho^n)
        else
            binomial(K, n) * (factorial(big(n)) / (factorial(big(s_repairmen)) * big(s_repairmen)^(n - s_repairmen))) * (rho^n)
        end
    end
    p0 = 1.0 / p0_inv
    L = sum(1:K) do n
        term = n <= s_repairmen ?
            (binomial(K, n) * (rho^n) * p0) :
            (binomial(K, n) * (factorial(big(n)) / (factorial(big(s_repairmen)) * big(s_repairmen)^(n - s_repairmen))) * (rho^n) * p0)
        n * Float64(term)
    end
    Lq = sum((s_repairmen + 1):K) do n
        term = (binomial(K, n) * (factorial(big(n)) / (factorial(big(s_repairmen)) * big(s_repairmen)^(n - s_repairmen))) * (rho^n) * p0)
        (n - s_repairmen) * Float64(term)
    end
    return (L - Lq) / s_repairmen, Lq
end

for n in [5, 10, 15]
    empty!(time_history)
    empty!(working_machines_history)
    sim = Simulation()
    repair_facility = Resource(sim, NUM_REPAIRMEN)
    spares_store = Store{Process}(sim)
    q_len, q_t, usg, usg_t = Float64[], Float64[], Float64[], Float64[]
    @process monitor_resource(sim, repair_facility, q_len, q_t, usg, usg_t)
    @process start_sim(sim, repair_facility, spares_store, n)
    run(sim)
    stop_t = now(sim)
    sim_util = time_weighted_avg(usg, usg_t, stop_t) / NUM_REPAIRMEN
    sim_q = time_weighted_avg(q_len, q_t, stop_t)
    ana_util, ana_q = analytical_repairman(n, S, NUM_REPAIRMEN, 1/LAMBDA, 1/MU)

    println("--- Results for N=$n ---")
    println("Utilization: Sim=$(round(sim_util, digits=3)), Ana=$(round(ana_util, digits=3))")
    println("Avg Queue:   Sim=$(round(sim_q, digits=3)), Ana=$(round(ana_q, digits=3))\n")
    p = plot(time_history, working_machines_history, step=:post, title="N=$n", xlabel="Time", ylabel="Working")
    display(p)
end
