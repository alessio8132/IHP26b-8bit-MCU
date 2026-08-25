`default_nettype none

module tt_um_alessio8132 (
    input  wire       clk,
    input  wire       rst_n,
    
    // External Bus Interface (Connecting to RAM/ROM or Tiny Tapeout Pins)
    input  wire [7:0] data_in,      // Data coming from memory/pins (Instruction bytes or RAM load)
    output wire [7:0] data_out,     // Data going out to memory/pins (RAM store or OUT instruction)
    output wire [7:0] address_bus,  // Current Program Counter or Memory Address
    
    // GPIO Direct Connections (for IN / OUT instructions)
    input  wire [7:0] gpio_in,      // ui_in pins
    output wire [7:0] gpio_out      // uo_out pins
);

    // --------------------------------------------------------
    // Internal Wires & Registers
    // --------------------------------------------------------
    
    // Program Counter & Instructions
    reg  [7:0] pc;
    reg  [7:0] instruction_register; // Holds Byte 1 (Opcode)
    reg  [7:0] immediate_register;   // Holds Byte 2 (Data / Address / Imm)
    
    // FSM Control Signals
    wire       ir_write;
    wire       imm_write;
    wire       pc_inc;
    wire       exec_en;
    
    // Decoder Outputs
    wire [1:0] rd_addr;
    wire [1:0] rs_addr;
    wire       alu_enable;
    wire [1:0] alu_op;
    wire       dec_reg_write;
    wire       mem_read;
    wire       mem_write;
    wire       imm_select;
    wire       io_in;
    wire       io_out;
    wire       jmp;
    wire       jz;
    wire       jc;
    wire       halt;

    // ALU & Register File Wires
    wire [7:0] rd_data;
    wire [7:0] rs_data;
    wire [7:0] alu_result;
    wire       alu_zero;
    wire       alu_carry;
    
    // CPU Status Flags
    reg        flag_zero;
    reg        flag_carry;

    // Guarded Write Enable (Only write on EXECUTE state)
    wire       real_reg_write = dec_reg_write & exec_en;

    // --------------------------------------------------------
    // 1. Program Counter & Control Registers
    // --------------------------------------------------------
    
    // Handle Address Bus (Outputs PC or Immediate Address depending on instruction)
    // For JMP/LD/ST, we want to output the immediate register as the target address.
    // Otherwise, we output the Program Counter to fetch the next instruction.
    assign address_bus = (jmp || jz || jc || mem_read || mem_write) ? immediate_register : pc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc                   <= 8'b0;
            instruction_register <= 8'b0;
            immediate_register   <= 8'b0;
            flag_zero            <= 1'b0;
            flag_carry           <= 1'b0;
        end else begin
            // Latch instruction bytes during fetch states
            if (ir_write)  instruction_register <= data_in;
            if (imm_write) immediate_register   <= data_in;

            // Handle Program Counter increments and jumps
            if (pc_inc) begin
                pc <= pc + 1'b1;
            end else if (exec_en) begin
                if (jmp) pc <= immediate_register;
                if (jz  && flag_zero) pc <= immediate_register;
                if (jc  && flag_carry) pc <= immediate_register;
            end

            // Update CPU flags during ALU execution
            if (exec_en && alu_enable) begin
                flag_zero  <= alu_zero;
                flag_carry <= alu_carry;
            end
        end
    end

    // --------------------------------------------------------
    // 2. Module Instantiations
    // --------------------------------------------------------

    // Control Unit FSM
    control_fsm u_fsm (
        .clk(clk),
        .rst_n(rst_n),
        .halt_in(halt),
        .ir_write(ir_write),
        .imm_write(imm_write),
        .pc_inc(pc_inc),
        .exec_en(exec_en)
    );

    // Instruction Decoder
    instruction_decoder u_decoder (
        .opcode(instruction_register),
        .rd_addr(rd_addr),
        .rs_addr(rs_addr),
        .alu_enable(alu_enable),
        .alu_op(alu_op),
        .reg_write(dec_reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .imm_select(imm_select),
        .io_in(io_in),
        .io_out(io_out),
        .jmp(jmp),
        .jz(jz),
        .jc(jc),
        .halt(halt)
    );

    // Register File
    // Operand B for the ALU can either be the Register source (Rs) or the Immediate Byte (Byte 2)
    wire [7:0] alu_operand_b = imm_select ? immediate_register : rs_data;

    register_file u_regfile (
        .clk(clk),
        .rst_n(rst_n),
        .rd_addr(rd_addr),
        .rs_addr(rs_addr),
        .write_en(real_reg_write),
        .write_data(
            io_in      ? gpio_in :
            mem_read   ? data_in :
            alu_result
        ),
        .rd_data(rd_data),
        .rs_data(rs_data)
    );

    // Arithmetic Logic Unit
    alu u_alu (
        .a(rd_data),
        .b(alu_operand_b),
        .alu_op(alu_op),
        .result(alu_result),
        .zero(alu_zero),
        .carry(alu_carry)
    );

    // --------------------------------------------------------
    // 3. Output Data & GPIO Routing
    // --------------------------------------------------------
    
    // If we are doing a Store instruction, send the register data to memory
    assign data_out = rs_data;
    
    // If we are executing an OUT instruction, route Rs directly to the GPIO pins
    assign gpio_out = io_out ? rs_data : 8'b0;

endmodule
