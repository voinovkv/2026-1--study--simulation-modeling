using Agents
using Random
using Graphs: complete_graph
using StatsBase: sample, Weights
using Distributions: Poisson
using DrWatson: @dict

@agent struct QuarantinePerson(GraphAgent)
    days_infected::Int
    status::Symbol
end

function initialize_sir_quarantine(;
    Ns = [1000, 1000, 1000],
    migration_rates = nothing,
    β_und = [0.5, 0.5, 0.5],
    β_det = [0.05, 0.05, 0.05],
    infection_period = 14,
    detection_time = 7,
    death_rate = 0.02,
    reinfection_probability = 0.1,
    quarantine_threshold = 0.1,
    Is = [0, 0, 1],
    seed = 42,
    n_steps = 100,
)
    rng = Xoshiro(seed)
    C = length(Ns)

    if migration_rates === nothing
        migration_rates = zeros(C, C)
        for i in 1:C
            for j in 1:C
                migration_rates[i, j] = (Ns[i] + Ns[j]) / Ns[i]
            end
        end
        for i in 1:C
            migration_rates[i, :] ./= sum(migration_rates[i, :])
        end
    end

    properties = @dict(
        Ns,
        β_und,
        β_det,
        migration_rates,
        infection_period,
        detection_time,
        death_rate,
        reinfection_probability,
        quarantine_threshold,
        C,
        n_steps,
    )

    space = GraphSpace(complete_graph(C))
    model = StandardABM(
        QuarantinePerson,
        space;
        properties,
        rng,
        agent_step! = sir_quarantine_agent_step!,
    )

    for city in 1:C
        for _ in 1:Ns[city]
            add_agent!(city, model, 0, :S)
        end
    end

    for city in 1:C
        if Is[city] > 0
            city_agents = ids_in_position(city, model)
            infected_ids = sample(rng, city_agents, Is[city]; replace = false)
            for id in infected_ids
                agent = model[id]
                agent.status = :I
                agent.days_infected = 1
            end
        end
    end

    return model
end

function sir_quarantine_agent_step!(agent, model)
    migrate_with_quarantine!(agent, model)
    if agent.status == :I
        transmit_with_quarantine!(agent, model)
        agent.days_infected += 1
    end
    recover_or_die_with_quarantine!(agent, model)
end

function infected_fraction_in_city(model, city)
    city_agents = collect(agents_in_position(city, model))
    isempty(city_agents) && return 0.0
    infected = count(a.status == :I for a in city_agents)
    return infected / length(city_agents)
end

function city_is_closed(model, city)
    return infected_fraction_in_city(model, city) >= model.quarantine_threshold
end

function migrate_with_quarantine!(agent, model)
    current_city = agent.pos
    if city_is_closed(model, current_city)
        return nothing
    end

    probs = model.migration_rates[current_city, :]
    target = sample(abmrng(model), 1:model.C, Weights(probs))
    if target != current_city
        move_agent!(agent, target, model)
    end
end

function transmit_with_quarantine!(agent, model)
    rate = if agent.days_infected < model.detection_time
        model.β_und[agent.pos]
    else
        model.β_det[agent.pos]
    end

    n_infections = rand(abmrng(model), Poisson(rate))
    n_infections == 0 && return nothing

    neighbors = [a for a in agents_in_position(agent.pos, model) if a.id != agent.id]
    shuffle!(abmrng(model), neighbors)

    for contact in neighbors
        if contact.status == :S
            contact.status = :I
            contact.days_infected = 1
            n_infections -= 1
            n_infections == 0 && return nothing
        elseif contact.status == :R && rand(abmrng(model)) <= model.reinfection_probability
            contact.status = :I
            contact.days_infected = 1
            n_infections -= 1
            n_infections == 0 && return nothing
        end
    end
end

function recover_or_die_with_quarantine!(agent, model)
    if agent.status == :I && agent.days_infected >= model.infection_period
        if rand(abmrng(model)) <= model.death_rate
            remove_agent!(agent, model)
        else
            agent.status = :R
            agent.days_infected = 0
        end
    end
end

infected_count_quarantine(model) = count(a.status == :I for a in allagents(model))
recovered_count_quarantine(model) = count(a.status == :R for a in allagents(model))
susceptible_count_quarantine(model) = count(a.status == :S for a in allagents(model))
total_count_quarantine(model) = nagents(model)
