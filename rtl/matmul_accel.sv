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

    localparam int RC_W = (N <= 2) ? 1 : $clog2(N);

    logic [RC_W-1:0] row;
    logic [RC_W-1:0] col;
    logic [RC_W-1:0] k_idx;

    logic signed [ACC_W-1:0] accum;

    integer i;

    logic signed [2*W-1:0] product;

    always_comb begin
        product =
            $signed(a[(row * N) + k_idx]) *
            $signed(b[(k_idx * N) + col]);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy  <= 1'b0;
            done  <= 1'b0;

            row   <= '0;
            col   <= '0;
            k_idx <= '0;
            accum <= '0;

            for (i = 0; i < N*N; i = i + 1)
                c[i] <= '0;

        end else begin
            done <= 1'b0;

            if (start && !busy) begin
                busy  <= 1'b1;

                row   <= '0;
                col   <= '0;
                k_idx <= '0;
                accum <= '0;

            end else if (busy) begin

                if (k_idx == N-1) begin
                    /*
                     * Final MAC for this output element.
                     */
                    c[(row * N) + col] <=
                        accum + product;

                    accum <= '0;
                    k_idx <= '0;

                    /*
                     * Advance to next output element.
                     */
                    if (col == N-1) begin
                        col <= '0;

                        if (row == N-1) begin
                            row  <= '0;
                            busy <= 1'b0;
                            done <= 1'b1;
                        end else begin
                            row <= row + 1'b1;
                        end

                    end else begin
                        col <= col + 1'b1;
                    end

                end else begin
                    /*
                     * Continue accumulating the current dot product.
                     */
                    accum <= accum + product;
                    k_idx <= k_idx + 1'b1;
                end
            end
        end
    end

endmodule
