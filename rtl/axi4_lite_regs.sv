// SPDX-License-Identifier: MIT
// Small, reusable AXI4-Lite slave register block.
// Register map (byte offsets, DATA_WIDTH=32):
//   0x00 CONTROL  RW, reset 0x0000_0000
//   0x04 STATUS   RO, reset 0x0000_0000 (write returns SLVERR)
//   0x08 SCRATCH0 RW, reset 0x0000_0000
//   0x0C SCRATCH1 RW, reset 0x0000_0000
// All other addresses, including unaligned addresses, return SLVERR.
// Reset is active-low and synchronous. AXI-Lite channels are independent;
// AW and W may arrive in either order and responses remain stable under stall.
module axi4_lite_regs #(
    parameter int unsigned ADDR_WIDTH = 8,
    parameter int unsigned DATA_WIDTH = 32
) (
    input  logic                      aclk,
    input  logic                      aresetn,

    input  logic [ADDR_WIDTH-1:0]     s_axi_awaddr,
    input  logic                      s_axi_awvalid,
    output logic                      s_axi_awready,
    input  logic [DATA_WIDTH-1:0]     s_axi_wdata,
    input  logic [DATA_WIDTH/8-1:0]   s_axi_wstrb,
    input  logic                      s_axi_wvalid,
    output logic                      s_axi_wready,
    output logic [1:0]                s_axi_bresp,
    output logic                      s_axi_bvalid,
    input  logic                      s_axi_bready,

    input  logic [ADDR_WIDTH-1:0]     s_axi_araddr,
    input  logic                      s_axi_arvalid,
    output logic                      s_axi_arready,
    output logic [DATA_WIDTH-1:0]     s_axi_rdata,
    output logic [1:0]                s_axi_rresp,
    output logic                      s_axi_rvalid,
    input  logic                      s_axi_rready,

    output logic [DATA_WIDTH-1:0]     control_reg,
    input  logic [DATA_WIDTH-1:0]     status_reg
);

    localparam int unsigned BYTE_LANES = DATA_WIDTH / 8;
    localparam int unsigned BYTE_SHIFT = $clog2(BYTE_LANES);
    localparam logic [1:0] RESP_OKAY   = 2'b00;
    localparam logic [1:0] RESP_SLVERR = 2'b10;

    logic [DATA_WIDTH-1:0] scratch0_reg, scratch1_reg;
    logic [ADDR_WIDTH-1:0] awaddr_q;
    logic [DATA_WIDTH-1:0] wdata_q;
    logic [BYTE_LANES-1:0] wstrb_q;
    logic aw_pending, w_pending;

    function automatic logic address_valid(input logic [ADDR_WIDTH-1:0] addr);
        logic [ADDR_WIDTH-BYTE_SHIFT-1:0] word_index;
        begin
            word_index = addr[ADDR_WIDTH-1:BYTE_SHIFT];
            address_valid = (addr[BYTE_SHIFT-1:0] == '0) && (word_index < 4);
        end
    endfunction

    function automatic logic [DATA_WIDTH-1:0] read_register(
        input logic [ADDR_WIDTH-1:0] addr
    );
        logic [ADDR_WIDTH-BYTE_SHIFT-1:0] word_index;
        begin
            word_index = addr[ADDR_WIDTH-1:BYTE_SHIFT];
            case (word_index)
                0: read_register = control_reg;
                1: read_register = status_reg;
                2: read_register = scratch0_reg;
                3: read_register = scratch1_reg;
                default: read_register = '0;
            endcase
        end
    endfunction

    // Each write address and data beat is buffered independently. A write
    // commits only after both have been accepted, regardless of arrival order.
    assign s_axi_awready = aresetn && !aw_pending && !s_axi_bvalid;
    assign s_axi_wready  = aresetn && !w_pending  && !s_axi_bvalid;
    assign s_axi_arready = aresetn && !s_axi_rvalid;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            aw_pending <= 1'b0;
            w_pending  <= 1'b0;
            awaddr_q   <= '0;
            wdata_q    <= '0;
            wstrb_q    <= '0;
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= RESP_OKAY;
            s_axi_rvalid <= 1'b0;
            s_axi_rresp  <= RESP_OKAY;
            s_axi_rdata  <= '0;
            control_reg  <= '0;
            scratch0_reg <= '0;
            scratch1_reg <= '0;
        end else begin
            if (s_axi_bvalid && s_axi_bready)
                s_axi_bvalid <= 1'b0;

            if (s_axi_awvalid && s_axi_awready) begin
                awaddr_q   <= s_axi_awaddr;
                aw_pending <= 1'b1;
            end

            if (s_axi_wvalid && s_axi_wready) begin
                wdata_q   <= s_axi_wdata;
                wstrb_q   <= s_axi_wstrb;
                w_pending <= 1'b1;
            end

            if (aw_pending && w_pending && !s_axi_bvalid) begin
                aw_pending <= 1'b0;
                w_pending  <= 1'b0;
                s_axi_bvalid <= 1'b1;
                s_axi_bresp <= address_valid(awaddr_q) ? RESP_OKAY : RESP_SLVERR;

                if (address_valid(awaddr_q)) begin
                    case (awaddr_q[ADDR_WIDTH-1:BYTE_SHIFT])
                        0: begin
                            for (int lane = 0; lane < BYTE_LANES; lane++)
                                if (wstrb_q[lane])
                                    control_reg[lane*8 +: 8] <= wdata_q[lane*8 +: 8];
                        end
                        2: begin
                            for (int lane = 0; lane < BYTE_LANES; lane++)
                                if (wstrb_q[lane])
                                    scratch0_reg[lane*8 +: 8] <= wdata_q[lane*8 +: 8];
                        end
                        3: begin
                            for (int lane = 0; lane < BYTE_LANES; lane++)
                                if (wstrb_q[lane])
                                    scratch1_reg[lane*8 +: 8] <= wdata_q[lane*8 +: 8];
                        end
                        default: s_axi_bresp <= RESP_SLVERR;
                    endcase
                end
            end

            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_rdata  <= address_valid(s_axi_araddr) ? read_register(s_axi_araddr) : '0;
                s_axi_rresp  <= address_valid(s_axi_araddr) ? RESP_OKAY : RESP_SLVERR;
                s_axi_rvalid <= 1'b1;
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
