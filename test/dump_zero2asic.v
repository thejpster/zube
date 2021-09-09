module dump();
    initial begin
        $dumpfile ("zero2asic.vcd");
        $dumpvars (0, zero2asic);
        #1;
    end
endmodule
