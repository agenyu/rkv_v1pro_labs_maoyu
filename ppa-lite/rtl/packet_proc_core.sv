module packet_proc_core (
  input  logic       clk,
  input  logic       rst_n,
  input  logic       start_i,
  input  logic       algo_mode_i,
  input  logic [3:0] type_mask_i,
  input  logic [5:0] exp_pkt_len_i,

  output logic       mem_rd_en_o,
  output logic [2:0] mem_rd_addr_o,
  input  logic [31:0] mem_rd_data_i,

  output logic       busy_o,
  output logic       done_o,
  output logic [5:0] res_pkt_len_o,
  output logic [7:0] res_pkt_type_o,
  output logic [7:0] res_payload_sum_o,
  output logic [7:0] res_payload_xor_o,
  output logic       format_ok_o,
  output logic       length_error_o,
  output logic       type_error_o,
  output logic       chk_error_o
);

  typedef enum logic [1:0] {
    S_IDLE    = 2'd0,
    S_PROCESS = 2'd1,
    S_DONE    = 2'd2
  } state_t;

  state_t state;

  logic       issue_read_r;
  logic       wait_read_r;
  logic [2:0] word_idx_r;
  logic [2:0] rd_addr_r;
  logic [5:0] pkt_len_r;
  logic [7:0] pkt_type_r;
  logic       algo_mode_r;
  logic [3:0] type_mask_r;
  logic [5:0] exp_len_r;
  logic [7:0] sum_r;
  logic [7:0] xor_r;
  logic       busy_r;
  logic       done_r;
  logic       format_ok_r;
  logic       length_error_r;
  logic       type_error_r;
  logic       chk_error_r;

  assign mem_rd_en_o      = issue_read_r;
  assign mem_rd_addr_o    = rd_addr_r;
  assign busy_o           = busy_r;
  assign done_o           = done_r;
  assign res_pkt_len_o    = pkt_len_r;
  assign res_pkt_type_o   = pkt_type_r;
  assign res_payload_sum_o = sum_r;
  assign res_payload_xor_o = xor_r;
  assign format_ok_o      = format_ok_r;
  assign length_error_o   = length_error_r;
  assign type_error_o     = type_error_r;
  assign chk_error_o      = chk_error_r;

  function automatic logic [3:0] words_for_len(input logic [7:0] len);
    if (len <= 8'd4) begin
      words_for_len = 4'd1;
    end
    else if (len >= 8'd32) begin
      words_for_len = 4'd8;
    end
    else begin
      words_for_len = (len + 8'd3) >> 2;
    end
  endfunction

  function automatic logic [7:0] effective_len(input logic [7:0] len);
    if (len > 8'd32) begin
      effective_len = 8'd32;
    end
    else begin
      effective_len = len;
    end
  endfunction

  function automatic logic type_is_legal(
    input logic [7:0] pkt_type,
    input logic [3:0] type_mask
  );
    case (pkt_type)
      8'h01: return type_mask[0];
      8'h02: return type_mask[1];
      8'h04: return type_mask[2];
      8'h08: return type_mask[3];
      default: return 1'b0;
    endcase
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= S_IDLE;
      issue_read_r    <= 1'b0;
      wait_read_r     <= 1'b0;
      word_idx_r      <= 3'd0;
      rd_addr_r       <= 3'd0;
      pkt_len_r       <= 6'd0;
      pkt_type_r      <= 8'd0;
      algo_mode_r     <= 1'b1;
      type_mask_r     <= 4'hF;
      exp_len_r       <= 6'd0;
      sum_r           <= 8'd0;
      xor_r           <= 8'd0;
      busy_r          <= 1'b0;
      done_r          <= 1'b0;
      format_ok_r     <= 1'b0;
      length_error_r  <= 1'b0;
      type_error_r    <= 1'b0;
      chk_error_r     <= 1'b0;
    end
    else if (start_i && !busy_r) begin
      state           <= S_PROCESS;
      issue_read_r    <= 1'b1;
      wait_read_r     <= 1'b0;
      word_idx_r      <= 3'd0;
      rd_addr_r       <= 3'd0;
      pkt_len_r       <= 6'd0;
      pkt_type_r      <= 8'd0;
      algo_mode_r     <= algo_mode_i;
      type_mask_r     <= type_mask_i;
      exp_len_r       <= exp_pkt_len_i;
      sum_r           <= 8'd0;
      xor_r           <= 8'd0;
      busy_r          <= 1'b1;
      done_r          <= 1'b0;
      format_ok_r     <= 1'b0;
      length_error_r  <= 1'b0;
      type_error_r    <= 1'b0;
      chk_error_r     <= 1'b0;
    end
    else begin
      case (state)
        S_IDLE: begin
          busy_r       <= 1'b0;
          issue_read_r <= 1'b0;
          wait_read_r  <= 1'b0;
        end

        S_PROCESS: begin
          if (issue_read_r) begin
            issue_read_r <= 1'b0;
            wait_read_r  <= 1'b1;
          end
          else if (wait_read_r) begin
            begin : process_word
              logic [7:0] sum_v;
              logic [7:0] xor_v;
              logic [7:0] word_len_v;
              logic       le_v;
              logic       te_v;
              logic       ce_v;
              integer     j;

              wait_read_r <= 1'b0;
              sum_v       = sum_r;
              xor_v       = xor_r;

              if (word_idx_r == 3'd0) begin
                pkt_len_r  <= mem_rd_data_i[7:0];
                pkt_type_r <= mem_rd_data_i[15:8];

                le_v = (mem_rd_data_i[7:0] < 8'd4) ||
                       (mem_rd_data_i[7:0] > 8'd32) ||
                       ((exp_len_r != 6'd0) && (mem_rd_data_i[7:0] != exp_len_r));
                te_v = !type_is_legal(mem_rd_data_i[15:8], type_mask_r);
                ce_v = algo_mode_r &&
                       (mem_rd_data_i[31:24] !=
                        (mem_rd_data_i[7:0] ^ mem_rd_data_i[15:8] ^ mem_rd_data_i[23:16]));

                length_error_r <= le_v;
                type_error_r   <= te_v;
                chk_error_r    <= ce_v;
                format_ok_r    <= !(le_v || te_v || ce_v);
              end
              else begin
                word_len_v = effective_len(pkt_len_r);
                for (j = 0; j < 4; j = j + 1) begin
                  if (((word_idx_r * 4) + j) < word_len_v) begin
                    sum_v = sum_v + mem_rd_data_i[(8*j) +: 8];
                    xor_v = xor_v ^ mem_rd_data_i[(8*j) +: 8];
                  end
                end
                sum_r <= sum_v;
                xor_r <= xor_v;
              end

              if (word_idx_r == 3'd0) begin
                if (words_for_len(mem_rd_data_i[7:0]) == 4'd1) begin
                  state        <= S_DONE;
                  busy_r       <= 1'b0;
                  done_r       <= 1'b1;
                  issue_read_r <= 1'b0;
                end
                else begin
                  word_idx_r   <= 3'd1;
                  rd_addr_r    <= 3'd1;
                  issue_read_r <= 1'b1;
                end
              end
              else if ((word_idx_r + 3'd1) >= words_for_len({2'b0, pkt_len_r})) begin
                state        <= S_DONE;
                busy_r       <= 1'b0;
                done_r       <= 1'b1;
                issue_read_r <= 1'b0;
              end
              else begin
                word_idx_r   <= word_idx_r + 3'd1;
                rd_addr_r    <= word_idx_r + 3'd1;
                issue_read_r <= 1'b1;
              end
            end
          end
        end

        S_DONE: begin
          busy_r       <= 1'b0;
          done_r       <= 1'b1;
          issue_read_r <= 1'b0;
          wait_read_r  <= 1'b0;
        end

        default: begin
          state        <= S_IDLE;
          busy_r       <= 1'b0;
          done_r       <= 1'b0;
          issue_read_r <= 1'b0;
          wait_read_r  <= 1'b0;
        end
      endcase
    end
  end

endmodule
