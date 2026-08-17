module matmul_accel #(
    parameter integer N = 4,
    parameter integer W = 8,
    parameter integer ACC_W = 2*W + $clog2(N) + 1
)(
    input  wire clk,
    input  wire rst_n,
    input  wire start,

    input  wire signed [N*N*W-1:0] a_flat,
    input  wire signed [N*N*W-1:0] b_flat,

    output reg signed [N*N*ACC_W-1:0] c_flat,
    output reg busy,
    output reg done
);

    localparam integer RC_W = (N <= 2) ? 1 : $clog2(N);

    reg [RC_W-1:0] row;
    reg [RC_W-1:0] col;
    reg [RC_W-1:0] k_idx;

    reg signed [ACC_W-1:0] accum;

    wire signed [W-1:0] a_value;
    wire signed [W-1:0] b_value;
    wire signed [2*W-1:0] product;

    /*
     * Extract the current operands from the flattened
     * row-major matrix buses.
     *
     * A[row][k]
     * B[k][col]
     */
    assign a_value =
        a_flat[((row*N + k_idx)*W) +: W];

    assign b_value =
        b_flat[((k_idx*N + col)*W) +: W];

    assign product = a_value * b_value;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            row    <= 0;
            col    <= 0;
            k_idx  <= 0;
            accum  <= 0;

            c_flat <= 0;

            busy   <= 0;
            done   <= 0;
        end
        else begin
            /*
             * done is asserted for exactly one cycle.
             */
            done <= 0;

            /*
             * Start a transaction only while idle.
             */
            if (start && !busy) begin
                row    <= 0;
                col    <= 0;
                k_idx  <= 0;
                accum  <= 0;

                busy   <= 1;
            end

            else if (busy) begin

                /*
                 * If this is the final multiplication
                 * for the current C[row][col], include
                 * the product and write the result.
                 */
                if (k_idx == N-1) begin

                    c_flat[((row*N + col)*ACC_W) +: ACC_W]
                        <= accum + product;

                    accum <= 0;
                    k_idx <= 0;

                    /*
                     * Move to the next matrix element.
                     */
                    if (col == N-1) begin
                        col <= 0;

                        if (row == N-1) begin
                            row  <= 0;
                            busy <= 0;
                            done <= 1;
                        end
                        else begin
                            row <= row + 1'b1;
                        end
                    end
                    else begin
                        col <= col + 1'b1;
                    end
                end

                /*
                 * Continue accumulating the current
                 * dot product.
                 */
                else begin
                    accum <= accum + product;
                    k_idx <= k_idx + 1'b1;
                end
            end
        end
    end

endmodule
