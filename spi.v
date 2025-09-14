module spi #(
  parameter DATA_WIDTH = 8
)(
  input  wire         clk,
  input  wire         rst,
  input  wire [7:0]   data_in,
  input  wire [1:0]   address,
  input  wire         data_valid,
  input  wire         spi_mosi,
  input  wire [1:0]   spi_mode,     // CPOL = mode[1], CPHA = mode[0]
  output reg          spi_cs,
  output reg          spi_sclk,
  output reg          spi_miso,
  output wire         transfer_done,
  output wire [4:0]   counter,
  output wire [1:0]   addr,
  output wire [7:0]   data_out
);

  // Internal registers
  reg [4:0]  count;
  reg [1:0]  addr_reg;
  reg [7:0]  reg_out;
  reg [7:0]  mem [3:0];
  reg [7:0]  tx_shift_reg;
  reg [7:0]  rx_shift_reg;
  reg        in_transfer;
  reg        clk_div;
  reg        transfer_done_d;

  // Assign outputs
  assign counter        = count;
  assign addr           = addr_reg;
  assign data_out       = reg_out;
  assign transfer_done  = transfer_done_d;

  // SPI mode decoding
  wire CPOL = spi_mode[1];
  wire CPHA = spi_mode[0];

  always @(posedge clk or posedge rst) begin
    if (rst) begin
      spi_cs          <= 1;
      spi_sclk        <= CPOL;
      spi_miso        <= 0;
      transfer_done_d <= 0;
      count           <= 0;
      addr_reg        <= 0;
      reg_out         <= 0;
      tx_shift_reg    <= 0;
      rx_shift_reg    <= 0;
      in_transfer     <= 0;
      clk_div         <= 0;
    end else begin
      transfer_done_d <= 0; // default low

      // Start of new transfer
      if (data_valid && !in_transfer) begin
        spi_cs         <= 0;
        spi_sclk       <= CPOL;
        addr_reg       <= address;
        tx_shift_reg   <= data_in;
        reg_out        <= data_in;
        rx_shift_reg   <= 0;
        count          <= 0;
        in_transfer    <= 1;
        clk_div        <= 0;
      end

      if (in_transfer) begin
        clk_div <= ~clk_div;

        if (clk_div) begin
          // Pre-toggling operations
          if (CPHA == 0) begin
            if (spi_sclk == ~CPOL && count < DATA_WIDTH) begin
              rx_shift_reg <= {rx_shift_reg[DATA_WIDTH-2:0], spi_mosi};
              count <= count + 1;
            end
          end else begin
            if (spi_sclk == CPOL && count < DATA_WIDTH) begin
              spi_miso <= tx_shift_reg[DATA_WIDTH-1];
              tx_shift_reg <= {tx_shift_reg[DATA_WIDTH-2:0], 1'b0};
            end
          end

          // Toggle clock
          spi_sclk <= ~spi_sclk;

          // Post-toggling operations
          if (CPHA == 0) begin
            if (spi_sclk == CPOL && count < DATA_WIDTH) begin
              spi_miso <= tx_shift_reg[DATA_WIDTH-1];
              tx_shift_reg <= {tx_shift_reg[DATA_WIDTH-2:0], 1'b0};
            end
          end else begin
            if (spi_sclk == ~CPOL && count < DATA_WIDTH) begin
              rx_shift_reg <= {rx_shift_reg[DATA_WIDTH-2:0], spi_mosi};
              count <= count + 1;
            end
          end

          // Check for end of transmission
          if (count == DATA_WIDTH) begin
            spi_cs          <= 1;
            transfer_done_d <= 1;
            in_transfer     <= 0;
            spi_sclk        <= CPOL;
            mem[addr_reg]   <= rx_shift_reg;
          end
        end
      end else begin
        spi_miso <= 0;
      end
    end
  end

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, spi);
  end

endmodule

