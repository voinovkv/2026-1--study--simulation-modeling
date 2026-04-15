# # Визуализация динамики: Анимированная гистограмма
# В этом разделе мы создаем анимацию, которая наглядно показывает процесс 
# изменения количества фишек в различных позициях сети Петри во времени.

using DrWatson
@quickactivate "project"
include(srcdir("DiningPhilosophers.jl"))
using .DiningPhilosophers
using Plots, Random

# ## Настройка эксперимента
# Используем небольшое количество философов (N=3) для наглядности визуализации.
N = 3
tmax = 30.0
net, u0, names = build_classical_network(N)

# Фиксируем seed для воспроизводимости стохастической траектории.
Random.seed!(123)
df = simulate_stochastic(net, u0, tmax)

# ## Создание анимации
# Мы итерируемся по каждой строке DataFrame (состоянию во времени) 
# и строим столбчатую диаграмму маркировок.
anim = @animate for row in eachrow(df)
    # Извлекаем значения маркировок, исключая колонку времени
    u = [row[col] for col in propertynames(row) if col != :time]
    
    bar(
        1:length(u),
        u,
        legend = false,
        ylims = (0, maximum(u0) + 1),
        xlabel = "Позиция",
        ylabel = "Фишки",
        title = "Время = $(round(row.time, digits=2))",
    )
    # Подписываем оси именами позиций из сети Петри
    xticks!(1:length(u), string.(names), rotation = 45)
end

# Сохраняем результат в формате GIF для последующего анализа.
gif(anim, plotsdir("philosophers_simulation.gif"), fps = 2)
println("Анимация сохранена в plots/philosophers_simulation.gif")