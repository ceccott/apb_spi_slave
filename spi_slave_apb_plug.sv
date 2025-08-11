// Copyright 2025 University of Geneva
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the “License”); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
module spi_slave_apb_plug #(
    parameter unsigned APB_ADDR_WIDTH = 32,
    parameter unsigned APB_DATA_WIDTH = 32
) (
    input  logic                  pclk,
    input  logic                  presetn,

    // APB Master Signals
    output logic                  psel,
    output logic                  penable,
    output logic [APB_ADDR_WIDTH-1:0] paddr,
    output logic                  pwrite,
    output logic [APB_DATA_WIDTH-1:0] pwdata,
    input  logic [APB_DATA_WIDTH-1:0] prdata,
    input  logic                  pready,

    // SPI/BUFFER Interface
    input  logic [APB_ADDR_WIDTH-1:0] rxtx_addr,
    input  logic                  rxtx_addr_valid,
    input  logic                  start_tx,
    input  logic                  cs,
    output logic [APB_DATA_WIDTH-1:0] tx_data,
    output logic                 tx_valid,
    input  logic                 tx_ready,
    input  logic [APB_DATA_WIDTH-1:0] rx_data,
    input  logic                 rx_valid,
    output logic                 rx_ready,

    input  logic [15:0]          wrap_length
);
  typedef enum logic [1:0] {IDLE, SETUP, ENABLE, TXRESP} apb_state_e;

  apb_state_e state, next_state;

  logic [APB_ADDR_WIDTH-1:0] curr_addr, next_addr;
  logic [15:0]               tx_counter;
  logic [15:0]               wrap_length_t;
  logic [0:0]                curr_rxtx_state; // 0 = read, 1 = write
  logic [0:0]                rxtx_state; // 0 = read, 1 = write

  logic sample_rxtx_state, sample_rx, sample_tx;

  localparam logic WRITING = 1'b1;
  localparam logic READING = 1'b0;

  assign wrap_length_t = (wrap_length == 0) ? 16'h1 : wrap_length;

  // State registers
  always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) begin
      state <= IDLE;
      curr_addr <= '0;
      curr_rxtx_state <= READING;
    end else begin
      state <= next_state;
      if (rxtx_addr_valid)
        curr_addr <= rxtx_addr;
      else if ((state == ENABLE) && pready)
        curr_addr <= next_addr;

      if (sample_rxtx_state)
        curr_rxtx_state <= rxtx_state;
    end
  end

  // Counter
  always_ff @(posedge pclk or negedge presetn) begin
    if (!presetn) tx_counter <= 0;
    else if (start_tx || rx_valid) tx_counter <= 0;
    else if ((state == ENABLE) && pready) begin
      if (tx_counter == wrap_length_t - 1)
        tx_counter <= 0;
      else
        tx_counter <= tx_counter + 1;
    end
  end

  always_comb begin
    next_addr = curr_addr;
    if (tx_counter == wrap_length_t - 1)
      next_addr = rxtx_addr;
    else
      next_addr = curr_addr + 1;
  end

  // FSM combinational
  always_comb begin
    next_state = state;
    rxtx_state = READING;

    psel   = 1'b0;
    penable = 1'b0;
    pwrite  = 1'b0;
    paddr   = curr_addr;
    pwdata  = rx_data;

    rx_ready  = 1'b0;
    tx_valid  = 1'b0;
    tx_data   = prdata;

    sample_rx = 1'b0;
    sample_tx = 1'b0;
    sample_rxtx_state = 1'b0;

    case (state)
      IDLE: begin
        if (rx_valid) begin
          sample_rxtx_state = 1'b1;
          rxtx_state = WRITING;
          rx_ready = 1'b1;
          next_state = SETUP;
        end else if (start_tx && !cs) begin
          sample_rxtx_state = 1'b1;
          rxtx_state = READING;
          next_state = SETUP;
        end
      end

      SETUP: begin
        psel = 1'b1;
        pwrite = (rxtx_state == WRITING);
        next_state = ENABLE;
      end

      ENABLE: begin
        psel = 1'b1;
        penable = 1'b1;
        pwrite = (rxtx_state == WRITING);

        if (pready) begin
          if (rxtx_state == READING) begin
            tx_valid = 1'b1;
            next_state = TXRESP;
          end else if (tx_counter == wrap_length_t - 1 || cs)
            next_state = IDLE;
          else
            next_state = SETUP;
        end
      end

      TXRESP: begin
        tx_valid = 1'b1;
        if (tx_ready) begin
          if (tx_counter == wrap_length_t - 1 || cs)
            next_state = IDLE;
          else
            next_state = SETUP;
        end
      end
    endcase
  end
endmodule
