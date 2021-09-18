module dump();
    initial begin
        $dumpfile ("zube.vcd");
        $dumpvars (0, zube);
        #1;
    end
endmodule
