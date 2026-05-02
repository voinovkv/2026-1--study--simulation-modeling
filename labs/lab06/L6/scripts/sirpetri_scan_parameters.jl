# # Анализ чувствительности модели SIR к коэффициенту инфицирования
# В этом разделе мы исследуем, как изменение параметра интенсивности контактов (β)
# влияет на критические показатели эпидемии: пиковую нагрузку на систему здравоохранения
# и общий масштаб заражения.

using DrWatson
@quickactivate "project"
include(srcdir("SIRPetri.jl"))
using .SIRPetri
using DataFrames, CSV, Plots

# ## 1. Определение пространства параметров
# Мы фиксируем скорость выздоровления γ и рассматриваем диапазон значений β,
# чтобы увидеть переход от затухающей эпидемии к масштабной вспышке.
β_range = 0.1:0.05:0.8
γ_fixed = 0.1
tmax = 100.0

# ## 2. Выполнение итерационного сканирования
# Для каждого значения β мы строим сеть Петри, запускаем детерминированную симуляцию
# и извлекаем ключевые метрики: максимум инфицированных (Peak I) и конечное число переболевших (Final R).
results = []
for β in β_range
    net, u0, _ = build_sir_network(β, γ_fixed)
    df = simulate_deterministic(net, u0, (0.0, tmax), saveat = 0.5, rates = [β, γ_fixed])
    
    peak_I = maximum(df.I)
    final_R = df.R[end]
    push!(results, (β = β, peak_I = peak_I, final_R = final_R))
end

# ## 3. Сохранение данных
# Результаты агрегируются в таблицу для последующего анализа и воспроизводимости.
df_scan = DataFrame(results)
CSV.write(datadir("sir_scan.csv"), df_scan)

# ## 4. Визуализация результатов
# Построение графика позволяет наглядно увидеть нелинейную зависимость 
# эпидемических показателей от параметров модели.
p = plot(
    df_scan.β,
    [df_scan.peak_I df_scan.final_R],
    label = ["Peak I" "Final R"],
    marker = :circle,
    xlabel = "β (infection rate)",
    ylabel = "Population",
)
savefig(plotsdir("sir_scan.png"))

println("Сканирование β завершено. Результат в data/sir_scan.csv")