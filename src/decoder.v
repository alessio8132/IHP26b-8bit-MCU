`default_nettype none

module instruction_decoder (
    input  wire [7:0] opcode,

    // Register Addresses (Directly extracted)
    output wire [1:0] rd_addr,
    output wire [1:0] rs_addr,

    // Control Signals
    output reg        alu_enable,
    output reg  [1:0] alu_op,
    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        imm_select, // 1 = use Byte 2 data, 0 = use Register data
    output reg        io_in,
    output reg        io_out,
    output reg        jmp,
    output reg        jz,
    output reg        jc,
    output reg        halt
);

    // Extract the class and operation fields for cleaner case statements
    wire [1:0] inst_class = opcode[7:6];
    wire [1:0] inst_op    = opcode[5:4];

    // Source and Destination are always in the same place
    assign rd_addr = opcode[3:2];
    assign rs_addr = opcode[1:0];

    always @(*) begin
        // 1. Default assignments to prevent inferred latches
        alu_enable = 0;
        alu_op     = 2'b00;
        reg_write  = 0;
        mem_read   = 0;
        mem_write  = 0;
        imm_select = 0;
        io_in      = 0;
        io_out     = 0;
        jmp        = 0;
        jz         = 0;
        jc         = 0;
        halt       = 0;

        // 2. Decode the instruction
        case (inst_class)
            2'b00: begin // Class 00: ALU Operations
                alu_enable = 1;
                alu_op     = inst_op; // 00=ADD, 01=SUB, 10=AND, 11=OR
                reg_write  = 1;       // ALU always writes back to Rd
            end

            2'b01: begin // Class 01: Memory & Data
                case (inst_op)
                    2'b00: begin imm_select = 1; reg_write = 1; end // LDI
                    2'b01: begin mem_read   = 1; reg_write = 1; end // LD
                    2'b10: begin mem_write  = 1; end                // ST
                    2'b11: begin reg_write  = 1; end                // MOV
                endcase
            end

            2'b10: begin // Class 10: I/O
                case (inst_op)
                    2'b00: begin io_in  = 1; reg_write = 1; end // IN
                    2'b01: begin io_out = 1; end                // OUT
                    default: ; // Reserved opcodes do nothing
                endcase
            end

            2'b11: begin // Class 11: Control Flow
                case (inst_op)
                    2'b00: jmp  = 1; // JMP
                    2'b01: jz   = 1; // JZ
                    2'b10: jc   = 1; // JC
                    2'b11: halt = 1; // HALT
                endcase
            end
        endcase
    end
endmodule