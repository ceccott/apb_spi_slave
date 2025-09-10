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
    input  logic                  pclk_i,
    input  logic                  preset_ni,

    // APB Master Signals
    output logic                  psel_o,
    output logic                  penable_o,
    output logic [APB_ADDR_WIDTH-1:0] paddr_o,
    output logic                  pwrite_o,
    output logic [APB_DATA_WIDTH-1:0] pwdata_o,
    input  logic [APB_DATA_WIDTH-1:0] prdata_i,
    input  logic                  pready_i,

    // SPI/BUFFER Interface
    input  logic [APB_ADDR_WIDTH-1:0] rxtx_addr_i,
    input  logic                  rxtx_addr_valid_i,
    input  logic                  start_tx_i,
    input  logic                  cs_ni, 
    output logic [APB_DATA_WIDTH-1:0] tx_data_o,
    output logic                 tx_valid_o,
    input  logic                 tx_ready_i,
    input  logic [APB_DATA_WIDTH-1:0] rx_data_i,
    input  logic                 rx_valid_i,
    output logic                 rx_ready_o,

    input  logic [15:0]          wrap_length_i
);
  typedef enum logic [1:0] {IDLE, SETUP, ENABLE, TXRESP} apb_state_e;

  apb_state_e state, next_state;

  logic [APB_ADDR_WIDTH-1:0] curr_addr, next_addr;
  logic [15:0]               tx_counter;
  logic [15:0]               wrap_length_i_t;
  logic                      curr_rxtx_state; // 0 = read, 1 = write
  logic                      rxtx_state; // 0 = read, 1 = write

  logic sample_rxtx_state, sample_rx, sample_tx;

  localparam logic WRITING = 1'b1;
  localparam logic READING = 1'b0;

  assign wrap_length_i_t = (wrap_length_i == 0) ? 16'h1 : wrap_length_i;

  // State registers
  always_ff @(posedge pclk_i or negedge preset_ni) begin
    if (!preset_ni) begin
      state <= IDLE;
      curr_addr <= '0;
      curr_rxtx_state <= READING;
    end else begin
      state <= next_state;
      if (rxtx_addr_valid_i)
        curr_addr <= rxtx_addr_i;
      else if ((state == ENABLE) && pready_i)
        curr_addr <= next_addr;

      if (sample_rxtx_state)
        curr_rxtx_state <= rxtx_state;
    end
  end

  // Counter
  always_ff @(posedge pclk_i or negedge preset_ni) begin
    if (!preset_ni) tx_counter <= 0;
    else if (start_tx_i || rx_valid_i) tx_counter <= 0;
    else if ((state == ENABLE) && pready_i) begin
      if (tx_counter == wrap_length_i_t - 1)
        tx_counter <= 0;
      else
        tx_counter <= tx_counter + 1;
    end
  end

  always_comb begin
    next_addr = curr_addr;
    if (tx_counter == wrap_length_i_t - 1)
      next_addr = rxtx_addr_i;
    else
      next_addr = curr_addr + 1;
  end

  // FSM combinational
  always_comb begin
    next_state = state;
    rxtx_state = READING;

    psel_o   = 1'b0;
    penable_o = 1'b0;
    pwrite_o  = 1'b0;
    paddr_o   = curr_addr;
    pwdata_o  = rx_data_i;

    rx_ready_o  = 1'b0;
    tx_valid_o  = 1'b0;
    tx_data_o   = prdata_i;

    sample_rx = 1'b0;
    sample_tx = 1'b0;
    sample_rxtx_state = 1'b0;

    case (state)
      IDLE: begin
        rxtx_state = READING;
        if (rx_valid_i) begin
          sample_rxtx_state = 1'b1;
          rxtx_state = WRITING;
          rx_ready_o = 1'b1;
          next_state = SETUP;
        end else if (start_tx_i && !cs_ni) begin
          sample_rxtx_state = 1'b1;
          rxtx_state = READING;
          next_state = SETUP;
        end
      end

      SETUP: begin
        psel_o = 1'b1;
        pwrite_o = (curr_rxtx_state == WRITING);
        next_state = ENABLE;
      end

      ENABLE: begin
        psel_o = 1'b1;
        penable_o = 1'b1;
        pwrite_o = (curr_rxtx_state == WRITING);

        if (pready_i) begin
          if (curr_rxtx_state == READING) begin
            tx_valid_o = 1'b1;
            next_state = TXRESP;
          end else if (tx_counter == wrap_length_i_t - 1 || cs_ni)
            next_state = IDLE;
          else
            next_state = SETUP;
        end
      end

      TXRESP: begin
        tx_valid_o = 1'b1;
        if (tx_ready_i) begin
          if (tx_counter == wrap_length_i_t - 1 || cs_ni)
            next_state = IDLE;
          else
            next_state = SETUP;
        end
      end
      default: begin
        next_state = IDLE;
        rxtx_state = READING;
      end
    endcase
  end
endmodule
