// Copyright 2017 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the “License”); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

module spi_slave_tx #(
    parameter DATA_WIDTH = 32
) (
    input  logic        test_mode,
    input  logic        sclk,
    input  logic        cs,
    output logic        miso,
    input  logic [$clog2(DATA_WIDTH)-1:0] counter_in,
    input  logic        counter_in_upd,
    input  logic [DATA_WIDTH-1:0] data,
    input  logic        data_valid,
    output logic        done
);

  localparam CntWidth = $clog2(DATA_WIDTH);  
  reg [DATA_WIDTH-1:0] data_int;
  reg [DATA_WIDTH-1:0] data_int_next;
  reg [CntWidth-1:0] counter;
  reg [CntWidth-1:0] counter_trgt;
  reg [CntWidth-1:0] counter_next;
  reg [CntWidth-1:0] counter_trgt_next;
  logic running;
  logic running_next;
  logic sclk_inv;
  logic sclk_test;

  assign miso = data_int[DATA_WIDTH-1];


  always_comb begin
    done = 1'b0;
    if (counter_in_upd) counter_trgt_next = counter_in;
    else counter_trgt_next = counter_trgt;

    if (counter_in_upd) running_next = 1'b1;
    else if (counter == counter_trgt) running_next = 1'b0;
    else running_next = running;

    if (running || counter_in_upd) begin
      if (counter == counter_trgt) begin
        done = 1'b1;
        counter_next = '0;
      end else counter_next = counter + 1'b1;

      if (data_valid) begin
        data_int_next = data;
      end else begin
        data_int_next = {data_int[DATA_WIDTH-2:0], 1'b0};
      end
    end else begin
      counter_next  = counter;
      data_int_next = data_int;
    end
  end

  assign sclk_inv = ~sclk;

  always_comb
  begin
    if (test_mode == 1'b0)
      sclk_test = sclk_inv;
    else
      sclk_test = sclk;
  end

  always @(posedge sclk_test or posedge cs) begin
    if (cs == 1'b1) begin
      counter      <= 'h0;
      counter_trgt <= '1; 
      data_int     <= 'h0;
      running      <= 1'b0;
    end else begin
      counter      <= counter_next;
      counter_trgt <= counter_trgt_next;
      data_int     <= data_int_next;
      running      <= running_next;
    end
  end
endmodule
