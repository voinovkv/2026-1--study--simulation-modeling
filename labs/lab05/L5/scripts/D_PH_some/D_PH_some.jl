using DrWatson
@quickactivate "project"
include(srcdir("DiningPhilosophers.jl"))
using .DiningPhilosophers
using DataFrames, CSV, Plots

Ns = [3, 5, 10]
tmax = 50.0

for N in Ns
    println("\n--- Тестирование для N = $N философов ---")

    println("=== Классическая сеть (N=$N) ===")
    net_classic, u0_classic, _ = build_classical_network(N)
    df_classic = simulate_stochastic(net_classic, u0_classic, tmax)

    CSV.write(datadir("dining_classic_N$N.csv"), df_classic)
    dead = detect_deadlock(df_classic, net_classic)
    println("Deadlock обнаружен (Классика): $dead")

    plot_classic = plot_marking_evolution(df_classic, N)
    savefig(plotsdir("classic_simulation_N$N.png"))

    println("=== Сеть с арбитром (N=$N) ===")
    net_arb, u0_arb, _ = build_arbiter_network(N)
    df_arb = simulate_stochastic(net_arb, u0_arb, tmax)

    CSV.write(datadir("dining_arbiter_N$N.csv"), df_arb)
    dead_arb = detect_deadlock(df_arb, net_arb)
    println("Deadlock обнаружен (Арбитр): $dead_arb")

    plot_arb = plot_marking_evolution(df_arb, N)
    savefig(plotsdir("arbiter_simulation_N$N.png"))
end
