module matmul_accel #(
    parameter int N = 4,
    parameter int W = 8,
    parameter int ACC_W = 2*W + $clog2(N) + 1
)(
    input  logic clk,
    input  logic rst_n,
    input  logic start,
    input  logic signed [W-1:0] a [0:N*N-1],
    input  logic signed [W-1:0] b [0:N*N-1],
    output logic signed [ACC_W-1:0] c [0:N*N-1],
    output logic busy,
    output logic done
);
    localparam int IDX_W = (N*N <= 2) ? 1 : $clog2(N*N);
    logic [IDX_W-1:0] out_idx;
    logic signed [ACC_W-1:0] dot_comb;
    integer k;
    integer row_i, col_i;

    always_comb begin
        row_i = out_idx / N;
        col_i = out_idx % N;
        dot_comb = '0;
        for (k = 0; k < N; k = k + 1)
            dot_comb = dot_comb + $signed(a[row_i*N+k]) * $signed(b[k*N+col_i]);
    end

    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy <= 1'b0;
            done <= 1'b0;
            out_idx <= '0;
            for (i = 0; i < N*N; i = i + 1) c[i] <= '0;
        end else begin
            done <= 1'b0;
            if (start && !busy) begin
                busy <= 1'b1;
                out_idx <= '0;
            end else if (busy) begin
                c[out_idx] <= dot_comb;
                if (out_idx == N*N-1) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end else begin
                    out_idx <= out_idx + 1'b1;
                end
            end
        end
    end
endmodule
