`timescale 1ns/1ps

module tb_axi4_lite_regs;
    localparam int ADDR_WIDTH = 8;
    localparam int DATA_WIDTH = 32;

    logic aclk = 1'b0;
    logic aresetn;
    logic [ADDR_WIDTH-1:0] s_axi_awaddr;
    logic s_axi_awvalid, s_axi_awready;
    logic [DATA_WIDTH-1:0] s_axi_wdata;
    logic [DATA_WIDTH/8-1:0] s_axi_wstrb;
    logic s_axi_wvalid, s_axi_wready;
    logic [1:0] s_axi_bresp;
    logic s_axi_bvalid, s_axi_bready;
    logic [ADDR_WIDTH-1:0] s_axi_araddr;
    logic s_axi_arvalid, s_axi_arready;
    logic [DATA_WIDTH-1:0] s_axi_rdata;
    logic [1:0] s_axi_rresp;
    logic s_axi_rvalid, s_axi_rready;
    logic [DATA_WIDTH-1:0] control_reg;
    logic [DATA_WIDTH-1:0] status_reg;

    always #5 aclk = ~aclk;

    axi4_lite_regs #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (.*);

    task automatic send_aw(input logic [ADDR_WIDTH-1:0] addr);
        begin
            @(negedge aclk);
            s_axi_awaddr = addr;
            s_axi_awvalid = 1'b1;
            do @(posedge aclk); while (!s_axi_awready);
            @(negedge aclk);
            s_axi_awvalid = 1'b0;
            $display("[%0t] AW accepted: addr=0x%02h", $time, addr);
        end
    endtask

    task automatic send_w(
        input logic [DATA_WIDTH-1:0] data,
        input logic [DATA_WIDTH/8-1:0] strb
    );
        begin
            @(negedge aclk);
            s_axi_wdata = data;
            s_axi_wstrb = strb;
            s_axi_wvalid = 1'b1;
            do @(posedge aclk); while (!s_axi_wready);
            @(negedge aclk);
            s_axi_wvalid = 1'b0;
            $display("[%0t] W accepted: data=0x%08h strb=0x%1h", $time, data, strb);
        end
    endtask

    task automatic finish_write(input logic [1:0] expected_resp);
        logic [1:0] held_resp;
        begin
            s_axi_bready = 1'b0;
            while (!s_axi_bvalid) @(negedge aclk);
            held_resp = s_axi_bresp;
            if (held_resp !== expected_resp)
                $fatal(1, "B response mismatch: got %b expected %b", held_resp, expected_resp);
            repeat (2) begin
                @(negedge aclk);
                if (!s_axi_bvalid || s_axi_bresp !== held_resp)
                    $fatal(1, "B response changed while stalled");
            end
            $display("[%0t] B response: %s (held stable under backpressure)", $time,
                     held_resp == 2'b00 ? "OKAY" : "SLVERR");
            s_axi_bready = 1'b1;
            @(posedge aclk);
            @(negedge aclk);
            s_axi_bready = 1'b0;
        end
    endtask

    // order: 0 = AW then W, 1 = W then AW, 2 = AW and W together.
    task automatic write_reg(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [DATA_WIDTH-1:0] data,
        input logic [DATA_WIDTH/8-1:0] strb,
        input int order,
        input logic [1:0] expected_resp
    );
        begin
            $display("[%0t] WRITE start: addr=0x%02h data=0x%08h order=%0d",
                     $time, addr, data, order);
            case (order)
                0: begin send_aw(addr); send_w(data, strb); end
                1: begin send_w(data, strb); send_aw(addr); end
                default: begin
                    @(negedge aclk);
                    s_axi_awaddr = addr;
                    s_axi_awvalid = 1'b1;
                    s_axi_wdata = data;
                    s_axi_wstrb = strb;
                    s_axi_wvalid = 1'b1;
                    do @(posedge aclk); while (!(s_axi_awready && s_axi_wready));
                    @(negedge aclk);
                    s_axi_awvalid = 1'b0;
                    s_axi_wvalid = 1'b0;
                    $display("[%0t] AW and W accepted together", $time);
                end
            endcase
            finish_write(expected_resp);
        end
    endtask

    task automatic read_reg(
        input logic [ADDR_WIDTH-1:0] addr,
        input logic [DATA_WIDTH-1:0] expected_data,
        input logic [1:0] expected_resp
    );
        logic [DATA_WIDTH-1:0] held_data;
        logic [1:0] held_resp;
        begin
            $display("[%0t] READ start: addr=0x%02h", $time, addr);
            s_axi_rready = 1'b0;
            @(negedge aclk);
            s_axi_araddr = addr;
            s_axi_arvalid = 1'b1;
            do @(posedge aclk); while (!s_axi_arready);
            @(negedge aclk);
            s_axi_arvalid = 1'b0;
            while (!s_axi_rvalid) @(negedge aclk);
            held_data = s_axi_rdata;
            held_resp = s_axi_rresp;
            if (held_data !== expected_data || held_resp !== expected_resp)
                $fatal(1, "READ 0x%02h got data=0x%08h resp=%b; expected data=0x%08h resp=%b",
                       addr, held_data, held_resp, expected_data, expected_resp);
            repeat (2) begin
                @(negedge aclk);
                if (!s_axi_rvalid || s_axi_rdata !== held_data || s_axi_rresp !== held_resp)
                    $fatal(1, "R response changed while stalled");
            end
            $display("[%0t] R response: data=0x%08h resp=%s (held stable under backpressure)",
                     $time, held_data, held_resp == 2'b00 ? "OKAY" : "SLVERR");
            s_axi_rready = 1'b1;
            @(posedge aclk);
            @(negedge aclk);
            s_axi_rready = 1'b0;
        end
    endtask

    initial begin
        aresetn = 1'b0;
        s_axi_awaddr = '0;
        s_axi_awvalid = 1'b0;
        s_axi_wdata = '0;
        s_axi_wstrb = '0;
        s_axi_wvalid = 1'b0;
        s_axi_bready = 1'b0;
        s_axi_araddr = '0;
        s_axi_arvalid = 1'b0;
        s_axi_rready = 1'b0;
        status_reg = '0;

        $display("=== AXI4-Lite register block direct testbench ===");
        repeat (3) @(posedge aclk);
        @(negedge aclk);
        aresetn = 1'b1;
        $display("[%0t] Reset released", $time);

        read_reg(8'h00, 32'h0000_0000, 2'b00);
        write_reg(8'h00, 32'h1122_3344, 4'b1111, 0, 2'b00);
        read_reg(8'h00, 32'h1122_3344, 2'b00);
        // WSTRB[1] selects bits [15:8], so provide 0xCC in that byte lane.
        write_reg(8'h00, 32'h00AA_CCDD, 4'b0010, 2, 2'b00);
        read_reg(8'h00, 32'h1122_CC44, 2'b00);

        write_reg(8'h08, 32'hDEAD_BEEF, 4'b1111, 1, 2'b00);
        read_reg(8'h08, 32'hDEAD_BEEF, 2'b00);
        write_reg(8'h0C, 32'h1234_5678, 4'b1111, 2, 2'b00);
        read_reg(8'h0C, 32'h1234_5678, 2'b00);

        status_reg = 32'hCAFE_BABE;
        read_reg(8'h04, 32'hCAFE_BABE, 2'b00);
        write_reg(8'h04, 32'hFFFF_FFFF, 4'b1111, 0, 2'b10);
        read_reg(8'h04, 32'hCAFE_BABE, 2'b00);
        write_reg(8'h20, 32'hA5A5_A5A5, 4'b1111, 1, 2'b10);
        read_reg(8'h01, 32'h0000_0000, 2'b10);

        $display("=== TEST PASS: all directed checks completed ===");
        $finish;
    end
endmodule
