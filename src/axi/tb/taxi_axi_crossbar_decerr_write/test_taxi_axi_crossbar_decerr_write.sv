// SPDX-License-Identifier: CERN-OHL-S-2.0
/*
 * Minimal AXI crossbar bad-address write DECERR timing reproducer.
 *
 * The test instantiates two upstream AXI masters (s_axi[0:1]) and one
 * downstream AXI slave (m_axi[0]).  Master 0 issues a two-beat write to
 * 0x1000, while the only slave aperture is 0x0000-0x0fff.  WVALID is held
 * low until after the DECERR response is observed.
 */

`resetall
`timescale 1ns / 1ps
`default_nettype none

module test_taxi_axi_crossbar_decerr_write;

localparam S_COUNT = 2;
localparam M_COUNT = 1;
localparam DATA_W = 32;
localparam ADDR_W = 32;
localparam STRB_W = DATA_W/8;
localparam S_ID_W = 1;
localparam M_ID_W = S_ID_W+$clog2(S_COUNT);

logic clk = 1'b0;
logic rst = 1'b1;

taxi_axi_if #(
    .DATA_W(DATA_W),
    .ADDR_W(ADDR_W),
    .STRB_W(STRB_W),
    .ID_W(S_ID_W)
) s_axi[S_COUNT]();

taxi_axi_if #(
    .DATA_W(DATA_W),
    .ADDR_W(ADDR_W),
    .STRB_W(STRB_W),
    .ID_W(M_ID_W)
) m_axi[M_COUNT]();

taxi_axi_crossbar #(
    .S_COUNT(S_COUNT),
    .M_COUNT(M_COUNT),
    .ADDR_W(ADDR_W),
    .S_THREADS({S_COUNT{32'd2}}),
    .S_ACCEPT({S_COUNT{32'd4}}),
    .M_REGIONS(1),
    .M_BASE_ADDR(32'h0000_0000),
    .M_ADDR_W(32'd12),
    .M_CONNECT_RD({M_COUNT{{S_COUNT{1'b1}}}}),
    .M_CONNECT_WR({M_COUNT{{S_COUNT{1'b1}}}}),
    .M_ISSUE({M_COUNT{32'd4}}),
    .M_SECURE({M_COUNT{1'b0}}),
    .S_AW_REG_TYPE({S_COUNT{2'd0}}),
    .S_W_REG_TYPE({S_COUNT{2'd0}}),
    .S_B_REG_TYPE({S_COUNT{2'd0}}),
    .S_AR_REG_TYPE({S_COUNT{2'd0}}),
    .S_R_REG_TYPE({S_COUNT{2'd0}}),
    .M_AW_REG_TYPE({M_COUNT{2'd0}}),
    .M_W_REG_TYPE({M_COUNT{2'd0}}),
    .M_B_REG_TYPE({M_COUNT{2'd0}}),
    .M_AR_REG_TYPE({M_COUNT{2'd0}}),
    .M_R_REG_TYPE({M_COUNT{2'd0}})
)
uut (
    .clk(clk),
    .rst(rst),
    .s_axi_wr(s_axi),
    .s_axi_rd(s_axi),
    .m_axi_wr(m_axi),
    .m_axi_rd(m_axi)
);

always #5 clk = !clk;

genvar gi;
generate
    for (gi = 0; gi < M_COUNT; gi = gi + 1) begin : slave_tieoff
        assign m_axi[gi].awready = 1'b0;
        assign m_axi[gi].wready = 1'b0;
        assign m_axi[gi].bid = '0;
        assign m_axi[gi].bresp = 2'b00;
        assign m_axi[gi].buser = '0;
        assign m_axi[gi].bvalid = 1'b0;

        assign m_axi[gi].arready = 1'b0;
        assign m_axi[gi].rid = '0;
        assign m_axi[gi].rdata = '0;
        assign m_axi[gi].rresp = 2'b00;
        assign m_axi[gi].rlast = 1'b0;
        assign m_axi[gi].ruser = '0;
        assign m_axi[gi].rvalid = 1'b0;
    end
endgenerate

int cycle = 0;
int w_beats = 0;
logic early_decerr_seen = 1'b0;

`define INIT_MASTER(index) \
    s_axi[index].awid = '0; \
    s_axi[index].awaddr = '0; \
    s_axi[index].awlen = '0; \
    s_axi[index].awsize = 3'd2; \
    s_axi[index].awburst = 2'b01; \
    s_axi[index].awlock = 1'b0; \
    s_axi[index].awcache = 4'b0011; \
    s_axi[index].awprot = 3'b000; \
    s_axi[index].awqos = '0; \
    s_axi[index].awregion = '0; \
    s_axi[index].awuser = '0; \
    s_axi[index].awvalid = 1'b0; \
    s_axi[index].wdata = '0; \
    s_axi[index].wstrb = '1; \
    s_axi[index].wlast = 1'b0; \
    s_axi[index].wuser = '0; \
    s_axi[index].wvalid = 1'b0; \
    s_axi[index].bready = 1'b1; \
    s_axi[index].arid = '0; \
    s_axi[index].araddr = '0; \
    s_axi[index].arlen = '0; \
    s_axi[index].arsize = 3'd2; \
    s_axi[index].arburst = 2'b01; \
    s_axi[index].arlock = 1'b0; \
    s_axi[index].arcache = 4'b0011; \
    s_axi[index].arprot = 3'b000; \
    s_axi[index].arqos = '0; \
    s_axi[index].arregion = '0; \
    s_axi[index].aruser = '0; \
    s_axi[index].arvalid = 1'b0; \
    s_axi[index].rready = 1'b1;

