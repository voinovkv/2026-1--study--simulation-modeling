using DrWatson
@quickactivate "lab_04_agents_SIR"

using Agents
using BlackBoxOptim
using Statistics
using DataFrames
using CSV

include(srcdir("sir_model.jl"))

function evaluate_candidate(x; replicates = 3, n_steps = 80)
    infected_frac(model) = count(a.status == :I for a in allagents(model)) / nagents(model)
    dead_count(model) = 3000 - nagents(model)

    peak_vals = Float64[]
    death_vals = Float64[]

    for rep in 1:replicates
        model = initialize_sir(;
            Ns = [1000, 1000, 1000],
            β_und = fill(x[1], 3),
            β_det = fill(x[1] / 10, 3),
            infection_period = 14,
            detection_time = round(Int, x[2]),
            death_rate = x[3],
            reinfection_probability = 0.1,
            Is = [0, 0, 1],
            seed = 42 + rep,
            n_steps = n_steps,
        )

        peak_infected = 0.0
        for _ in 1:n_steps
            Agents.step!(model, 1)
            frac = infected_frac(model)
            if frac > peak_infected
                peak_infected = frac
            end
        end

        push!(peak_vals, peak_infected)
        push!(death_vals, dead_count(model) / 3000)
    end

    return mean(peak_vals), mean(death_vals)
end

function constrained_cost(x)
    peak, death_fraction = evaluate_candidate(x)
    if peak > 0.30
        return 1.0 + peak
    end
    return death_fraction
end

function main()
    result = bboptimize(
        constrained_cost;
        SearchRange = [
            (0.1, 1.0),
            (3.0, 14.0),
            (0.01, 0.1),
        ],
        NumDimensions = 3,
        MaxTime = 60,
        TraceMode = :compact,
        Method = :adaptive_de_rand_1_bin_radiuslimited,
    )

    best = best_candidate(result)
    best_cost = best_fitness(result)
    peak, death_fraction = evaluate_candidate(best; replicates = 5, n_steps = 100)

    summary_df = DataFrame(
        β_und = [best[1]],
        detection_time = [round(Int, best[2])],
        death_rate = [best[3]],
        objective = [best_cost],
        peak_infected = [peak],
        death_fraction = [death_fraction],
        satisfies_constraint = [peak <= 0.30],
    )

    CSV.write(datadir("optimization_with_constraint.csv"), summary_df)

    println("Best parameters with peak constraint:")
    println("β_und = $(best[1])")
    println("detection_time = $(round(Int, best[2]))")
    println("death_rate = $(best[3])")
    println("peak_infected = $(peak)")
    println("death_fraction = $(death_fraction)")
    println("constraint_satisfied = $(peak <= 0.30)")
end

main()
