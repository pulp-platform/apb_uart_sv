/* Copyright (C) 2017 ETH Zurich, University of Bologna
 * All rights reserved.
 *
 * This code is under development and not yet released to the public.
 * Until it is released, the code is under the copyright of ETH Zurich and
 * the University of Bologna, and may contain confidential and/or unpublished 
 * work. Any reuse/redistribution is strictly forbidden without written
 * permission from ETH Zurich.
 *
 * Bug fixes and contributions will eventually be released under the
 * SolderPad open hardware license in the context of the PULP platform
 * (http://www.pulp-platform.org), under the copyright of ETH Zurich and the
 * University of Bologna.
 */

module uart_interrupt
#(
    parameter TX_FIFO_DEPTH = 32,
    parameter RX_FIFO_DEPTH = 32
)
(
    input  logic                      clk_i,
    input  logic                      rstn_i,

    // registers
    input  logic [2:0]                IER_i, // interrupt enable register
    input  logic                      RDA_i, // receiver data available
    input  logic                      CTI_i, // character timeout indication

    // control logic
    input  logic                      error_i,
    input  logic [$clog2(RX_FIFO_DEPTH):0]    rx_elements_i,
    input  logic [$clog2(TX_FIFO_DEPTH):0]    tx_elements_i,
    input  logic [1:0]                trigger_level_i,

    input  logic [3:0]                clr_int_i, // one hot

    output logic                      interrupt_o,
    output logic [3:0]                IIR_o
);

    logic [3:0] iir_n, iir_q;
    logic trigger_level_reached;

    always_comb
    begin
        trigger_level_reached = 1'b0;
        case (trigger_level_i)
            2'b00:
                if ($unsigned(rx_elements_i) == 1)
                    trigger_level_reached = 1'b1;
            2'b01:
                if ($unsigned(rx_elements_i) == 4)
                    trigger_level_reached = 1'b1;
            2'b10:
                if ($unsigned(rx_elements_i) == 8)
                    trigger_level_reached = 1'b1;
            2'b11:
                if ($unsigned(rx_elements_i) == 14)
                    trigger_level_reached = 1'b1;
            default : /* default */;
        endcase
    end

    always_comb
    begin

        if (clr_int_i == 4'b0)
            iir_n = iir_q;
        else
            iir_n = iir_q & ~(clr_int_i);

        // Receiver line status interrupt on: Overrun error, parity error, framing error or break interrupt
        if (IER_i[2] & error_i)
            iir_n = 4'b1100;
        // Received data available or trigger level reached in FIFO mode
        else if (IER_i[0] & (trigger_level_reached | RDA_i))
            iir_n = 4'b1000;
        // Character timeout indication
        else if (IER_i[0] & CTI_i)
            iir_n = 4'b1000;
        // Transmitter holding register empty
        else if (IER_i[1] & tx_elements_i == 0)
            iir_n = 4'b0100;
    end


    always_ff @(posedge clk_i, negedge rstn_i)
    begin
        if (~rstn_i)
        begin
            iir_q <= 4'b0001;
        end
        else
        begin
            iir_q <= iir_n;
        end
    end

    assign IIR_o = iir_q;
    assign interrupt_o = ~iir_q[0];

endmodule

