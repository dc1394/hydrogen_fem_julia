module Hydrogen_FEM
    include("hydrogen_fem_module.jl")
    using LinearAlgebra
    using Match
    using MKL
    using Printf
    using .Hydrogen_FEM_module

    const NODE_TOTAL = 10000

    function construct()
        param = Hydrogen_FEM_module.Hydrogen_FEM_param("eigenfunc.csv", "eigenval.csv", NODE_TOTAL, NODE_TOTAL - 1, 1000.0, 0.0)
        val = Hydrogen_FEM_module.Hydrogen_FEM_variables(
            Symmetric(zeros(param.ELE_TOTAL, param.ELE_TOTAL)),
            Array{Float64}(undef, param.ELE_TOTAL),
            Array{Float64, 3}(undef, param.ELE_TOTAL, 2, 2),
            Array{Float64, 3}(undef, param.ELE_TOTAL, 2, 2),
            Array{Int64, 2}(undef, param.ELE_TOTAL, 2),
            Array{Float64, 2}(undef, param.ELE_TOTAL, 2),
            Array{Float64}(undef, param.NODE_TOTAL),
            Array{Float64}(undef, param.NODE_TOTAL),
            Symmetric(zeros(param.ELE_TOTAL, param.ELE_TOTAL)))
        
        return param, val
    end

    function do_run(param, val)
        # データの生成
        make_data!(param, val)

        # 要素行列の生成
        make_element_matrix!(param, val)

        # 全体行列を生成
        hg_tmp, ug_tmp = make_global_matrix(param, val)

        # 境界条件処理を行う
        boundary_conditions!(param, val, hg_tmp, ug_tmp)

        # 一般化固有値問題を解く
        eigenval, phi = eigen!(val.hg, val.ug)
        
        # 基底状態の固有ベクトルを取り出す
        val.phi = @view(phi[:,1])

        # 固有ベクトルの要素数を増やす
        resize!(val.phi, NODE_TOTAL)

        # 端点rcでの値を0にする
        val.phi[NODE_TOTAL] = 0.0

        # 固有ベクトル（波動関数）を規格化
        normalize!(val)

        return eigenval
    end

    save_result(param, eigenval, val) = let
        open(param.EIGENFUNC_FILENAME, "w" ) do fp
            for i = 1:length(val.phi)
                println(fp, @sprintf "%.14f, %.14f, %.14f" val.node_r_glo[i] val.phi[i] 2.0 * exp(- val.node_r_glo[i]))
            end
        end

        open(param.EIGENVAL_FILENAME, "w" ) do fp
            for i = 1:length(eigenval)
                println(fp, @sprintf "%d, %.14f, %.14f" i eigenval[i] -0.5 * 1.0 / float(i * i))
            end
        end
    end

    function boundary_conditions!(param, val, hg_tmp, ug_tmp)
        @inbounds for i = 1:param.ELE_TOTAL
            for j = i - 1:i + 1
                if j != 0 && j != param.NODE_TOTAL
                    # 左辺の全体行列のN行とN列を削る
                    val.hg.data[j, i] = hg_tmp.data[j, i]

                    # 右辺の全体行列のN行とN列を削る    
                    val.ug.data[j, i] = ug_tmp.data[j, i]
                end
            end
        end
    end

    get_A_matrix_element(e, le, p, q) = let
        ed = float(e - 1)
        @match p begin
            1 =>
                @match q begin
                    1 => return  0.5 * le * (ed * ed + ed + 1.0 / 3.0) - le * le * (ed / 3.0 + 1.0 / 12.0)
                    2 => return -0.5 * le * (ed * ed + ed + 1.0 / 3.0) - le * le * (ed / 6.0 + 1.0 / 12.0)
                    _ => return 0.0
                end

            2 =>
                @match q begin
                    2 => return 0.5 * le * (ed * ed + ed + 1.0 / 3.0) - le * le * (ed / 3.0 + 0.25)
                    _ => return 0.0
                end

            _ => return 0.0
        end
    end

    get_B_matrix_element(e, le, p, q) = let
        ed = float(e - 1)
        @match p begin 
            1 =>
                @match q begin
                    1 => return le * le * le * (ed * ed / 3.0 + ed / 6.0 + 1.0 / 30.0)
                    2 => return le * le * le * (ed * ed / 6.0 + ed / 6.0 + 0.05)
                    _ => return 0.0
                end

            2 =>
                @match q begin
                    2 => return le * le * le * (ed * ed / 3.0 + ed / 2.0 + 0.2)
                    _ => return 0.0
                end
            
            _ => return 0.0
        end
    end

    function make_data!(param, val)
        # Global節点のx座標を定義(R_MIN～R_MAX）
        dr = (param.R_MAX - param.R_MIN) / float(param.ELE_TOTAL)
        @inbounds for i = 0:param.NODE_TOTAL - 1
            # 計算領域を等分割
            val.node_r_glo[i + 1] = param.R_MIN + float(i) * dr
        end

        @inbounds for e = 1:param.ELE_TOTAL
            val.node_num_seg[e, 1] = e
            val.node_num_seg[e, 2] = e + 1
        end
            
        @inbounds for e = 1:param.ELE_TOTAL
            for i = 1:2
                val.node_r_ele[e, i] = val.node_r_glo[val.node_num_seg[e, i]]
            end
        end
    end

    function make_element_matrix!(param, val)
        # 各線分要素の長さを計算
        @inbounds for e = 1:param.ELE_TOTAL
            val.length[e] = abs(val.node_r_ele[e, 2] - val.node_r_ele[e, 1])
        end

        # 要素行列の各成分を計算
        @inbounds for e = 1:param.ELE_TOTAL
            le = val.length[e]
            for j = 1:2
                for i = 1:j
                    val.mat_A_ele[e, i, j] = get_A_matrix_element(e, le, i, j)
                    val.mat_B_ele[e, i, j] = get_B_matrix_element(e, le, i, j)
                    end
                end
            end
        end

    function make_global_matrix(param, val)
        hg_tmp = Symmetric(zeros(param.NODE_TOTAL, param.NODE_TOTAL))
        ug_tmp = Symmetric(zeros(param.NODE_TOTAL, param.NODE_TOTAL))

        @inbounds for e = 1:param.ELE_TOTAL
            for j = 1:2
                for i = 1:j
                    hg_tmp.data[val.node_num_seg[e, i], val.node_num_seg[e, j]] += val.mat_A_ele[e, i, j]
                    ug_tmp.data[val.node_num_seg[e, i], val.node_num_seg[e, j]] += val.mat_B_ele[e, i, j]
                end
            end
        end

        return hg_tmp, ug_tmp
    end

    function normalize!(val)
        sum = 0.0
        max = length(val.phi) - 2

        # Simpsonの公式によって数値積分する
        @inbounds @simd for i = 1:2:max
            f0 = val.phi[i] * val.phi[i] * val.node_r_glo[i] * val.node_r_glo[i]
            f1 = val.phi[i + 1] * val.phi[i + 1] * val.node_r_glo[i + 1] * val.node_r_glo[i + 1]
            f2 = val.phi[i + 2] * val.phi[i + 2] * val.node_r_glo[i + 2] * val.node_r_glo[i + 2]
            
            sum += (f0 + 4.0 * f1 + f2)
        end
        
        val.phi = map(x -> abs(x / sqrt(sum * val.length[1] / 3.0)), val.phi)
    end
end