task automatic tick;
    @(posedge clk);
    #1;
endtask

always @(posedge clk) begin
    #1;

    if (rst) begin
        cycle <= 0;
        w_beats <= 0;
    end else begin
        cycle <= cycle + 1;

        if (s_axi[0].wvalid && s_axi[0].wready) begin
            w_beats <= w_beats + 1;
            $display("[%0t] cycle %0d: W handshake beat %0d, wlast=%0b",
                $time, cycle, w_beats, s_axi[0].wlast);
        end

        if (s_axi[0].bvalid && s_axi[0].bready) begin
            $display("[%0t] cycle %0d: B handshake, bresp=%0b, completed W beats=%0d",
                $time, cycle, s_axi[0].bresp, w_beats);
            if (s_axi[0].bresp == 2'b11 && w_beats < 2) begin
                early_decerr_seen <= 1'b1;
                $display("[%0t] BUG: DECERR returned before the two-beat write transfer completed", $time);
            end
        end
    end
end

initial begin
    int timeout;

    $dumpfile("taxi_axi_crossbar_decerr_write.fst");
    $dumpvars(0, test_taxi_axi_crossbar_decerr_write);

    `INIT_MASTER(0)
    `INIT_MASTER(1)

    repeat (2) tick();
    rst = 1'b0;
    repeat (1) tick();

    s_axi[0].awid = 1'b0;
    s_axi[0].awaddr = 32'h0000_1000;
    s_axi[0].awlen = 8'd1;
    s_axi[0].awsize = 3'd2;
    s_axi[0].awburst = 2'b01;
    s_axi[0].awvalid = 1'b1;

    timeout = 20;
    while (!s_axi[0].awready && timeout > 0) begin
        tick();
        timeout--;
    end

    if (!s_axi[0].awready) begin
        $fatal(1, "Timed out waiting for AWREADY");
    end

    $display("[%0t] cycle %0d: AW handshake for bad address 0x%08x",
        $time, cycle, s_axi[0].awaddr);
    s_axi[0].awvalid = 1'b0;

    timeout = 20;
    while (!early_decerr_seen && timeout > 0) begin
        tick();
        timeout--;
    end

    if (!early_decerr_seen) begin
        $fatal(1, "Expected early DECERR was not observed");
    end

    repeat (2) tick();
    $display("FST written to taxi_axi_crossbar_decerr_write.fst");
    $finish;
end

endmodule

`resetall
