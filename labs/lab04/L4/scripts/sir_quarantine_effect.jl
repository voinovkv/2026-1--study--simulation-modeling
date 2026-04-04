using DrWatson
@quickactivate "lab_04_agents_SIR"

using Agents
using DataFrames
using Plots
using CSV

include(srcdir("sir_model.jl"))
include(srcdir("sir_quarantine_model.jl"))

function create_migration_matrix(C, intensity)
    M = ones(C, C) .* intensity ./ (C - 1)
    for i in 1:C
        M[i, i] = 1 - intensity
    end
    return M
end

function run_baseline_experiment(params)
    model = initialize_sir(; params...)

    times = Int[]
    S_vals = Int[]
    I_vals = Int[]
    R_vals = Int[]
    total_vals = Int[]

    for step in 1:params[:n_steps]
        agent_ids = collect(allids(model))
        for id in agent_ids
            agent = try
                model[id]
            catch
                nothing
            end
            if agent !== nothing
                sir_agent_step!(agent, model)
            end
        end

        push!(times, step)
        push!(S_vals, susceptible_count(model))
        push!(I_vals, infected_count(model))
        push!(R_vals, recovered_count(model))
        push!(total_vals, total_count(model))
    end

    return DataFrame(
        time = times,
        susceptible = S_vals,
        infected = I_vals,
        recovered = R_vals,
        total = total_vals,
    )
end

function run_quarantine_experiment(params)
    model = initialize_sir_quarantine(; params...)

    times = Int[]
    S_vals = Int[]
    I_vals = Int[]
    R_vals = Int[]
    total_vals = Int[]
    closed_city1 = Bool[]
    closed_city2 = Bool[]
    closed_city3 = Bool[]

    for step in 1:params[:n_steps]
        agent_ids = collect(allids(model))
        for id in agent_ids
            agent = try
                model[id]
            catch
                nothing
            end
            if agent !== nothing
                sir_quarantine_agent_step!(agent, model)
            end
        end

        push!(times, step)
        push!(S_vals, susceptible_count_quarantine(model))
        push!(I_vals, infected_count_quarantine(model))
        push!(R_vals, recovered_count_quarantine(model))
        push!(total_vals, total_count_quarantine(model))
        push!(closed_city1, city_is_closed(model, 1))
        push!(closed_city2, city_is_closed(model, 2))
        push!(closed_city3, city_is_closed(model, 3))
    end

    return DataFrame(
        time = times,
        susceptible = S_vals,
        infected = I_vals,
        recovered = R_vals,
        total = total_vals,
        city1_closed = closed_city1,
        city2_closed = closed_city2,
        city3_closed = closed_city3,
    )
end

function main()
    params = Dict(
        :Ns => [1000, 1000, 1000],
        :β_und => [0.5, 0.5, 0.5],
        :β_det => [0.05, 0.05, 0.05],
        :infection_period => 14,
        :detection_time => 7,
        :death_rate => 0.02,
        :reinfection_probability => 0.1,
        :Is => [1, 0, 0],
        :seed => 42,
        :n_steps => 150,
        :migration_rates => create_migration_matrix(3, 0.2),
    )

    baseline_df = run_baseline_experiment(params)

    quarantine_params = merge(params, Dict(:quarantine_threshold => 0.1))
    quarantine_df = run_quarantine_experiment(quarantine_params)

    CSV.write(datadir("quarantine_baseline.csv"), baseline_df)
    CSV.write(datadir("quarantine_enabled.csv"), quarantine_df)

    baseline_peak = maximum(baseline_df.infected)
    quarantine_peak = maximum(quarantine_df.infected)
    baseline_peak_time = baseline_df.time[argmax(baseline_df.infected)]
    quarantine_peak_time = quarantine_df.time[argmax(quarantine_df.infected)]
    baseline_deaths = sum(params[:Ns]) - baseline_df.total[end]
    quarantine_deaths = sum(params[:Ns]) - quarantine_df.total[end]

    summary_df = DataFrame(
        scenario = ["baseline", "quarantine"],
        peak_infected = [baseline_peak, quarantine_peak],
        peak_time = [baseline_peak_time, quarantine_peak_time],
        total_deaths = [baseline_deaths, quarantine_deaths],
    )
    CSV.write(datadir("quarantine_summary.csv"), summary_df)

    p1 = plot(
        baseline_df.time,
        baseline_df.infected;
        label = "Infected without quarantine",
        xlabel = "Days",
        ylabel = "Infected",
        linewidth = 2,
        title = "Effect of quarantine on infected population",
    )
    plot!(p1, quarantine_df.time, quarantine_df.infected; label = "Infected with quarantine", linewidth = 2)

    p2 = plot(
        baseline_df.time,
        baseline_df.total;
        label = "Total without quarantine",
        xlabel = "Days",
        ylabel = "Total population",
        linewidth = 2,
        title = "Population dynamics",
    )
    plot!(p2, quarantine_df.time, quarantine_df.total; label = "Total with quarantine", linewidth = 2)

    p3 = plot(
        quarantine_df.time,
        Int.(quarantine_df.city1_closed);
        label = "City 1 closed",
        xlabel = "Days",
        ylabel = "Closed state",
        linewidth = 2,
        title = "City closures under quarantine",
    )
    plot!(p3, quarantine_df.time, Int.(quarantine_df.city2_closed); label = "City 2 closed", linewidth = 2)
    plot!(p3, quarantine_df.time, Int.(quarantine_df.city3_closed); label = "City 3 closed", linewidth = 2)

    plot(p1, p2, p3; layout = (3, 1), size = (900, 1100))
    savefig(plotsdir("quarantine_effect.png"))

    println("Results saved:")
    println(datadir("quarantine_baseline.csv"))
    println(datadir("quarantine_enabled.csv"))
    println(datadir("quarantine_summary.csv"))
    println(plotsdir("quarantine_effect.png"))
end

main()
