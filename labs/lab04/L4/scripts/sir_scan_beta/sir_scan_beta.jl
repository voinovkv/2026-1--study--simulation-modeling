using DrWatson
@quickactivate "project"

using Agents, DataFrames, Plots, CSV, Random

include(srcdir("sir_model.jl"))

function run_experiment(p)

    beta = p[:beta]
    β_und = fill(beta, 3)
    β_det = fill(beta/10, 3)

    model = initialize_sir(;
        Ns = p[:Ns],
        β_und = β_und,
        β_det = β_det,
        infection_period = p[:infection_period],
        detection_time = p[:detection_time],
        death_rate = p[:death_rate],
        reinfection_probability = p[:reinfection_probability],
        Is = p[:Is],
        seed = p[:seed],
        n_steps = p[:n_steps],  # этот параметр не используется в initialize_sir, но нужен для цикла симуляции
    )

    infected_fraction(model) =
        count(a.status == :I for a in allagents(model)) / nagents(model)

    peak_infected = 0.0  # отслеживаем максимальный уровень инфицированных за всё время симуляции

    for step = 1:p[:n_steps]

        agent_ids = collect(allids(model))
        for id in agent_ids
            agent = try
                model[id]
            catch
                nothing  # если агент удалён (умер), пропускаем его
            end
            if agent !== nothing
                sir_agent_step!(agent, model)  # обновляем состояние агента
            end
        end

        frac = infected_fraction(model)

        if frac > peak_infected
            peak_infected = frac
        end
    end

    final_infected = infected_fraction(model)  # конечная доля инфицированных
    final_recovered = count(a.status == :R for a in allagents(model)) / nagents(model)  # доля выздоровевших
    total_deaths = sum(p[:Ns]) - nagents(model)  # общее число смертей (разница между начальным и конечным населением)

    return (
        peak = peak_infected,
        final_inf = final_infected,
        final_rec = final_recovered,
        deaths = total_deaths,
    )
end

beta_range = 0.1:0.1:1.0

seeds = [42, 43, 44]

params_list = []
for b in beta_range
    for s in seeds
        push!(
            params_list,
            Dict(
                :beta => b,  # скалярное значение β, определяющее заразность
                :Ns => [1000, 1000, 1000],  # численность населения в трёх городах
                :infection_period => 14,  # длительность инфекционного периода (дней)
                :detection_time => 7,  # время до выявления инфекции (дней)
                :death_rate => 0.02,  # вероятность смерти при выздоровлении (2 %)
                :reinfection_probability => 0.1,  # вероятность повторного заражения (10 %)
                :Is => [0, 0, 1],  # начальное количество инфицированных (заражение начинается в третьем городе)
                :seed => s,  # зерно генератора случайных чисел
                :n_steps => 100,  # количество шагов симуляции (дней)
            ),
        )
    end
end

results = []
for params in params_list
    data = run_experiment(params)  # запускаем эксперимент с текущими параметрами
    push!(results, merge(params, Dict(pairs(data))))  # объединяем входные параметры и результаты
    println("Завершён эксперимент с beta = $(params[:beta]), seed = $(params[:seed])")
end

df = DataFrame(results)
CSV.write(datadir("beta_scan_all.csv"), df)

using Statistics
grouped = combine(
    groupby(df, [:beta]),  # группируем данные по значениям β
    :peak => mean => :mean_peak,  # средняя доля пика эпидемии
    :final_inf => mean => :mean_final_inf,  # средняя конечная доля инфицированных
    :deaths => mean => :mean_deaths,  # среднее число смертей
)

plot(
    grouped.beta,
    grouped.mean_peak,
    label = "Пик эпидемии",
    xlabel = "Коэффициент заразности β",
    ylabel = "Доля инфицированных",
    marker = :circle,
    linewidth = 2,
)
plot!(
    grouped.beta,
    grouped.mean_final_inf,
    label = "Конечная доля инфицированных",
    marker = :square,
)
plot!(grouped.beta, grouped.mean_deaths ./ 3000, label = "Доля умерших", marker = :diamond)
savefig(plotsdir("beta_scan.png"))

println("Результаты сохранены в data/beta_scan_all.csv и plots/beta_scan.png")
