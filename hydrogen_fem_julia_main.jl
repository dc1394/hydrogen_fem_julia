include("hydrogen_fem_julia.jl")
using Printf
using .Hydrogen_FEM
#using Plots

function main()
    param, val = Hydrogen_FEM.construct()
    eigenval = Hydrogen_FEM.do_run(param, val)

    @printf "計算が終わりました: 基底状態のエネルギー固有値E = %.14f (Hartree)\n" eigenval
    Hydrogen_FEM.save_result(val)
    @printf "計算結果を%sに書き込みました\n" param.RESULT_FILENAME
    #plot(val.node_r_glo, val.phi)
end
@time main()