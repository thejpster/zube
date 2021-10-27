module dump();
    integer idx; // need integer for loop
    initial begin
        $dumpfile ("data_register.vcd");
        for (idx = 0; idx < (1 << data_register.DEPTH_BITS); idx = idx + 1) $dumpvars(0, data_register.contents[idx]);
        $dumpvars (0, data_register);
        #1;
    end
endmodule
