`timescale 1ns/10ps
`define CYCLE      7.0          	  // Modify your clock period here
`define SDFFILE    "./DN_syn.sdf"	  // Modify your sdf file name
`define End_CYCLE  10000000              // Modify cycle times once your design need more cycle times!
`define PCD        "./point_cloud_64bithex.dat"
`define NOM        "./DN_Verify_64bit.dat"


module testfixture;

parameter N_PCD   = 11739; //點雲數量
parameter N_NOM   = N_PCD;

reg   [127:0]   pcd_mem   [0:N_PCD-1];
reg           nom_mem    [0:N_NOM-1];

reg [7:0] NOM_dbg;
reg [7:0] exp_dbg;
wire nom_data;
reg   clk = 0;
reg   reset = 0;
reg   result_compare = 0 ;
integer cycle_total = 0 ;

integer err = 0;
integer times = 0;
reg over = 0;
integer exp_num = 0;
wire [13:0] pcd_addr;
wire [13:0]nom_addr;
reg [127:0] pcd_data;
reg pcd_ready = 0;
integer i;

DN DN( .clk(clk), .reset(reset),
       .pcd_addr(pcd_addr), .pcd_req(pcd_req), .pcd_ready(pcd_ready), .pcd_data(pcd_data),
       .nom_addr(nom_addr), .nom_valid(nom_valid), .nom_data(nom_data), .finish(finish));

nom_mem u_nom_mem(.nom_valid(nom_valid), .nom_data(nom_data), .nom_addr(nom_addr), .clk(clk));


`ifdef SDF

initial
    $sdf_annotate(`SDFFILE, DN);
`endif



initial
    $readmemh (`PCD, pcd_mem);
initial
    $readmemh (`NOM, nom_mem);

always
begin
    #(`CYCLE/2) clk = ~clk;
end

// initial
// begin
//     $fsdbDumpfile("DN.fsdb");
//     $fsdbDumpvars;
//     $fsdbDumpMDA;
// end

always @(posedge clk )
begin
    cycle_total = cycle_total + 1;
    if (cycle_total % 10000 == 0)  // 每 100000 個 clock 印一次
        $display("Cycle=%0d", $time, cycle_total);
end


initial
begin  // data input
    @(negedge clk)  reset = 1'b1;
    #(`CYCLE*2);
    reset = 1'b0;
    @(posedge clk)  pcd_ready <= 1'b1;
    while (finish == 0)
    begin
        if( pcd_req)
        begin
            pcd_data <= pcd_mem[pcd_addr];
        end
        else
        begin
            pcd_data <= 'hz;
        end
        @(negedge clk);
    end
    pcd_ready = 0;
    pcd_data='hz;
    @(posedge clk) result_compare = 1;
end

initial
begin // result compare
    $display("-----------------------------------------------------\n");
    $display("START!!! Simulation Start .....\n");
    $display("-----------------------------------------------------\n");
    #(`CYCLE*3);
    wait( finish ) ;
    @(posedge clk);
    @(posedge clk);
    for (i=0; i <N_PCD ; i=i+1)
    begin
        //@(posedge clk);  // TRY IT ! no comment this line for debugging !!
        exp_dbg = nom_mem[i];
        NOM_dbg = u_nom_mem.NOM_M[i];
        if (nom_mem[i] == u_nom_mem.NOM_M[i])
        begin
            err = err;
        end
        else
        begin
            //$display("pixel %d is FAIL !!", i);
            err = err+1;
            if (err <= 10)
                $display("Output point cloud %d are wrong!", i);
            if (err == 11)
            begin
                $display("Find the wrong point cloud reached a total of more than 10 !, Please check the code .....\n");
            end
        end
        if( ((i%1000) === 0) || (i == 11738))
        begin
            if ( err === 0)
                $display("Output point cloud: 0 ~ %d are correct!\n", i);
            else
                $display("Output point cloud: 0 ~ %d are wrong ! The wrong point cloud reached a total of %d or more ! \n", i, err);

        end
        exp_num = exp_num + 1;
    end
    over = 1;
end

initial
begin
    wait( finish ) ;
    $display ("**   RUN CYCLE = %11d  **",cycle_total);
end


initial
begin
    #(`End_CYCLE * `CYCLE );
    if (finish == 1'b0)
    begin
        $display("-----------------------------------------------------\n");
        $display("               Endcycle Is Too Short...!\n"             );
        $display("-------------------------FAIL------------------------\n");
        $display("-----------------------------------------------------\n");
    end
    else
    begin
        $display("-----------------------------------------------------\n");
        $display("Error!!! Somethings' wrong with your code ...!\n");
        $display("-------------------------FAIL------------------------\n");
        $display("-----------------------------------------------------\n");
    end
    $finish;
end

initial
begin
    @(posedge over)
     if((over) && (exp_num!='d0))
     begin
         $display("-----------------------------------------------------\n");
         if (err == 0)
         begin
             $display("Congratulations! All data have been generated successfully!\n");
             $display("-------------------------PASS------------------------\n");
         end
         else
         begin
             $display("There are %d errors!\n", err);
             $display("-----------------------------------------------------\n");

         end
     end
     #(`CYCLE/2);
    $finish;
end

endmodule


    module nom_mem (nom_valid, nom_data, nom_addr, clk);
input		    nom_valid;
input	[13:0] 	nom_addr;
input		    nom_data;
input		    clk;

reg [7:0] NOM_M [0:11738];
integer i;

initial
begin
    for (i=0; i<=11738; i=i+1)
        NOM_M[i] = 0;
end

always@(negedge clk)
    if (nom_valid)
        NOM_M[ nom_addr ] <= nom_data;

endmodule





