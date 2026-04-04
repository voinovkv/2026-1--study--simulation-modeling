using DrWatson
@quickactivate "project"
using Agents, DataFrames, Plots, CSV, Random

include(srcdir("sir_model.jl"))

function create_migration_matrix(C, intensity)
    M = ones(C, C) .* intensity ./ (C-1)
    for i = 1:C
        M[i, i] = 1 - intensity
    end
    return M
end

function peak_time(p)

    migration_rates = create_migration_matrix(p[:C], p[:migration_intensity])

    model = initialize_sir(;
        Ns = p[:Ns],
        β_und = p[:β_und],
        β_det = p[:β_det],
        infection_period = p[:infection_period],
        detection_time = p[:detection_time],
        death_rate = p[:death_rate],
        reinfection_probability = p[:reinfection_probability],
        Is = p[:Is],
        seed = p[:seed],
        migration_rates = migration_rates,
    )

    infected_frac(model) = count(a.status == :I for a in allagents(model)) / nagents(model)

    peak = 0.0        # отслеживаем максимальную долю инфицированных
    peak_step = 0    # запоминаем шаг, на котором достигнут пик

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

        frac = infected_frac(model)

        if frac > peak
            peak = frac
            peak_step = step
        end
    end

    return (peak_time = peak_step, peak_value = peak)
end

migration_intensities = 0.0:0.1:0.5

seeds = [42, 43, 44]

params_list = []
for mig in migration_intensities
    for s in seeds
        push!(
            params_list,
            Dict(
                :migration_intensity => mig,  # скаляр, определяющий общую интенсивность миграции
                :C => 3,  # количество городов в системе
                :Ns => [1000, 1000, 1000],  # численность населения в каждом городе
                :β_und => [0.5, 0.5, 0.5],  # вероятность передачи инфекции невыявленными носителями
                :β_det => [0.05, 0.05, 0.05],  # вероятность передачи выявленными носителями (в 10 раз меньше)
                :infection_period => 14,  # длительность инфекционного периода (дней)
                :detection_time => 7,  # время до выявления инфекции (дней)
                :death_rate => 0.02,  # вероятность смерти при выздоровлении (2 %)
                :reinfection_probability => 0.1,  # вероятность повторного заражения (10 %)
                :Is => [1, 0, 0],  # начальное количество инфицированных (заражение начинается в первом городе)
                :seed => s,  # зерно генератора случайных чисел
                :n_steps => 150,  # количество шагов симуляции (дней)
            ),
        )
    end
end

results = []
for params in params_list
    data = peak_time(params)  # запускаем эксперимент с текущими параметрами
    push!(results, merge(params, Dict(pairs(data))))  # объединяем входные параметры и результаты
    println(
        "Завершён эксперимент с migration_intensity = $(params[:migration_intensity]), seed = $(params[:seed])",
    )
end

df = DataFrame(results)
CSV.write(datadir("migration_scan_all.csv"), df)

using Statistics
grouped = combine(
    groupby(df, [:migration_intensity]),  # группируем данные по значениям интенсивности миграции
    :peak_time => mean => :mean_peak_time,  # среднее время достижения пика (дни)
    :peak_value => mean => :mean_peak_value,  # средняя доля инфицированных в пике
)

plot(
    grouped.migration_intensity,
    grouped.mean_peak_time,
    marker = :circle,
    xlabel = "Интенсивность миграции",
    ylabel = "Время до пика (дни)",
    label = "Время пика",
    legend = :topright,
    lw = 2
)
plot!(
    grouped.migration_intensity,
    grouped.mean_peak_value .* 3000,
    marker = :square,
    ylabel = "Численность в пике (чел.)",
    label = "Пиковая заболеваемость",
    lw = 2
)
savefig(plotsdir("migration_effect.png"))

println("Результаты сохранены в data/migration_scan_all.csv и plots/migration_effect.png")
