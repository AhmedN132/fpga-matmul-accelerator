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

    logic signed [ACC_W-1:0] dot_product;

    integer k;
    integer i;

    /*
     * Combinational dot-product datapath.
     *
     * One output matrix element is calculated per clock cycle:
     *
     * C[row][col] =
     *     sum(A[row][k] * B[k][col])
     */
    always_comb begin
        dot_product = '0;

        for (k = 0; k < N; k = k + 1) begin
            dot_product =
                dot_product
                + $signed(a[(row * N) + k])
                * $signed(b[(k * N) + col]);
        end
    end


    /*
     * Control logic.
     *
     * start:
     *   Begins a new matrix multiplication when idle.
     *
     * busy:
     *   Remains asserted while output elements are generated.
     *
     * done:
     *   Pulses for one clock cycle after the final element is written.
     */
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            busy <= 1'b0;
            done <= 1'b0;

            row <= '0;
            col <= '0;

            for (i = 0; i < N*N; i = i + 1) begin
                c[i] <= '0;
            end

        end else begin

            /* done is a one-cycle pulse */
            done <= 1'b0;

            /*
             * Accept start only while idle.
             * A start request while busy is ignored.
             */
            if (start && !busy) begin

                busy <= 1'b1;

                row <= '0;
                col <= '0;

            end

            else if (busy) begin

                /*
                 * Store the current output matrix element.
                 */
                c[(row * N) + col] <= dot_product;

                /*
                 * Advance through the output matrix.
                 */
                if (col == N-1) begin

                    col <= '0;

                    if (row == N-1) begin

                        /*
                         * Final output element completed.
                         */
                        row <= '0;
                        busy <= 1'b0;
                        done <= 1'b1;

                    end else begin

                        row <= row + 1'b1;

                    end

                end else begin

                    col <= col + 1'b1;

                end
            end
        end
    end

endmodule
