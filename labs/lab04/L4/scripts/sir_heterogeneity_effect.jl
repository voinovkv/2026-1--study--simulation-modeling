using DrWatson
@quickactivate "L4"
@quickactivate "project"
using Agents
using DataFrames
using Plots
using CSV

include(srcdir("sir_model.jl"))

function count_status_in_city(model, city, status)
    return count(a.status == status && a.pos == city for a in allagents(model))
end

function main()
    params = Dict(
        :Ns => [1000, 1000, 1000],
        :β_und => [0.3, 0.5, 0.8],
        :β_det  => [0.03, 0.05, 0.08],
        :infection_period => 14,
        :detection_time => 7,
        :death_rate => 0.02,
        :reinfection_probability => 0.1,
        :Is => [0, 0, 1],
        :seed => 42,
        :n_steps => 120,
    )

    model = initialize_sir(; params...)

    times = Int[]

    S_city1 = Int[]
    I_city1 = Int[]
    R_city1 = Int[]

    S_city2 = Int[]
    I_city2 = Int[]
    R_city2 = Int[]

    S_city3 = Int[]
    I_city3 = Int[]
    R_city3 = Int[]

    peak_city1 = 0
    peak_city2 = 0
    peak_city3 = 0

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

        s1 = count_status_in_city(model, 1, :S)
        i1 = count_status_in_city(model, 1, :I)
        r1 = count_status_in_city(model, 1, :R)
        push!(S_city1, s1)
        push!(I_city1, i1)
        push!(R_city1, r1)
        peak_city1 = max(peak_city1, i1)

        s2 = count_status_in_city(model, 2, :S)
        i2 = count_status_in_city(model, 2, :I)
        r2 = count_status_in_city(model, 2, :R)
        push!(S_city2, s2)
        push!(I_city2, i2)
        push!(R_city2, r2)
        peak_city2 = max(peak_city2, i2)

        s3 = count_status_in_city(model, 3, :S)
        i3 = count_status_in_city(model, 3, :I)
        r3 = count_status_in_city(model, 3, :R)
        push!(S_city3, s3)
        push!(I_city3, i3)
        push!(R_city3, r3)
        peak_city3 = max(peak_city3, i3)
    end

    df = DataFrame(
        time = times,
        S_city1 = S_city1,
        I_city1 = I_city1,
        R_city1 = R_city1,
        S_city2 = S_city2,
        I_city2 = I_city2,
        R_city2 = R_city2,
        S_city3 = S_city3,
        I_city3 = I_city3,
        R_city3 = R_city3,
    )

    CSV.write(datadir("heterogeneity_dynamics.csv"), df)

    p1 = plot(
        df.time,
        df.I_city1;
        label = "City 1",
        xlabel = "Days",
        ylabel = "Infected",
        title = "Infected dynamics by city",
        linewidth = 2,
    )
    plot!(p1, df.time, df.I_city2; label = "City 2", linewidth = 2)
    plot!(p1, df.time, df.I_city3; label = "City 3", linewidth = 2)

    p2 = plot(
        df.time,
        df.S_city1;
        label = "City 1",
        xlabel = "Days",
        ylabel = "Susceptible",
        title = "Susceptible dynamics by city",
        linewidth = 2,
    )
    plot!(p2, df.time, df.S_city2; label = "City 2", linewidth = 2)
    plot!(p2, df.time, df.S_city3; label = "City 3", linewidth = 2)

    p3 = plot(
        df.time,
        df.R_city1;
        label = "City 1",
        xlabel = "Days",
        ylabel = "Recovered",
        title = "Recovered dynamics by city",
        linewidth = 2,
    )
    plot!(p3, df.time, df.R_city2; label = "City 2", linewidth = 2)
    plot!(p3, df.time, df.R_city3; label = "City 3", linewidth = 2)

    plot(p1, p2, p3; layout = (3, 1), size = (900, 1100))
    savefig(plotsdir("heterogeneity_effect.png"))

    summary_df = DataFrame(
        city = [1, 2, 3],
        β_und = params[:β_und],
        β_det = params[:β_det],
        peak_infected = [peak_city1, peak_city2, peak_city3],
    )

    CSV.write(datadir("heterogeneity_summary.csv"), summary_df)

    println("Results saved:")
    println(datadir("heterogeneity_dynamics.csv"))
    println(datadir("heterogeneity_summary.csv"))
    println(plotsdir("heterogeneity_effect.png"))
end

main()
