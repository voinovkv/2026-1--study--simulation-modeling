# # Финальный анализ и визуализация результатов моделирования
# В этом разделе мы консолидируем данные, полученные в ходе предыдущих экспериментов,
# чтобы провести сравнительный анализ и оценить чувствительность модели.

using DrWatson
@quickactivate "project"
using DataFrames, CSV, Plots

# ## 1. Загрузка данных
# Мы считываем результаты детерминированного, стохастического и параметрического моделирования
# из соответствующих CSV файлов в директории данных.
df_det = CSV.read(datadir("sir_det.csv"), DataFrame)
df_stoch = CSV.read(datadir("sir_stoch.csv"), DataFrame)
df_scan = CSV.read(datadir("sir_scan.csv"), DataFrame)

# ## 2. Сравнение динамики
# Первым шагом мы визуализируем разницу между плавным детерминированным прогнозом
# и случайными колебаниями стохастической траектории во времени.
p1 = plot(
    df_det.time,
    [df_det.I df_stoch.I[1:length(df_det.time)]],
    label = ["Deterministic I" "Stochastic I"],
    xlabel = "Time",
    ylabel = "Infected",
    title = "Comparison",
)
savefig(plotsdir("comparison.png"))

# ## 3. Анализ чувствительности
# На основе данных сканирования параметров мы строим зависимость пиковой нагрузки
# от коэффициента инфицирования β, чтобы определить критические пороги.
p2 = plot(
    df_scan.β,
    df_scan.peak_I,
    marker = :circle,
    xlabel = "β",
    ylabel = "Peak I",
    title = "Sensitivity",
)
savefig(plotsdir("sensitivity.png"))

println("Отчётные графики сохранены в plots/")