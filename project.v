module comparatorStructural(A, B, clk, EQ, GT, LT);
    // Inputs: Two 6-bit numbers (A and B), clock signal
    input [5:0] A, B;
    input clk;
    // Outputs: Equality, Greater, and Less-than indicators
    output EQ, GT, LT; 

    // Internal wires for bitwise operations
    wire [5:0] Bnot, Anot;
    wire [5:0] and1out, and2out;    
    wire [5:0] norout;    
    wire [10:0] and3out;

    // Generate logic for bitwise comparison
    genvar i;
    generate
        for (i = 0; i < 6; i = i + 1) begin : gen_comparator
            not #(4) (Bnot[i], B[i]);          // Bitwise NOT of B
            not #(4) (Anot[i], A[i]);          // Bitwise NOT of A      
            and #(9) (and1out[i], Anot[i], B[i]); // A < B for each bit
            and #(9) (and2out[i], A[i], Bnot[i]); // A > B for each bit
            nor #(6) (norout[i], and1out[i], and2out[i]); // A == B for each bit
        end
    endgenerate

    // Generate carry-based comparison for A < B
    and #(9) (and3out[10], norout[5], and1out[4]);
    and #(9) (and3out[9], norout[5], norout[4], and1out[3]);
    and #(9) (and3out[8], norout[5], norout[4], norout[3], and1out[2]);
    and #(9) (and3out[7], norout[5], norout[4], norout[3], norout[2], and1out[1]);    
    and #(9) (and3out[6], norout[5], norout[4], norout[3], norout[2], norout[1], and1out[0]);

    or #(9) (LT, and1out[5], and3out[10], and3out[9], and3out[8], and3out[7], and3out[6]); // Output: A < B

    // Generate carry-based comparison for A > B
    and #(9) (and3out[5], norout[5], and2out[4]);
    and #(9) (and3out[4], norout[5], norout[4], and2out[3]);
    and #(9) (and3out[3], norout[5], norout[4], norout[3], and2out[2]);
    and #(9) (and3out[2], norout[5], norout[4], norout[3], norout[2], and2out[1]);    
    and #(9) (and3out[1], norout[5], norout[4], norout[3], norout[2], norout[1], and2out[0]);

    or #(9) (GT, and2out[5], and3out[5], and3out[4], and3out[3], and3out[2], and3out[1]); // Output: A > B

    and #(9) (EQ, norout[5], norout[4], norout[3], norout[2], norout[1], norout[0]); // Output: A == B
endmodule

///////////////////////////////////////////////////////////////////////////

module signedOrUnsignedStructural(A, B, S, clk, EQ, GT, LT); 
    // Inputs: Two 6-bit numbers (A and B), Selection bit (S), clock signal
    input [5:0] A, B;
    input S, clk;             
    // Outputs: Equality, Greater, and Less-than indicators
    output reg EQ, GT, LT;   

    // Internal wires for two's complement and comparison results
    wire [5:0] A_twos_comp, B_twos_comp;
    wire EQ_unsigned, GT_unsigned, LT_unsigned;
    wire EQ_signed, GT_signed, LT_signed;

    // Registers for synchronizing inputs
    reg [5:0] A_reg, B_reg;
    reg S_reg;

    // Capture inputs on the negative edge of the clock
    always @(negedge clk) begin
        A_reg <= A;
        B_reg <= B;    
        S_reg <= S;
    end      

    // Compute two's complement for signed numbers
    assign A_twos_comp = (A_reg[5] == 1) ? (~A_reg + 1) : A_reg;
    assign B_twos_comp = (B_reg[5] == 1) ? (~B_reg + 1) : B_reg;   

    // Instantiate unsigned and signed comparators
    comparatorStructural comparator_unsigned (.A(A_reg), .B(B_reg), .clk(clk), .EQ(EQ_unsigned), .GT(GT_unsigned), .LT(LT_unsigned));
    comparatorStructural comparator_signed (.A(A_twos_comp), .B(B_twos_comp), .clk(clk), .EQ(EQ_signed), .GT(GT_signed), .LT(LT_signed));

    // Select the appropriate comparison result based on S
    always @(posedge clk) begin
        if (S_reg == 0) begin // Unsigned comparison
            EQ <= EQ_unsigned;
            GT <= GT_unsigned;
            LT <= LT_unsigned;
        end else begin // Signed comparison
            EQ <= (A_reg[5] == 0 && B_reg[5] == 1) || (A_reg[5] == 1 && B_reg[5] == 0) ? 0 : EQ_signed; // Handle sign mismatch
            GT <= (A_reg[5] == 0 && B_reg[5] == 1) ? 1 :
                  (A_reg[5] == 1 && B_reg[5] == 0) ? 0 : 
			    (A_reg == 6'b111111 && B_reg == 6'b111111) ? 0 :  
                  (A_reg[5] == 1 && B_reg[5] == 1) ? ~GT_signed : GT_signed;
            LT <= (A_reg[5] == 0 && B_reg[5] == 1) ? 0 :
                  (A_reg[5] == 1 && B_reg[5] == 0) ? 1 : 
			   (A_reg == 6'b111111 && B_reg == 6'b111111) ? 0 :
                  (A_reg[5] == 1 && B_reg[5] == 1) ? ~LT_signed : LT_signed;
        end
    end
