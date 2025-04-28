`timescale 1ns / 1ps
module rsi_fsm (
    input clk,
    input rst,
    input start,
    input [15:0] price_in,
    input new_price,
    output reg done,
    output reg [7:0] rsi
);

    localparam IDLE      = 3'b000,
               FILL_FIFO = 3'b001,
               READ_INIT = 3'b010,
               READ_WAIT = 3'b011,
               COMPARE   = 3'b100,
               DONE      = 3'b101;

    reg [2:0] state = IDLE;

    wire [15:0] price_out;
    wire fifo_full, fifo_empty;
    reg fifo_wr_en = 0, fifo_rd_en = 0;

    price_fifo #(.DEPTH(20)) fifo (
        .clk(clk),
        .rst(rst),
        .wr_en(fifo_wr_en),
        .rd_en(fifo_rd_en),
        .din(price_in),
        .dout(price_out),
        .full(fifo_full),
        .empty(fifo_empty)
    );

    reg [15:0] prev_price = 0, curr_price = 0;
    reg [31:0] gain_sum = 0, loss_sum = 0;
    reg [4:0] sample_cnt = 0;
    reg read_delay = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            fifo_wr_en <= 0;
            fifo_rd_en <= 0;
            done <= 0;
            rsi <= 0;
            sample_cnt <= 0;
            gain_sum <= 0;
            loss_sum <= 0;
            prev_price <= 0;
            read_delay <= 0;
        end else begin
            fifo_wr_en <= 0;
            fifo_rd_en <= 0;

            case (state)
                IDLE: begin
                    if (start) begin
                        gain_sum <= 0;
                        loss_sum <= 0;
                        sample_cnt <= 0;
                        done <= 0;
                        state <= FILL_FIFO;
                    end
                end

                FILL_FIFO: begin
                    if (new_price && !fifo_full)
                        fifo_wr_en <= 1;

                    if (fifo_full) begin
                        fifo_rd_en <= 1;
                        read_delay <= 1;
                        state <= READ_INIT;
                    end
                end

                READ_INIT: begin
                    fifo_rd_en <= 0;
                    if (read_delay) begin
                        prev_price <= price_out;
                        read_delay <= 0;
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    if (sample_cnt < 19 && !fifo_empty) begin
                        fifo_rd_en <= 1;
                        read_delay <= 1;
                        state <= READ_WAIT;
                    end else begin
                        state <= DONE;
                    end
                end

                READ_WAIT: begin
                    fifo_rd_en <= 0;
                    if (read_delay) begin
                        curr_price <= price_out;

                        if (price_out > prev_price)
                            gain_sum <= gain_sum + (price_out - prev_price);
                        else if (price_out < prev_price)
                            loss_sum <= loss_sum + (prev_price - price_out);

                        prev_price <= price_out;
                        sample_cnt <= sample_cnt + 1;
                        read_delay <= 0;
                        state <= COMPARE;
                    end
                end

                DONE: begin
                    if ((gain_sum + loss_sum) > 0)
                        rsi <= (100 * gain_sum) / (gain_sum + loss_sum);
                    else
                        rsi <= 0;

                    done <= 1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
