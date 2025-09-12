module apb_spi_slave #(
    parameter APB_ADDR_WIDTH = 12,
    parameter APB_DATA_WIDTH = 8,
    parameter SPI_MODE = 1'b0,
    parameter READ_DUMMY_CYCLES = 8'h7, // 8 cycles
    parameter TX_FIFO_LOG_DEPTH = 2,
    parameter RX_FIFO_LOG_DEPTH = 2
) (

    // SPI SLAVE
    input  logic spi_sclk_i,
    input  logic spi_cs_i,
    input  logic spi_mosi_i,
    output logic spi_miso_o,

    // APB MASTER
    //***************************************
    input logic apb_pclk_i,
    input logic apb_preset_ni,

    output logic                      apb_psel_o,
    output logic                      apb_penable_o,
    output logic [APB_ADDR_WIDTH-1:0] apb_paddr_o,
    output logic                      apb_pwrite_o,
    output logic [APB_DATA_WIDTH-1:0] apb_pwdata_o,
    input  logic [APB_DATA_WIDTH-1:0] apb_prdata_i,
    input  logic                      apb_pready_i
);

  localparam RX_DATA_WIDTH = (APB_DATA_WIDTH >= APB_ADDR_WIDTH) ? APB_DATA_WIDTH : APB_ADDR_WIDTH;

  logic [RX_DATA_WIDTH-1:0] rx_counter;
  logic                      rx_counter_upd;
  logic [RX_DATA_WIDTH-1:0] rx_data;
  logic                      rx_data_valid;

  logic [APB_DATA_WIDTH-1:0] tx_counter;
  logic                      tx_counter_upd;
  logic [APB_DATA_WIDTH-1:0] tx_data;
  logic                      tx_data_valid;

  logic                      ctrl_rd_wr;

  logic [APB_ADDR_WIDTH-1:0] ctrl_addr;
  logic                      ctrl_addr_valid;

  logic [APB_DATA_WIDTH-1:0] ctrl_data_rx;
  logic                      ctrl_data_rx_valid;
  logic [APB_DATA_WIDTH-1:0] ctrl_data_tx;
  logic                      ctrl_data_tx_ready;

  logic [APB_DATA_WIDTH-1:0] fifo_data_rx;
  logic                      fifo_data_rx_valid;
  logic                      fifo_data_rx_ready;
  logic [APB_DATA_WIDTH-1:0] fifo_data_tx;
  logic                      fifo_data_tx_valid;
  logic                      fifo_data_tx_ready;

  logic [APB_ADDR_WIDTH-1:0] addr_sync;
  logic                      addr_valid_sync;
  logic                      cs_sync;

  logic                      tx_done;
  logic                      rd_wr_sync;

  logic [              15:0] wrap_length;
  logic                      test_mode;

  spi_slave_rx #(
    .DATA_WIDTH(RX_DATA_WIDTH)
  ) u_rxreg (
      .sclk          (spi_sclk_i),
      .cs            (spi_cs_i),
      .mosi          (spi_mosi_i),
      .counter_in    (rx_counter),
      .counter_in_upd(rx_counter_upd),
      .data          (rx_data),
      .data_ready    (rx_data_valid)
  );

  spi_slave_tx #(
    .DATA_WIDTH(APB_DATA_WIDTH)
  ) u_txreg (
      .test_mode     (SPI_MODE),
      .sclk          (spi_sclk_i),
      .cs            (spi_cs_i),
      .miso          (spi_miso_o),
      .counter_in    (tx_counter),
      .counter_in_upd(tx_counter_upd),
      .data          (tx_data),
      .data_valid    (tx_data_valid),
      .done          (tx_done)
  );

  spi_slave_controller #(
    .DUMMY_CYCLES(READ_DUMMY_CYCLES),
    .ADDR_WIDTH(APB_ADDR_WIDTH),
    .DATA_WIDTH(APB_DATA_WIDTH)
  ) u_slave_sm (
      .sclk              (spi_sclk_i),
      .sys_rstn          (apb_preset_ni),
      .cs                (spi_cs_i),
      .rx_counter        (rx_counter),
      .rx_counter_upd    (rx_counter_upd),
      .rx_data           (rx_data),
      .rx_data_valid     (rx_data_valid),
      .tx_counter        (tx_counter),
      .tx_counter_upd    (tx_counter_upd),
      .tx_data           (tx_data),
      .tx_data_valid     (tx_data_valid),
      .tx_done           (tx_done),
      .ctrl_rd_wr        (ctrl_rd_wr),
      .ctrl_addr         (ctrl_addr),
      .ctrl_addr_valid   (ctrl_addr_valid),
      .ctrl_data_rx      (ctrl_data_rx),
      .ctrl_data_rx_valid(ctrl_data_rx_valid),
      .ctrl_data_tx      (ctrl_data_tx),
      .ctrl_data_tx_ready(ctrl_data_tx_ready),
      .wrap_length       (wrap_length)
  );

  spi_slave_dc_fifo #(
      .DATA_WIDTH(APB_DATA_WIDTH),
      .FIFO_LOG_DEPTH(RX_FIFO_LOG_DEPTH)
  ) u_dcfifo_rx (
      .clk_a  (spi_sclk_i),
      .rstn_a (apb_preset_ni),
      .data_a (ctrl_data_rx),
      .valid_a(ctrl_data_rx_valid),
      .ready_a(),
      .clk_b  (apb_pclk_i),
      .rstn_b (apb_preset_ni),
      .data_b (fifo_data_rx),
      .valid_b(fifo_data_rx_valid),
      .ready_b(fifo_data_rx_ready)
  );

  spi_slave_dc_fifo #(
      .DATA_WIDTH(APB_DATA_WIDTH),
      .FIFO_LOG_DEPTH(TX_FIFO_LOG_DEPTH)
  ) u_dcfifo_tx (
      .clk_a  (apb_pclk_i),
      .rstn_a (apb_preset_ni),
      .data_a (fifo_data_tx),
      .valid_a(fifo_data_tx_valid),
      .ready_a(fifo_data_tx_ready),
      .clk_b  (spi_sclk_i),
      .rstn_b (apb_preset_ni),
      .data_b (ctrl_data_tx),
      .valid_b(),
      .ready_b(ctrl_data_tx_ready)
  );

  spi_slave_apb_plug #(
      .APB_ADDR_WIDTH(APB_ADDR_WIDTH),
      .APB_DATA_WIDTH(APB_DATA_WIDTH)
  ) u_apbplug (
      .pclk_i    (apb_pclk_i),
      .preset_ni (apb_preset_ni),
      .psel_o    (apb_psel_o),
      .penable_o (apb_penable_o),
      .paddr_o   (apb_paddr_o),
      .pwrite_o  (apb_pwrite_o),
      .pwdata_o  (apb_pwdata_o),
      .prdata_i  (apb_prdata_i),
      .pready_i  (apb_pready_i),
      //
      .rxtx_addr_i         (addr_sync),
      .rxtx_addr_valid_i   (addr_valid_sync),
      .start_tx_i          (rd_wr_sync & addr_valid_sync),
      .cs_ni                (cs_sync),
      .tx_data_o           (fifo_data_tx),
      .tx_valid_o          (fifo_data_tx_valid),
      .tx_ready_i          (fifo_data_tx_ready),
      .rx_data_i           (fifo_data_rx),
      .rx_valid_i          (fifo_data_rx_valid),
      .rx_ready_o          (fifo_data_rx_ready),
      .wrap_length_i       (wrap_length)
  );

  spi_slave_syncro #(
      .ADDR_WIDTH(APB_ADDR_WIDTH)
  ) u_syncro (
      .sys_clk           (apb_pclk_i),
      .rstn              (apb_preset_ni),
      .cs                (spi_cs_i),
      .address           (ctrl_addr),
      .address_valid     (ctrl_addr_valid),
      .rd_wr             (ctrl_rd_wr),
      .cs_sync           (cs_sync),
      .address_sync      (addr_sync),
      .address_valid_sync(addr_valid_sync),
      .rd_wr_sync        (rd_wr_sync)
  );

endmodule