endmodule

///////////////////////////////////////////////////////////////////////////	  

module comparatorBehavioral(A, B, S, clk, EQ, GT, LT);
    input [5:0] A, B;  // 6-bit inputs for A and B
    input S, clk;  // Input signal S for signed/unsigned selection and clk for clock
    output reg EQ, GT, LT;  // Outputs for Equal, Greater Than, and Less Than
    reg [5:0] A_reg, B_reg;  // Registers to store the values of A and B
    reg S_reg;  // Register to store the S signal

    // Always block triggered on the falling edge of the clock (for storing inputs)
    always @(negedge clk) begin
        A_reg <= A;  // Store A in A_reg on falling edge of clk
        B_reg <= B;  // Store B in B_reg on falling edge of clk
        S_reg <= S;  // Store S in S_reg on falling edge of clk
    end
    
    // Always block triggered on the rising edge of the clock (for comparison logic)
    always @(posedge clk) begin
        EQ <= 0;  // Reset the outputs at the start of every clock cycle
        GT <= 0;
        LT <= 0;

        if (S_reg == 0) begin  // Unsigned comparison when S_reg is 0
            if (A_reg == B_reg) 
                EQ <= 1;  // Set EQ if A equals B
            else if (A_reg > B_reg) 
                GT <= 1;  // Set GT if A is greater than B
            else 
                LT <= 1;  // Set LT if A is less than B
        end 
        else begin  // Signed comparison when S_reg is 1
            if (A_reg[5] == 0 && B_reg[5] == 1)  // A is positive, B is negative
                GT <= 1;  // A is greater than B
            else if (A_reg[5] == 1 && B_reg[5] == 0)  // A is negative, B is positive
                LT <= 1;  // A is less than B
            else begin  // Both A and B have the same sign
                if (A_reg[5] == 0 && B_reg[5] == 0) begin  // Both A and B are positive
                    if (A_reg == B_reg) 
                        EQ <= 1;  // Set EQ if A equals B
                    else if (A_reg > B_reg) 
                        GT <= 1;  // Set GT if A is greater than B
                    else 
                        LT <= 1;  // Set LT if A is less than B
                end 
                else if (A_reg[5] == 1 && B_reg[5] == 1) begin  // Both A and B are negative
                    if (A_reg == B_reg) 
                        EQ <= 1;  // Set EQ if A equals B
                    else if ((~A_reg + 1) < (~B_reg + 1)) 
                        GT <= 1;  // Set GT if A is less than B (by comparing 2's complement)
                    else 
                        LT <= 1;  // Set LT if A is greater than B
                end
            end
        end
    end
endmodule

///////////////////////////////////////////////////////////////////////////
module tb_comparator; 
    // Declare 6-bit registers for A and B, and registers for S (signed/unsigned selector) and clk (clock signal)
    reg [5:0] A, B;
    reg S, clk;
    
    // Declare wires for the outputs of the two comparator modules (structural and behavioral)
    wire EQ_structural, GT_structural, LT_structural;
    wire EQ_behavioral, GT_behavioral, LT_behavioral;

    // Clock generation process: toggles clk every 37 time units to create a clock period of 74 units
    always begin
        #37 clk = ~clk; 
    end

    // Instantiate the two comparator modules (behavioral and structural)
    comparatorBehavioral behavioral(A, B, S, clk, EQ_behavioral, GT_behavioral, LT_behavioral);
    signedOrUnsignedStructural structural(A, B, S, clk, EQ_structural, GT_structural, LT_structural);

    initial begin
        // Initialize signals
        clk = 0;  // Set initial clock value
        A = 6'b000000;  // Initialize A to 0
        B = 6'b000000;  // Initialize B to 0
        S = 0;  // Set S to 0 (unsigned comparison)

        // Run the testbench for 8192 cycles
        repeat (8192) begin	
            // Increment values of A, B, and S
            {A, B, S} = {A, B, S} + 1;
            
            // Wait for 74 time units before displaying the results
            #74;
            
            // Display the current values of A, B, S, and the results of both comparators
            $display("Time:%0t | A:%b B:%b S:%b | Structural [EQ:%b GT:%b LT:%b] | Behavioral [EQ:%b GT:%b LT:%b] | Test Result: %s", 
                     $time, A, B, S, EQ_structural, GT_structural, LT_structural, EQ_behavioral, GT_behavioral, LT_behavioral,
                     // Check if outputs from both comparators match and display "PASS" or "FAIL"
                     (EQ_structural == EQ_behavioral && GT_structural == GT_behavioral && LT_structural == LT_behavioral) ? "PASS" : "FAIL");

            // Increment values of A, B, and S again for the next cycle
            {A, B, S} = {A, B, S} + 1;
        end
    end
endmodule

///////////////////////////////////////////////////////////////////////////