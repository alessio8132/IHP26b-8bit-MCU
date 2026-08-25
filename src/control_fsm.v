`default_nettype none

module control_fsm (
    input  wire clk,
    input  wire rst_n,
    input  wire halt_in,      // Comes from the instruction decoder

    // FSM Control Outputs
    output reg  ir_write,     // 1 = Latch data bus into Instruction Register (Opcode)
    output reg  imm_write,    // 1 = Latch data bus into Immediate Register (Byte 2)
    output reg  pc_inc,       // 1 = Increment Program Counter
    output reg  exec_en       // 1 = Enable registers and memory to save results
);

    // --------------------------------------------------------
    // State Encodings (Local parameters are like #define in C)
    // --------------------------------------------------------
    localparam [1:0] FETCH_OP   = 2'b00; // Fetch the 8-bit instruction
    localparam [1:0] FETCH_DATA = 2'b01; // Fetch the 8-bit payload
    localparam [1:0] EXECUTE    = 2'b10; // Perform the math/logic
    localparam [1:0] HALTED     = 2'b11; // CPU stopped

    reg [1:0] current_state;
    reg [1:0] next_state;

    // --------------------------------------------------------
    // Block 1: State Register (Updates only on clock edges)
    // --------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= FETCH_OP; // Reset puts us at the start
        end else begin
            current_state <= next_state;
        end
    end

    // --------------------------------------------------------
    // Block 2: Next State Logic (No clocks here, just routing)
    // --------------------------------------------------------
    always @(*) begin
        // Default: stay in current state to prevent latches
        next_state = current_state;

        case (current_state)
            FETCH_OP:   next_state = FETCH_DATA;
            FETCH_DATA: next_state = EXECUTE;
            EXECUTE: begin
                if (halt_in) next_state = HALTED;
                else         next_state = FETCH_OP; // Loop back!
            end
            HALTED:     next_state = HALTED; // Stuck here until reset
        endcase
    end

    // --------------------------------------------------------
    // Block 3: Output Logic (What signals go high in each state?)
    // --------------------------------------------------------
    always @(*) begin
        // Default everything to 0
        ir_write  = 1'b0;
        imm_write = 1'b0;
        pc_inc    = 1'b0;
        exec_en   = 1'b0;

        case (current_state)
            FETCH_OP: begin
                ir_write = 1'b1; // Tell the IR to grab memory data
                pc_inc   = 1'b1; // Move PC to point to Byte 2
            end
            
            FETCH_DATA: begin
                imm_write = 1'b1; // Tell Immediate register to grab Byte 2
                pc_inc    = 1'b1; // Move PC to the next instruction
            end

            EXECUTE: begin
                // The decoder is constantly reading the frozen opcode.
                // We pulse exec_en to tell the CPU "Yes, you have permission to write the result now."
                exec_en = 1'b1;
            end
            
            HALTED: begin
                // All outputs remain 0. CPU is frozen.
            end
        endcase
    end
endmodule