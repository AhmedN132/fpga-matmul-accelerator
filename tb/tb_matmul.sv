`timescale 1ns/1ps

module tb_matmul;

    localparam integer N = 4;
    localparam integer W = 8;
    localparam integer ACC_W = 2*W + $clog2(N) + 1;

    reg clk;
    reg rst_n;
    reg start;

    wire busy;
    wire done;

    /*
     * Human-friendly matrices used by the testbench.
     */
    reg signed [W-1:0] a [0:N*N-1];
    reg signed [W-1:0] b [0:N*N-1];

    /*
     * Flattened buses connected to the DUT.
     */
    reg signed [N*N*W-1:0] a_flat;
    reg signed [N*N*W-1:0] b_flat;

    wire signed [N*N*ACC_W-1:0] c_flat;

    integer r;
    integer col;
    integer k;
    integer i;
    integer t;
    integer exp;

    reg signed [ACC_W-1:0] actual;


    matmul_accel #(
        .N(N),
        .W(W),
        .ACC_W(ACC_W)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),

        .a_flat(a_flat),
        .b_flat(b_flat),

        .c_flat(c_flat),

        .busy(busy),
        .done(done)
    );


    /*
     * 100 MHz clock
     */
    initial begin
        clk = 0;

        forever #5 clk = ~clk;
    end


    /*
     * Pack the testbench matrices into the flattened
     * interface expected by the DUT.
     */
    task pack_inputs;
        integer p;

        begin
            a_flat = 0;
            b_flat = 0;

            for (p = 0; p < N*N; p = p + 1) begin
                a_flat[(p*W) +: W] = a[p];
                b_flat[(p*W) +: W] = b[p];
            end
        end
    endtask


    /*
     * Start a matrix multiplication and verify every
     * result against a software-style reference model.
     */
    task run_and_check;

        begin

            pack_inputs();

            /*
             * Drive start away from the sampling edge.
             */
            @(negedge clk);
            start = 1'b1;

            @(negedge clk);
            start = 1'b0;

            /*
             * Wait for transaction completion.
             */
            wait(done == 1'b1);

            #1;

            /*
             * Verify every C[row][column].
             */
            for (r = 0; r < N; r = r + 1) begin

                for (col = 0; col < N; col = col + 1) begin

                    exp = 0;

                    for (k = 0; k < N; k = k + 1) begin
                        exp = exp
                            + $signed(a[r*N+k])
                            * $signed(b[k*N+col]);
                    end

                    actual =
                        c_flat[
                            ((r*N + col)*ACC_W)
                            +: ACC_W
                        ];

                    if ($signed(actual) !== exp) begin

                        $display(
                            "FAIL: C[%0d,%0d]",
                            r,
                            col
                        );

                        $display(
                            "Expected = %0d",
                            exp
                        );

                        $display(
                            "Actual   = %0d",
                            $signed(actual)
                        );

                        $fatal(
                            1,
                            "Matrix multiplication mismatch"
                        );
                    end
                end
            end
        end
    endtask


    initial begin

        /*
         * Initial conditions.
         */
        rst_n  = 0;
        start  = 0;
        a_flat = 0;
        b_flat = 0;

        for (i = 0; i < N*N; i = i + 1) begin
            a[i] = 0;
            b[i] = 0;
        end


        /*
         * Hold reset for several clocks.
         */
        repeat (3) @(posedge clk);

        @(negedge clk);
        rst_n = 1;


        /*
         * TEST 1
         *
         * A × Identity = A
         */
        for (i = 0; i < N*N; i = i + 1) begin
            a[i] = (i % 9) - 4;
            b[i] = 0;
        end

        for (i = 0; i < N; i = i + 1) begin
            b[i*N+i] = 1;
        end

        run_and_check();

        $display(
            "PASS: identity matrix test"
        );


        /*
         * TEST 2
         *
         * Deterministic signed matrix multiplication.
         */
        for (i = 0; i < N*N; i = i + 1) begin
            a[i] = (i % 7) - 3;
            b[i] = (i % 5) - 2;
        end

        run_and_check();

        $display(
            "PASS: deterministic signed test"
        );


        /*
         * TEST 3
         *
         * Random regression.
         */
        for (t = 0; t < 25; t = t + 1) begin

            for (i = 0; i < N*N; i = i + 1) begin

                a[i] =
                    $urandom_range(0,30) - 15;

                b[i] =
                    $urandom_range(0,30) - 15;
            end

            run_and_check();
        end

        $display(
            "PASS: 25 randomized matrix tests"
        );


        /*
         * TEST 4
         *
         * Verify that start while busy does not restart
         * the current computation.
         */
        for (i = 0; i < N*N; i = i + 1) begin
            a[i] = 1;
            b[i] = 1;
        end

        pack_inputs();

        @(negedge clk);
        start = 1;

        @(negedge clk);
        start = 0;


        /*
         * Wait until computation is underway.
         */
        repeat (3) @(posedge clk);


        /*
         * Attempt to restart while busy.
         * DUT should ignore this.
         */
        @(negedge clk);
        start = 1;

        @(negedge clk);
        start = 0;


        wait(done == 1'b1);

        #1;


        /*
         * A and B are all ones.
         *
         * Each output must therefore equal N:
         *
         * 1*1 + 1*1 + 1*1 + 1*1 = 4
         */
        for (i = 0; i < N*N; i = i + 1) begin

            actual =
                c_flat[
                    (i*ACC_W)
                    +: ACC_W
                ];

            if ($signed(actual) !== N) begin
                $fatal(
                    1,
                    "Busy/start protection failed at output %0d: got=%0d expected=%0d",
                    i,
                    $signed(actual),
                    N
                );
            end
        end

        $display(
            "PASS: busy/start protection"
        );


        $display("");
        $display(
            "============================================"
        );

        $display(
            "PASS: FPGA matrix accelerator regression"
        );

        $display(
            "============================================"
        );

        $finish;
    end

endmodule
