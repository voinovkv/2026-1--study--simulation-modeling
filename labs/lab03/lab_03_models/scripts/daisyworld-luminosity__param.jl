# Подключаем библиотеки для работы с проектом, агентным моделированием, данными и визуализацией
using DrWatson
@quickactivate "project"  # Активируем виртуальное окружение проекта "project" для воспроизводимости зависимостей
using Agents          # Библиотека для агент‑ориентированного моделирования
using DataFrames      # Работа с табличными данными (аналог pandas в Python)
using Plots           # Универсальная библиотека для построения графиков
using CairoMakie      # Высокопроизводительная библиотека для создания статических графиков
 
# Загружаем код модели Daisyworld из файла daisyworld.jl
# srcdir() (из DrWatson) формирует корректный путь к директории src/
include(srcdir("daisyworld.jl"))
 
# Определяем функции‑фильтры для подсчёта агентов по породам
# black(a) возвращает true, если агент a — «чёрная» маргаритка (breed = :black)
black(a) = a.breed == :black
# white(a) возвращает true, если агент a — «белая» маргаритка (breed = :white)
white(a) = a.breed == :white
 
# adata — список кортежей для сбора данных об агентах во время симуляции:
# (функция‑фильтр, агрегирующая функция)
# Здесь: считаем количество «чёрных» и «белых» маргариток на каждом шаге
adata = [(black, count), (white, count)]
 
## Параметры эксперимента
param_dict = Dict(
    # Размер сетки модели: 30×30 клеток
    :griddims => (30, 30),
    # Диапазон максимального возраста маргариток (будут созданы комбинации с 25 и 40)
    :max_age => [25, 40],
    # Начальное заполнение «белыми» маргаритками (20 % и 80 %)
    :init_white => [0.2, 0.8],
    # Начальное заполнение «чёрными» маргаритками (20 %)
    :init_black => 0.2,
    # Альбедо (отражательная способность) «белых» маргариток: 75 %
    :albedo_white => 0.75,
    # Альбедо «чёрных» маргариток: 25 %
    :albedo_black => 0.25,
    # Альбедо голой поверхности планеты: 40 %
    :surface_albedo => 0.4,
    # Скорость изменения солнечной светимости за шаг симуляции
    :solar_change => 0.005,
    # Начальная солнечная светимость (нормализованная единица)
    :solar_luminosity => 1.0,
    # Сценарий изменения светимости: плавный рост (ramp)
    :scenario => :ramp,
    # Фиксированное зерно ГСЧ для воспроизводимости результатов
    :seed => 165,
)
 
## Создаём список всех комбинаций параметров для перебора
# dict_list() (из DrWatson) генерирует все возможные комбинации значений параметров
# Например: (max_age=25, init_white=0.2), (max_age=25, init_white=0.8), и т. д.
params_list = dict_list(param_dict)
 
# Перебираем все комбинации параметров
for params in params_list
    # Создаём экземпляр модели Daisyworld с текущими параметрами
    # params... распаковывает словарь в ключевые аргументы функции
    model = daisyworld(; params...)
 
    # Определяем функцию для сбора средней температуры планеты на каждом шаге симуляции
    temperature(model) = StatsBase.mean(model.temperature)
    # mdata — список для сбора данных о модели:
    # temperature — средняя температура, :solar_luminosity — текущая светимость
    mdata = [temperature, :solar_luminosity]
 
    # Запускаем симуляцию на 1000 шагов
    # adata собирает данные об агентах (количество «чёрных»/«белых»)
    # mdata собирает данные о модели (температура и светимость)
    # Возвращает два DataFrame: agent_df (данные по агентам), model_df (данные по модели)
    agent_df, model_df = run!(model, 1000; adata = adata, mdata = mdata)
 
    # Создаём фигуру для графиков размером 600×600 пикселей
    figure = CairoMakie.Figure(size = (600, 600))
 
    # Верхний график: динамика количества маргариток
    ax1 = figure[1, 1] = Axis(figure, ylabel = "daisy count")
    # Красная линия: количество «чёрных» маргариток по времени
    blackl = lines!(ax1, agent_df[!, :time], agent_df[!, :count_black], color = :red)
    # Синяя линия: количество «белых» маргариток по времени
    whitel = lines!(ax1, agent_df[!, :time], agent_df[!, :count_white], color = :blue)
    # Добавляем легенду справа от графика
    figure[1, 2] = Legend(figure, [blackl, whitel], ["black", "white"])
 
    # Средний график: изменение температуры планеты
    ax2 = figure[2, 1] = Axis(figure, ylabel = "temperature")
    # Красная линия: средняя температура по времени
    lines!(ax2, model_df[!, :time], model_df[!, :temperature], color = :red)
 
    # Нижний график: изменение солнечной светимости
    ax3 = figure[3, 1] = Axis(figure, xlabel = "tick", ylabel = "luminosity")
    # Красная линия: светимость по времени
    lines!(ax3, model_df[!, :time], model_df[!, :solar_luminosity], color = :red)
 
    # Скрываем подписи оси X на верхних двух графиках для компактности
    for ax in (ax1, ax2)
        ax.xticklabelsvisible = false
    end
 
    # Генерируем имя файла на основе префикса и значений параметров
    # Например: daisy-luminosity_griddims-30x30_max_age-25_init_white-0.2.png
    plt_name = savename("daisy-luminosity", params) * ".png"
    # Сохраняем фигуру в формате PNG в директорию plots/
    save(plotsdir(plt_name), figure)
end
