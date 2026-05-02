# # Моделирование эпидемической динамики (SIR)
# В данном блокноте мы исследуем распространение инфекции, используя аппарат сетей Петри
# и библиотеку DrWatson для управления проектом.

using DrWatson
@quickactivate "project"
using Random
include(srcdir("SIRPetri.jl"))
using .SIRPetri
using DataFrames, CSV, Plots

# ## 1. Инициализация параметров
# Мы определяем интенсивность контактов (β) и скорость выздоровления (γ),
# а также временной горизонт моделирования.
β = 0.3
γ = 0.1
tmax = 100.0

# ## 2. Построение структуры модели
# На основе параметров создается сеть Петри, начальное состояние популяций (u0)
# и список состояний (S, I, R).
net, u0, states = build_sir_network(β, γ)

# ## 3. Детерминированное моделирование
# Решаем систему обыкновенных дифференциальных уравнений (ODE) для получения усредненной динамики.
df_det = simulate_deterministic(net, u0, (0.0, tmax), saveat = 0.5, rates = [β, γ])
CSV.write(datadir("sir_det.csv"), df_det)

# ## 4. Стохастическое моделирование
# Проводим симуляцию методом Монте-Карло (алгоритм Гиллеспи) для учета случайных факторов.
Random.seed!(123)
df_stoch = simulate_stochastic(net, u0, (0.0, tmax), rates = [β, γ])
CSV.write(datadir("sir_stoch.csv"), df_stoch)

# ## 5. Визуализация и сохранение результатов
# Построение графиков для сравнения двух подходов и экспорт изображений в директорию plots.
p_det = plot_sir(df_det)
savefig(plotsdir("sir_det_dynamics.png"))

p_stoch = plot_sir(df_stoch)
savefig(plotsdir("sir_stoch_dynamics.png"))

println("Базовый прогон завершён. Результаты в data/ и plots/")