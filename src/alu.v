`default_nettype none

module alu (
    input  wire [7:0] a,        // First operand (usually from Rd)
    input  wire [7:0] b,        // Second operand (usually from Rs)
    input  wire [1:0] alu_op,   // Control signal from the decoder

    output reg  [7:0] result,   // The 8-bit answer
    output wire       zero,     // High if result is 0 (for JZ instruction)
    output reg        carry     // High if addition overflows (for JC instruction)
);

    always @(*) begin
        // Default assignment to prevent latches
        carry = 1'b0;

        case (alu_op)
            // 2'b00: ADD
            // By concatenating {carry, result}, Verilog extends the math to 9 bits.
            // If 8-bit a + 8-bit b > 255, the 9th bit spills into 'carry'.
            2'b00: {carry, result} = a + b; 
            
            // 2'b01: SUB
            // We do a standard subtraction. We also calculate the borrow/carry.
            2'b01: begin
                result = a - b;
                carry  = (a < b); // Carry flag acts as a "borrow" flag for subtraction
            end
            
            // 2'b10: AND
            2'b10: result = a & b;
            
            // 2'b11: OR
            2'b11: result = a | b;
        endcase
    end

    // The zero flag is constantly checking the result.
    // If all 8 bits are 0, this outputs a 1.
    assign zero = (result == 8'b0);

endmodule