# # Скрипт многокритериальной оптимизации параметров SIR‑модели 
# **Цель:** Найти оптимальные параметры модели распространения инфекции, минимизирующие:
# * пиковую заболеваемость (максимальную долю инфицированных);
# * смертность (долю умерших от начального населения).
# Используем многокритериальную оптимизацию с помощью пакета BlackBoxOptim.

using DrWatson
@quickactivate "project"

using BlackBoxOptim, Random, Statistics

include(srcdir("sir_model.jl"))

# ## Целевая функция: минимизируем пиковую заболеваемость и смертность
# Принимает вектор параметров `x` и возвращает кортеж из двух целевых значений:
# * доля пиковых инфицированных;
# * доля умерших от начального населения.
function cost_multi(x)
    # Параметры из вектора x:
    # x[1]: β_und — базовая заразность невыявленных носителей;
    # x[2]: detection_time — время до выявления инфекции (в днях);
    # x[3]: death_rate — вероятность смерти при выздоровлении.
    model = initialize_sir(;
        Ns = [1000, 1000, 1000],
        β_und = fill(x[1], 3),
        β_det = fill(x[1]/10, 3),
        infection_period = 14,
        detection_time = round(Int, x[2]),
        death_rate = x[3],
        reinfection_probability = 0.1,
        Is = [0, 0, 1],
        seed = 42,
        n_steps = 100,
    )    
    # Вспомогательные функции для расчёта метрик
    infected_frac(model) = count(a.status == :I for a in allagents(model)) / nagents(model)
    dead_count(model) = 3000 - nagents(model)  # начальное население — 3000 человек (3 города по 1000)
	
    peak_infected = 0.0
	
    peak_vals = Float64[]  # массив для хранения пиков заболеваемости по повторам
    dead_vals = Int[]     # массив для хранения числа смертей по повторам

    replicates = 5  # количество повторов симуляции для усреднения результатов

    for rep = 1:replicates
        # Инициализируем модель с текущими параметрами и уникальным seed для каждого повтора
        model = initialize_sir(;
            Ns = [1000, 1000, 1000],
            β_und = fill(x[1], 3),
            β_det = fill(x[1]/10, 3),  # заразность выявленных носителей в 10 раз ниже
            infection_period = 14,
            detection_time = round(Int, x[2]),  # округляем до целого числа дней
            death_rate = x[3],
            reinfection_probability = 0.1,
            Is = [0, 0, 1],  # начальное заражение в третьем городе
            seed = 42 + rep,  # уникальный seed для каждого повтора
            n_steps = 100,
        )

        # Запуск симуляции на 100 шагов (дней)
        for step = 1:100
            Agents.step!(model, 1)  # выполняем один шаг модели
            frac = infected_frac(model)  # рассчитываем текущую долю инфицированных
            if frac > peak_infected
                peak_infected = frac  # обновляем пик, если текущая доля выше
            end
        end

        # Сохраняем результаты текущего повтора
        push!(peak_vals, peak_infected)
        push!(dead_vals, dead_count(model))
    end

    # Возвращаем средние значения по всем повторам:
    # * средняя доля пиковых инфицированных;
    # * средняя доля умерших от начального населения (3000 человек).
    return (mean(peak_vals), mean(dead_vals) / 3000)
end

# ## Запуск  оптимизации
# Используем алгоритм для поиска оптимальных решений.
result = bboptimize(
    cost_multi,  # целевая функция
    Method = :borg_moea,  # метод оптимизации: Borg Multi‑Objective Evolutionary Algorithm
    FitnessScheme = ParetoFitnessScheme{2}(is_minimizing = true),  # схема оценки: минимизация двух целей
    SearchRange = [
        (0.1, 1.0),    # диапазон для β_und (0.1–1.0)
        (3.0, 14.0),   # диапазон для detection_time (3–14 дней)
        (0.01, 0.1),  # диапазон для death_rate (1–10 %)
    ],
    NumDimensions = 3,  # количество оптимизируемых параметров
    MaxTime = 120,    # максимальное время оптимизации: 2 минуты
    TraceMode = :compact,  # режим вывода прогресса (компактный)
)

# ## Извлечение лучших результатов
best = best_candidate(result)  # оптимальные значения параметров
fitness = best_fitness(result)   # достигнутые значения целевых функций

# ## Вывод результатов
println("Оптимальные параметры:")
println("β_und = $(best[1])")  # базовая заразность
println("Время выявления = $(round(Int, best[2])) дней")  # округление до целого числа дней
println("Смертность = $(best[3])")  # вероятность смерти
println("Достигнутые показатели:")
println("Пик заболеваемости: $(fitness[1])")  # доля пиковых инфицированных
println("Доля умерших: $(fitness[2])")  # доля умерших от начального населения

# Сохранение результатов

save(datadir("optimization_result.jld2"), Dict("best" => best, "fitness" => fitness))


