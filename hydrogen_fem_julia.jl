include("hydrogen_fem_module.jl")
using LinearAlgebra
using Match
using Printf
using .Hydrogen_FEM

function construct()
    param = Hydrogen_FEM.Hydrogen_FEM_param("result.csv", 5000, 5000 - 1, 30.0, 0.0)
    val =  Hydrogen_FEM.Hydrogen_FEM_variables(
        zeros(param.NODE_TOTAL, param.NODE_TOTAL),
        zeros(param.ELE_TOTAL),
        zeros(param.ELE_TOTAL, 2, 2),
        zeros(param.ELE_TOTAL, 2, 2),
        zeros(param.ELE_TOTAL, 2),
        zeros(param.ELE_TOTAL, 2),
        zeros(param.NODE_TOTAL),
        zeros(param.NODE_TOTAL),
        zeros(param.NODE_TOTAL, param.NODE_TOTAL))
    
    return param, val
end

function do_run(param, val)
    # データの生成
    make_data(param, val)

    # 要素行列の生成
    make_element_matrix(param, val)

    # 全体行列を生成
    make_global_matrix(param, val)

    # 一般化固有値問題を解く
    eigenval, phi = eigen(val.hg, val.ug)
    
    # 基底状態の固有ベクトルを取り出す
    val.phi = vec(phi)[1:param.NODE_TOTAL]

    # 固有ベクトル（波動関数）を規格化
    normalize(val)

    return eigenval[1]
end

get_A_matrix_element(e, le, p, q) = let
    ed = float(e - 1);
    @match p begin
        1 =>
            @match q begin
                1 => return  0.5 * le * (ed * ed + ed + 1.0 / 3.0) - le * le * (ed / 3.0 + 1.0 / 12.0);
                2 => return -0.5 * le * (ed * ed + ed + 1.0 / 3.0) - le * le * (ed / 6.0 + 1.0 / 12.0);
                _ => return 0.0
            end

        2 =>
            @match q begin
                1 => return -0.5 * le * (ed * ed + ed + 1.0 / 3.0) - le * le * (ed / 6.0 + 1.0 / 12.0);
                2 => return 0.5 * le * (ed * ed + ed + 1.0 / 3.0) - le * le * (ed / 3.0 + 0.25);
                _ => return 0.0
            end

        _ => return 0.0
    end
end

get_B_matrix_element(e, le, p, q) = let
    ed = float(e - 1);
    @match p begin 
        1 =>
            @match q begin
                1 => return le * le * le * (ed * ed / 3.0 + ed / 6.0 + 1.0 / 30.0);
                2 => return le * le * le * (ed * ed / 6.0 + ed / 6.0 + 0.05);
                _ => return 0.0
            end

        2 =>
            @match q begin
                1 => return le * le * le * (ed * ed / 6.0 + ed / 6.0 + 0.05);
                2 => return le * le * le * (ed * ed / 3.0 + ed / 2.0 + 0.2);
                _ => return 0.0
            end
        
        _ => return 0.0
    end
end

function make_data(param, val)
    # Global節点のx座標を定義(R_MIN～R_MAX）
    dr = (param.R_MAX - param.R_MIN) / float(param.ELE_TOTAL);
    for i = 0:param.NODE_TOTAL - 1
        # 計算領域を等分割
        val.node_r_glo[i + 1] = param.R_MIN + float(i) * dr;
    end

    for e = 1:param.ELE_TOTAL
        val.nod_num_seg[e, 1] = e;
        val.nod_num_seg[e, 2] = e + 1;
    end
        
    for e = 1:param.ELE_TOTAL
        for i = 1:2
            val.node_r_ele[e, i] = val.node_r_glo[val.nod_num_seg[e, i]];
        end
    end
end

function make_element_matrix(param, val)
    # 各線分要素の長さを計算
    for e = 1:param.ELE_TOTAL
        val.length[e] = abs(val.node_r_ele[e, 2] - val.node_r_ele[e, 1]);
    end

    # 要素行列の各成分を計算
    for e = 1:param.ELE_TOTAL
        le = val.length[e];
        for i = 1:2
            for j = 1:2
                val.mat_A_ele[e, i, j] = get_A_matrix_element(e, le, i, j);
                val.mat_B_ele[e, i, j] = get_B_matrix_element(e, le, i, j);
                end
            end
        end
    end

function make_global_matrix(param, val)
    for e = 1:param.ELE_TOTAL
        for i = 1:2
            for j = 1:2
                val.hg[val.nod_num_seg[e, i], val.nod_num_seg[e, j]] += val.mat_A_ele[e, i, j];
                val.ug[val.nod_num_seg[e, i], val.nod_num_seg[e, j]] += val.mat_B_ele[e, i, j];
            end
        end
    end
end

function normalize(val)
    sum = 0.0;
    len = length(val.phi)
    max = len - 2

    # Simpsonの公式によって数値積分する
    for i = 1:2:max
        f0 = val.phi[i] * val.phi[i] * val.node_r_glo[i] * val.node_r_glo[i]
        f1 = val.phi[i + 1] * val.phi[i + 1] * val.node_r_glo[i + 1] * val.node_r_glo[i + 1]
        f2 = val.phi[i + 2] * val.phi[i + 2] * val.node_r_glo[i + 2] * val.node_r_glo[i + 2]
        
        sum += (f0 + 4.0 * f1 + f2)
    end
    
    a_1 = 1.0 / sqrt(sum * val.length[1] / 3.0);

    for i = 1:len
        val.phi[i] *= -a_1;
    end
end

save_result(val) = let
    open("result.csv", "w" ) do fp
        for i = 1:length(val.phi)
            println(fp, @sprintf "%.14f, %.14f, %.14f" val.node_r_glo[i] val.phi[i] 2.0 * exp(- val.node_r_glo[i]))
        end
    end
end
        