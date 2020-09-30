include("hydrogen_fem_julia.jl")
using Printf

function main()
    param, val = construct()
    eigenval = do_run(param, val)

    @printf "計算が終わりました: 基底状態のエネルギー固有値E = %.14f (Hartree)\n" eigenval
    save_result(val)
    @printf "計算結果を%sに書き込みました\n" param.RESULT_FILENAME
end
@time main()