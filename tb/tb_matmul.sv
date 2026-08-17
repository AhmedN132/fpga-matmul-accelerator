`timescale 1ns/1ps
module tb_matmul;
  localparam int N=4,W=8,ACC_W=2*W+$clog2(N)+1;
  logic clk=0,rst_n=0,start=0; logic busy,done;
  logic signed [W-1:0] a[0:N*N-1], b[0:N*N-1];
  logic signed [ACC_W-1:0] c[0:N*N-1];
  integer r,col,k,i,t,exp;
  matmul_accel #(.N(N),.W(W)) dut(.*);
  always #5 clk=~clk;

  task automatic run_and_check;
    begin
      @(posedge clk); start<=1; @(posedge clk); start<=0;
      wait(done); #1;
      for(r=0;r<N;r=r+1) for(col=0;col<N;col=col+1) begin
        exp=0; for(k=0;k<N;k=k+1) exp += $signed(a[r*N+k])*$signed(b[k*N+col]);
        if($signed(c[r*N+col]) !== exp)
          $fatal(1,"Mismatch c[%0d,%0d] exp=%0d got=%0d",r,col,exp,$signed(c[r*N+col]));
      end
    end
  endtask

  initial begin
    for(i=0;i<N*N;i=i+1) begin a[i]=0; b[i]=0; end
    repeat(2) @(posedge clk); rst_n<=1;

    // Identity multiplication.
    for(i=0;i<N*N;i=i+1) begin a[i]=(i%9)-4; b[i]=0; end
    for(i=0;i<N;i=i+1) b[i*N+i]=1;
    run_and_check();

    // Signed deterministic case.
    for(i=0;i<N*N;i=i+1) begin a[i]=(i%7)-3; b[i]=(i%5)-2; end
    run_and_check();

    // Random regression within 8-bit signed range.
    for(t=0;t<25;t=t+1) begin
      for(i=0;i<N*N;i=i+1) begin a[i]=$urandom_range(0,30)-15; b[i]=$urandom_range(0,30)-15; end
      run_and_check();
    end

    // start while busy must not restart transaction.
    for(i=0;i<N*N;i=i+1) begin a[i]=1; b[i]=1; end
    @(posedge clk); start<=1; @(posedge clk); start<=0;
    repeat(3) @(posedge clk); start<=1; @(posedge clk); start<=0;
    wait(done); #1;
    for(i=0;i<N*N;i=i+1) if($signed(c[i])!==N) $fatal(1,"Busy/start protection failed");

    $display("PASS: matrix accelerator directed + random regression");
    $finish;
  end
endmodule
