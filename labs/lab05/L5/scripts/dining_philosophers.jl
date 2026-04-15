# # Сценарий моделирования: Обедающие философы
# В данном разделе мы проводим сравнительный анализ двух конфигураций сети Петри:
# 1. Классическая сеть, где возможна ситуация взаимной блокировки (deadlock).
# 2. Сеть с арбитром, ограничивающим число одновременно голодных философов.

using DrWatson
@quickactivate "project"
include(srcdir("DiningPhilosophers.jl"))
using .DiningPhilosophers
using DataFrames, CSV, Plots

# Параметры эксперимента
N = 5
tmax = 50.0

# ## 1. Классическая конфигурация
# Попытаемся смоделировать поведение философов без внешнего контроля.
println("=== Классическая сеть (без арбитра) ===")
net_classic, u0_classic, _ = build_classical_network(N)
df_classic = simulate_stochastic(net_classic, u0_classic, tmax)

# Сохранение результатов и проверка на тупиковые состояния
CSV.write(datadir("dining_classic.csv"), df_classic)
dead = detect_deadlock(df_classic, net_classic)
println("Deadlock обнаружен: $dead")

# Визуализация динамики маркировок
plot_classic = plot_marking_evolution(df_classic, N)
savefig(plotsdir("classic_simulation.png"))

# ## 2. Конфигурация с Арбитром
# Вводим дополнительную позицию-ограничитель, которая не позволяет всем 
# философам одновременно взять по одной вилке.
println("\n=== Сеть с арбитром ===")
net_arb, u0_arb, _ = build_arbiter_network(N)
df_arb = simulate_stochastic(net_arb, u0_arb, tmax)

CSV.write(datadir("dining_arbiter.csv"), df_arb)
dead_arb = detect_deadlock(df_arb, net_arb)
println("Deadlock обнаружен: $dead_arb")

plot_arb = plot_marking_evolution(df_arb, N)
savefig(plotsdir("arbiter_simulation.png"))