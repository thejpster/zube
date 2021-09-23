module dump();
    initial begin
        $dumpfile ("data_register.vcd");
        $dumpvars (0, data_register);
        #1;
    end
endmodule
