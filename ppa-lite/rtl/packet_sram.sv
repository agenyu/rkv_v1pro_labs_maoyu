module packet_sram (
  input  logic        clk,
  input  logic        rst_n,

  input  logic        apb_wr_en,
  input  logic [2:0]  apb_addr,
  input  logic [31:0] apb_wr_data,

  input  logic        proc_rd_en,
  input  logic [2:0]  proc_rd_addr,
  output logic [31:0] proc_rd_data,

  input  logic        apb_rd_en,
  output logic [31:0] apb_rd_data
);

  logic [31:0] mem [0:7];
  integer i;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < 8; i = i + 1) begin
        mem[i] <= 32'h0000_0000;
      end
    end
    else if (apb_wr_en) begin
      mem[apb_addr] <= apb_wr_data;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      proc_rd_data <= 32'h0000_0000;
      apb_rd_data  <= 32'h0000_0000;
    end
    else begin
      if (proc_rd_en) begin
        proc_rd_data <= mem[proc_rd_addr];
      end
      if (apb_rd_en) begin
        apb_rd_data <= mem[apb_addr];
      end
    end
  end

endmodule
