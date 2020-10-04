module Hydrogen_FEM
    struct Hydrogen_FEM_param
        RESULT_FILENAME::String
        NODE_TOTAL::Int64
        ELE_TOTAL::Int64
        R_MAX::Float64
        R_MIN::Float64
    end

    mutable struct Hydrogen_FEM_variables
        hg::Array{Float64, 2}
        length::Array{Float64, 1}
        mat_A_ele::Array{Float64, 3}
        mat_B_ele::Array{Float64, 3}
        node_num_seg::Array{Int64, 2}
        node_r_ele::Array{Float64, 2}
        node_r_glo::Array{Float64, 1}
        phi::Array{Float64, 1}
        ug::Array{Float64, 2}
    end
end