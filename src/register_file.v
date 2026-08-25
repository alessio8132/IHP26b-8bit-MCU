`default_nettype none

module register_file (
    input  wire       clk,
    input  wire       rst_n,
    
    // Read/Write Addresses from the Decoder
    input  wire [1:0] rd_addr,    // Destination register (also serves as operand A)
    input  wire [1:0] rs_addr,    // Source register (serves as operand B)
    
    // Data Paths
    input  wire       write_en,   // Guarded write-enable signal (real_reg_write)
    input  wire [7:0] write_data, // Data coming back from the ALU or Memory
    
    output wire [7:0] rd_data,    // Exposes the contents of the Rd register
    output wire [7:0] rs_data     // Exposes the contents of the Rs register
);

    // This creates an array of four 8-bit variables
    reg [7:0] registers [0:3];

    // --------------------------------------------------------
    // Continuous Read Ports
    // The outputs instantly update if the address changes.
    // --------------------------------------------------------
    assign rd_data = registers[rd_addr];
    assign rs_data = registers[rs_addr];

    // --------------------------------------------------------
    // Synchronous Write Port
    // Data is only saved on the rising edge of the clock.
    // --------------------------------------------------------
    integer i; // Used for the reset loop

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // On reset, clear all registers to 0
            for (i = 0; i < 4; i = i + 1) begin
                registers[i] <= 8'b00000000;
            end
        end else if (write_en) begin
            // Only overwrite the destination register if enabled
            registers[rd_addr] <= write_data;
        end
    end

endmodule