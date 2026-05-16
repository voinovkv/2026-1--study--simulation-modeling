using StableRNGs
using Distributions
using ConcurrentSim
using ResumableFunctions
using Plots
 
# --- The Prologue: Preparing the Stage ---
# We begin by ensuring a path exists for our visual chronicles.
mkpath("plots")
 
# --- The Laws of the Land: Simulation Parameters ---
# We establish a seed for the threads of fate and determine the size of our gathering.
rng = StableRNG(123)
num_customers = 10
 
# --- The Infrastructure: Queue and Flow ---
# Here we define the capacity of our sanctuary and the rhythm of those seeking entry.
num_servers = 2
mu = 1.0 / 2
lam = 0.9
arrival_dist = Exponential(1 / lam)
service_dist = Exponential(1 / mu)
 
# --- The Scribe's Ledger: Tracking the Population ---
times = Float64[0.0]
in_system = Int[0]
 
# A silent observer records each shift in the balance of the crowd.
function update_stats(env, delta)
    push!(times, now(env))
    push!(in_system, in_system[end] + delta)
end
 
# --- The Traveler's Tale: The Journey of a Customer ---
@resumable function customer(
    env::Environment,
    server::Resource,
    id::Integer,
    t_a::Float64,
    d_s::Distribution,
)
    # The traveler waits for the appointed time to reach the gate.
    @yield timeout(env, t_a)
    update_stats(env, 1)
    println("Traveler $id has arrived at the gates: ", now(env))
    
    # They request entry, standing in line until an attendant is free.
    @yield request(server)
    println("Traveler $id is being attended to: ", now(env))
    
    # The interaction unfolds, a moment of transaction and service.
    @yield timeout(env, rand(rng, d_s))
    
    # Having concluded their business, the attendant is released for the next soul.
    @yield unlock(server)
    
    # The traveler departs, leaving the system behind.
    update_stats(env, -1)
    println("Traveler $id has completed their journey: ", now(env))
end
 
# --- The Grand Performance: Setting the World in Motion ---
function setup_and_run()
    sim = Simulation()
    server = Resource(sim, num_servers)
    arrival_time = 0.0
    
    # One by one, we summon the travelers into existence.
    for i = 1:num_customers
        arrival_time += rand(rng, arrival_dist)
        @process customer(sim, server, i, arrival_time, service_dist)
    end
    
    # The clock begins to tick, and the story unfolds.
    run(sim)
    
    # --- The Epilogue: Visualizing the Flow ---
    # We translate the scribe's notes into a grand tapestry of data.
    p = plot(times, in_system, linetype=:steppost,
             xlabel="Time", ylabel="Count",
             label="Current Population", lw=2)
    savefig(p, "plots/simulation_results.png")
    println("\nThe chronicle has been saved to plots/simulation_results.png")
    display(p)
end
 
setup_and_run()
