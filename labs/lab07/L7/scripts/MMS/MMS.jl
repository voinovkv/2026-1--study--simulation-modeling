using StableRNGs
using Distributions
using ConcurrentSim
using ResumableFunctions
using Plots

mkpath("plots")

rng = StableRNG(123)
num_customers = 10

num_servers = 2
mu = 1.0 / 2
lam = 0.9
arrival_dist = Exponential(1 / lam)
service_dist = Exponential(1 / mu)

times = Float64[0.0]
in_system = Int[0]

function update_stats(env, delta)
    push!(times, now(env))
    push!(in_system, in_system[end] + delta)
end

@resumable function customer(
    env::Environment,
    server::Resource,
    id::Integer,
    t_a::Float64,
    d_s::Distribution,
)

    @yield timeout(env, t_a)
    update_stats(env, 1)
    println("Traveler $id has arrived at the gates: ", now(env))

    @yield request(server)
    println("Traveler $id is being attended to: ", now(env))

    @yield timeout(env, rand(rng, d_s))

    @yield unlock(server)

    update_stats(env, -1)
    println("Traveler $id has completed their journey: ", now(env))
end

function setup_and_run()
    sim = Simulation()
    server = Resource(sim, num_servers)
    arrival_time = 0.0

    for i = 1:num_customers
        arrival_time += rand(rng, arrival_dist)
        @process customer(sim, server, i, arrival_time, service_dist)
    end

    run(sim)

    p = plot(times, in_system, linetype=:steppost,
             title="The ebb and flow of travelers over time",
             xlabel="Time (The Eternal Stream)", ylabel="Count (Souls within the Walls)",
             label="Current Population", lw=2)
    savefig(p, "plots/simulation_results.png")
    println("\nThe chronicle has been saved to plots/simulation_results.png")
    display(p)
end

setup_and_run()
