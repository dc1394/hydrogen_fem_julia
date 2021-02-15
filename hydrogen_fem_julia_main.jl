include("hydrogen_fem_julia.jl")
using Printf
using .Hydrogen_FEM
#using Plots

function main()
    param, val = Hydrogen_FEM.construct()
    eigenval = Hydrogen_FEM.do_run(param, val)

    @printf "計算が終わりました: 基底状態のエネルギー固有値E = %.14f (Hartree)\n" eigenval[1]
    Hydrogen_FEM.save_result(param, eigenval, val)
    @printf "計算結果を%sと%sに書き込みました\n" param.EIGENFUNC_FILENAME param.EIGENVAL_FILENAME 
    #plot(val.node_r_glo, val.phi)
end
@time main()