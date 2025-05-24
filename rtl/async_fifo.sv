module async_fifo #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4  
)(
    input  logic rst_n,     
    input  logic clk_w,     
    input  logic clk_r,     

    input  logic                  we,       
    input  logic [DATA_WIDTH-1:0] wdata,     
    output logic full,      

    input  logic re,        
    output logic [DATA_WIDTH-1:0] rdata,     
    output logic empty      
);

   
    logic [DATA_WIDTH-1:0] mem [0:(1<<ADDR_WIDTH)-1];

 
    logic [ADDR_WIDTH:0] wptr_bin, wptr_bin_next, wptr_gray;
    logic [ADDR_WIDTH:0] rptr_bin, rptr_bin_next, rptr_gray;


    logic [ADDR_WIDTH:0] rptr_gray_sync1, rptr_gray_sync2;
    logic [ADDR_WIDTH:0] wptr_gray_sync1, wptr_gray_sync2;

   
    assign wptr_bin_next = wptr_bin + (we && !full);
    assign rptr_bin_next = rptr_bin + (re && !empty);


   assign full = (
    (wptr_gray[ADDR_WIDTH]     != rptr_gray_sync2[ADDR_WIDTH]) &&     // MSB differs
    (wptr_gray[ADDR_WIDTH-1]   != rptr_gray_sync2[ADDR_WIDTH-1]) &&   // Second MSB differs
    (wptr_gray[ADDR_WIDTH-2:0] == rptr_gray_sync2[ADDR_WIDTH-2:0])    // Lower bits match
);
    
    // read pointer matches write pointer exactly
    assign empty = (rptr_gray == wptr_gray_sync2);

    // ========== WRITE DOMAIN ========== //
    always_ff @(posedge clk_w or negedge rst_n) begin
        if (!rst_n) begin
            wptr_bin  <= 0;
            wptr_gray <= 0;
        end else if (we && !full) begin
            mem[wptr_bin[ADDR_WIDTH-1:0]] <= wdata;
            wptr_bin  <= wptr_bin_next;
            wptr_gray <= (wptr_bin_next >> 1) ^ wptr_bin_next;  
        end
    end

    // Synchronize read pointer into write clock domain
    always_ff @(posedge clk_w or negedge rst_n) begin
        if (!rst_n) begin
            rptr_gray_sync1 <= 0;
            rptr_gray_sync2 <= 0;
        end else begin
            rptr_gray_sync1 <= rptr_gray;
            rptr_gray_sync2 <= rptr_gray_sync1;
        end
    end

    // ========== READ DOMAIN ========== //
    always_ff @(posedge clk_r or negedge rst_n) begin
        if (!rst_n) begin
            rptr_bin  <= 0;
            rptr_gray <= 0;
            rdata     <= 0;
        end else if (re && !empty) begin
            rdata <= mem[rptr_bin[ADDR_WIDTH-1:0]];
            rptr_bin  <= rptr_bin_next;
            rptr_gray <= (rptr_bin_next >> 1) ^ rptr_bin_next;  
        end
    end

    // Synchronize write pointer into read clock domain
    always_ff @(posedge clk_r or negedge rst_n) begin
        if (!rst_n) begin
            wptr_gray_sync1 <= 0;
            wptr_gray_sync2 <= 0;
        end else begin
            wptr_gray_sync1 <= wptr_gray;
            wptr_gray_sync2 <= wptr_gray_sync1;
        end
    end

endmodule