# # Финальный отчет: Сравнительный анализ
# В завершение мы сопоставим результаты двух симуляций. Нас интересует
# состояние "Eat" (философ ест), которое наглядно демонстрирует наличие
# или отсутствие прогресса в системе.

using DrWatson
@quickactivate "project"
using DataFrames, CSV, Plots

# ## Загрузка данных
# Мы считываем результаты, сохраненные на этапе моделирования.
df_classic = CSV.read(datadir("dining_classic.csv"), DataFrame)
df_arbiter = CSV.read(datadir("dining_arbiter.csv"), DataFrame)
N = 5

# Столбцы для состояния "Ест"
eat_cols = [Symbol("Eat_$i") for i = 1:N]

# ## Построение графиков
# Мы создаем два подграфика: один для классической сети, где мы ожидаем 
# увидеть прекращение активности при дедлоке, и второй для сети с арбитром.

p1 = plot(
    df_classic.time,
    Matrix(df_classic[:, eat_cols]),
    label = ["Ф $i" for i = 1:N],
    xlabel = "Время",
    ylabel = "Ест (1/0)",
    title = "Классическая сеть",
)

p2 = plot(
    df_arbiter.time,
    Matrix(df_arbiter[:, eat_cols]),
    label = ["Ф $i" for i = 1:N],
    xlabel = "Время",
    ylabel = "Ест (1/0)",
    title = "Сеть с арбитром",
)

# Объединяем графики в единый отчет для финального сравнения.
p_final = plot(p1, p2, layout = (2, 1), size = (800, 600))
savefig(plotsdir("final_report.png"))

println("Отчёт сохранён в plots/final_report.png")