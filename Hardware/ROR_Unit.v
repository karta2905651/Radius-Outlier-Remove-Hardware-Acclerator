module DN ( clk, reset, pcd_addr, pcd_req, pcd_ready, pcd_data, nom_addr, nom_valid, nom_data, finish);

input               clk;
input               reset;
input               pcd_ready;
input      [127:0]   pcd_data;

output reg [13:0]   pcd_addr;
output reg          pcd_req;
output reg [13:0]   nom_addr;
output reg          nom_valid;
output reg          nom_data;
output reg          finish;

reg signed [31:0] x_current [0:15] , y_current [0:15] , z_current [0:15] ;
reg signed [31:0] x_cal , y_cal , z_cal ;

reg [13:0] current ;
reg [4:0] neighbor_num [0:15] ;

integer i ;

wire true_0 ;
wire true_1 ;
wire true_2 ;
wire true_3 ;
wire true_4 ;
wire true_5 ;
wire true_6 ;
wire true_7 ;
wire true_8 ;
wire true_9 ;
wire true_10 ;
wire true_11 ;
wire true_12 ;
wire true_13 ;
wire true_14 ;
wire true_15 ;

wire flag_num , flag_true ;


// FSM
reg [1:0] state , next_state ;
parameter cur_init = 2'd0 , cal_init = 2'd1 , calcute = 2'd2 , access_memory = 2'd3 ;

reg ok ;

always@(*)
begin
    case (state)
        cur_init :
            next_state = (ok) ? cal_init : cur_init ;
        cal_init :
            next_state = (ok) ? calcute : cal_init ;
        calcute :
            next_state = (ok) ? access_memory : calcute ;
        access_memory :
            next_state = (ok) ? cal_init : access_memory ;
    endcase
end

always@(posedge clk or posedge reset)
begin
    if (reset)
    begin
        state <= cur_init ;
    end
    else
    begin
        state <= next_state ;
    end
end


// ok
always@(*)
begin
    case(state)
        cur_init :
            ok = (pcd_addr[3:0] == 14'd15) ? 1'b1 : 1'b0 ;
        cal_init :
            ok = 1'b1 ;
        calcute :
            ok = ((pcd_addr == 14'd11738) || (flag_num && flag_true)) ? 1'b1 : 1'b0 ;
        access_memory :
            ok = (pcd_addr[3:0] == 14'd15) ? 1'b1 : 1'b0 ;
    endcase
end


// flag
assign flag_num = (neighbor_num[0] > 5'd20) && (neighbor_num[1] > 5'd20) && (neighbor_num[2] > 5'd20) && (neighbor_num[3] > 5'd20) && (neighbor_num[4] > 5'd20) && (neighbor_num[5] > 5'd20) && (neighbor_num[6] > 5'd20) && (neighbor_num[7] > 5'd20) && (neighbor_num[8] > 5'd20) && (neighbor_num[9] > 5'd20 ) && (neighbor_num[10] > 5'd20) && (neighbor_num[11] > 5'd20 ) && (neighbor_num[12] > 5'd20) && (neighbor_num[13] > 5'd20 ) && (neighbor_num[14] > 5'd20) && (neighbor_num[15] > 5'd20 );
assign flag_true = (true_0 || true_1 || true_2 || true_3 || true_4 || true_5 || true_6 || true_7 || true_8 || true_9 || true_10 || true_11 || true_12 || true_13 || true_14 || true_15) ;



// pcd_req
always@(posedge clk or posedge reset)
begin
    if (reset)
    begin
        pcd_req <= 1'b0 ;
    end
    else
    begin
        if (pcd_ready)
        begin
            pcd_req <= 1'b1 ;
        end
        else
        begin
            pcd_req <= 1'b0 ;
        end
    end
end



// pcd_addr
always@(posedge clk or posedge reset)
begin
    if (reset)
    begin
        pcd_addr <= 14'd0 ;
    end
    else
    begin
        if (pcd_ready)
        begin
            if (state == cur_init)
            begin
                pcd_addr <= current ;
            end
            else if (state == cal_init)
            begin
                pcd_addr <= 14'd0 ;
            end
            else if (state == calcute)
            begin
                if (ok)
                begin
                    pcd_addr <= 14'd11739 ;
                end
                else
                begin
                    pcd_addr <= pcd_addr + 14'd1 ;
                end
            end
            else
            begin
                pcd_addr <= current ;
            end
        end
        else
        begin
            pcd_addr <= 14'd0 ;
        end

    end
end



// current
always@(posedge clk or posedge reset)
begin
    if (reset)
    begin
        current <= 14'd0 ;
    end
    else
    begin
        if (pcd_ready)
        begin
            if (state == cal_init)
            begin
                current <= current - 14'd1 ;
            end
            else if (state == calcute)
            begin
                current <= current ;
            end
            else
            begin
                current <= current + 14'd1 ;
            end
        end
        else
        begin
            current <= 14'd0 ;
        end

    end
end


// 16 current_pcd

// x_current
always@(posedge clk or posedge reset)
begin
    if (reset)
    begin
        for ( i=0 ; i<=15 ; i=i+1)
        begin
            x_current[i] <= 32'd0 ;
        end
    end
    else
    begin
        if (pcd_ready)
        begin
            if ((state == cur_init) || ((state == access_memory) && nom_valid))
            begin
                if (pcd_addr > 14'd11738)
                begin
                    x_current[15] <= 32'd0 ;
                end
                else
                begin
                    x_current[15] <= pcd_data[127:96] ;
                end
                for ( i=0 ; i<=14 ; i=i+1)
                begin
                    x_current[i] <= x_current[i+1] ;
                end
            end
            else
            begin
                for ( i=0 ; i<=15 ; i=i+1)
                begin
                    x_current[i] <= x_current[i] ;
                end
            end
        end
        else
        begin
            for ( i=0 ; i<=15 ; i=i+1)
            begin
                x_current[i] <= 32'd0 ;
            end
        end
    end
end


// y_current
always@(posedge clk or posedge reset)
begin
    if (reset)
    begin
        for ( i=0 ; i<=15 ; i=i+1)
        begin
            y_current[i] <= 32'd0 ;
        end
    end
    else
    begin
        if (pcd_ready)
        begin
            if ((state == cur_init) || ((state == access_memory) && nom_valid))
            begin
                if (pcd_addr > 14'd11738)
                begin
                    y_current[15] <= 32'd0 ;
                end
                else
                begin
                    y_current[15] <= pcd_data[95:64] ;
                end
                for ( i=0 ; i<=14 ; i=i+1)
                begin
                    y_current[i] <= y_current[i+1] ;
                end
            end
            else
            begin
                for ( i=0 ; i<=15 ; i=i+1)
                begin
                    y_current[i] <= y_current[i] ;
                end
            end
        end
        else
        begin
            for ( i=0 ; i<=15 ; i=i+1)
            begin
                y_current[i] <= 32'd0 ;
            end
        end
    end
end


// z_current
always@(posedge clk or posedge reset)
begin
    if (reset)
    begin
        for ( i=0 ; i<=15 ; i=i+1)
        begin
            z_current[i] <= 32'd0 ;
        end
    end
    else
    begin
        if (pcd_ready)
        begin
            if ((state == cur_init) || ((state == access_memory) && nom_valid))
            begin
                if (pcd_addr > 14'd11738)
                begin
                    z_current[15] <= 32'd0 ;
                end
                else
                begin
                    z_current[15] <= pcd_data[63:32] ;
                end
                for ( i=0 ; i<=14 ; i=i+1)
                begin
                    z_current[i] <= z_current[i+1] ;
                end
            end
            else
            begin
                for ( i=0 ; i<=15 ; i=i+1)
                begin
                    z_current[i] <= z_current[i] ;
                end
            end
        end
        else
        begin
            for ( i=0 ; i<=15 ; i=i+1)
            begin
                z_current[i] <= 32'd0 ;
            end
        end
    end
end





// calcute_pcd

// x_cal
always@(posedge clk or posedge reset)
begin
    if (reset)
    begin
        x_cal <= 32'd0 ;
    end
    else
    begin
        if (pcd_ready)
        begin
            if (state == calcute)
            begin
                x_cal <= pcd_data[127:96] ;
            end
            else
            begin
                x_cal <= 32'd0 ;
            end
        end
        else
        begin
            x_cal <= 32'd0 ;
        end
    end
end



// y_cal
always@(posedge clk or posedge reset)
begin
    if (reset)
    begin
        y_cal <= 32'd0 ;
    end
    else
    begin
        if (pcd_ready)
        begin
            if (state == calcute)
            begin
                y_cal <= pcd_data[95:64] ;
            end
            else
            begin
                y_cal <= 32'd0 ;
            end
        end
        else
        begin
            y_cal <= 32'd0 ;
        end
    end
end



// z_cal
always@(posedge clk or posedge reset)
begin
    if (reset)
    begin
        z_cal <= 32'd0 ;
    end
    else
    begin
        if (pcd_ready)
        begin
            if (state == calcute)
            begin
                z_cal <= pcd_data[63:32]  ;
            end
            else
            begin
                z_cal <= 32'd0 ;
            end
        end
        else
        begin
            z_cal <= 32'd0 ;
        end
    end
end



// distance calcute
Distance_cal_cell D0 (.x_cal(x_cal) , .y_cal(y_cal) , .z_cal(z_cal) , .x_current(x_current[0]) , .y_current(y_current[0]) , .z_current(z_current[0]) , .true(true_0)) ;
Distance_cal_cell D1 (.x_cal(x_cal) , .y_cal(y_cal) , .z_cal(z_cal) , .x_current(x_current[1]) , .y_current(y_current[1]) , .z_current(z_current[1]) , .true(true_1)) ;
Distance_cal_cell D2 (.x_cal(x_cal) , .y_cal(y_cal) , .z_cal(z_cal) , .x_current(x_current[2]) , .y_current(y_current[2]) , .z_current(z_current[2]) , .true(true_2)) ;
Distance_cal_cell D3 (.x_cal(x_cal) , .y_cal(y_cal) , .z_cal(z_cal) , .x_current(x_current[3]) , .y_current(y_current[3]) , .z_current(z_current[3]) , .true(true_3)) ;
Distance_cal_cell D4 (.x_cal(x_cal) , .y_cal(y_cal) , .z_cal(z_cal) , .x_current(x_current[4]) , .y_current(y_current[4]) , .z_current(z_current[4]) , .true(true_4)) ;
Distance_cal_cell D5 (.x_cal(x_cal) , .y_cal(y_cal) , .z_cal(z_cal) , .x_current(x_current[5]) , .y_current(y_current[5]) , .z_current(z_current[5]) , .true(true_5)) ;
Distance_cal_cell D6 (.x_cal(x_cal) , .y_cal(y_cal) , .z_cal(z_cal) , .x_current(x_current[6]) , .y_current(y_current[6]) , .z_current(z_current[6]) , .true(true_6)) ;
Distance_cal_cell D7 (.x_cal(x_cal) , .y_cal(y_cal) , .z_cal(z_cal) , .x_current(x_current[7]) , .y_current(y_current[7]) , .z_current(z_current[7]) , .true(true_7)) ;
Distance_cal_cell D8 (.x_cal(x_cal) , .y_cal(y_cal) , .z_cal(z_cal) , .x_current(x_current[8]) , .y_current(y_current[8]) , .z_current(z_current[8]) , .true(true_8)) ;
Distance_cal_cell D9 (.x_cal(x_cal) , .y_cal(y_cal) , .z_cal(z_cal) , .x_current(x_current[9]) , .y_current(y_current[9]) , .z_current(z_current[9]) , .true(true_9)) ;
Distance_cal_cell D10 (.x_cal(x_cal) , .y_cal(y_cal) , .z_cal(z_cal) , .x_current(x_current[10]) , .y_current(y_current[10]) , .z_current(z_current[10]) , .true(true_10)) ;
Distance_cal_cell D11 (.x_cal(x_cal) , .y_cal(y_cal) , .z_cal(z_cal) , .x_current(x_current[11]) , .y_current(y_current[11]) , .z_current(z_current[11]) , .true(true_11)) ;
Distance_cal_cell D12 (.x_cal(x_cal) , .y_cal(y_cal) , .z_cal(z_cal) , .x_current(x_current[12]) , .y_current(y_current[12]) , .z_current(z_current[12]) , .true(true_12)) ;
Distance_cal_cell D13 (.x_cal(x_cal) , .y_cal(y_cal) , .z_cal(z_cal) , .x_current(x_current[13]) , .y_current(y_current[13]) , .z_current(z_current[13]) , .true(true_13)) ;
Distance_cal_cell D14 (.x_cal(x_cal) , .y_cal(y_cal) , .z_cal(z_cal) , .x_current(x_current[14]) , .y_current(y_current[14]) , .z_current(z_current[14]) , .true(true_14)) ;
Distance_cal_cell D15 (.x_cal(x_cal) , .y_cal(y_cal) , .z_cal(z_cal) , .x_current(x_current[15]) , .y_current(y_current[15]) , .z_current(z_current[15]) , .true(true_15)) ;

// neighbor_num_0
always@(posedge clk or posedge reset)
begin
    if (reset)
    begin
        for ( i=0 ; i<=15 ; i=i+1)
        begin
            neighbor_num[i] <= 5'd0 ;
        end
    end
    else
    begin
        if (pcd_ready)
        begin
            if (state == calcute)
            begin
                neighbor_num[0] <= (true_0 && neighbor_num[0] <= 5'd20) ? neighbor_num[0] + 5'd1 : neighbor_num[0] ;
                neighbor_num[1] <= (true_1 && neighbor_num[1] <= 5'd20) ? neighbor_num[1] + 5'd1 : neighbor_num[1] ;
                neighbor_num[2] <= (true_2 && neighbor_num[2] <= 5'd20) ? neighbor_num[2] + 5'd1 : neighbor_num[2] ;
                neighbor_num[3] <= (true_3 && neighbor_num[3] <= 5'd20) ? neighbor_num[3] + 5'd1 : neighbor_num[3] ;
                neighbor_num[4] <= (true_4 && neighbor_num[4] <= 5'd20) ? neighbor_num[4] + 5'd1 : neighbor_num[4] ;
                neighbor_num[5] <= (true_5 && neighbor_num[5] <= 5'd20) ? neighbor_num[5] + 5'd1 : neighbor_num[5] ;
                neighbor_num[6] <= (true_6 && neighbor_num[6] <= 5'd20) ? neighbor_num[6] + 5'd1 : neighbor_num[6] ;
                neighbor_num[7] <= (true_7 && neighbor_num[7] <= 5'd20) ? neighbor_num[7] + 5'd1 : neighbor_num[7] ;
                neighbor_num[8] <= (true_8 && neighbor_num[8] <= 5'd20) ? neighbor_num[8] + 5'd1 : neighbor_num[8] ;
                neighbor_num[9] <= (true_9 && neighbor_num[9] <= 5'd20) ? neighbor_num[9] + 5'd1 : neighbor_num[9] ;
                neighbor_num[10] <= (true_10 && neighbor_num[10] <= 5'd20) ? neighbor_num[10] + 5'd1 : neighbor_num[10] ;
                neighbor_num[11] <= (true_11 && neighbor_num[11] <= 5'd20) ? neighbor_num[11] + 5'd1 : neighbor_num[11] ;
                neighbor_num[12] <= (true_12 && neighbor_num[12] <= 5'd20) ? neighbor_num[12] + 5'd1 : neighbor_num[12] ;
                neighbor_num[13] <= (true_13 && neighbor_num[13] <= 5'd20) ? neighbor_num[13] + 5'd1 : neighbor_num[13] ;
                neighbor_num[14] <= (true_14 && neighbor_num[14] <= 5'd20) ? neighbor_num[14] + 5'd1 : neighbor_num[14] ;
                neighbor_num[15] <= (true_15 && neighbor_num[15] <= 5'd20) ? neighbor_num[15] + 5'd1 : neighbor_num[15] ;
            end
            else if (state == access_memory)
            begin
                neighbor_num[15] <= 5'd0 ;
                for ( i=0 ; i<=14 ; i=i+1)
                begin
                    neighbor_num[i] <= neighbor_num[i+1] ;
                end
            end
            else
            begin
                for ( i=0 ; i<=15 ; i=i+1)
                begin
                    neighbor_num[i] <= neighbor_num[i] ;
                end
            end
        end
        else
        begin
            for ( i=0 ; i<=15 ; i=i+1)
            begin
                neighbor_num[i] <= 5'd0 ;
            end
        end
    end
end



// nom_data
always@(posedge clk or posedge reset)
begin
    if (reset)
    begin
        nom_data <= 1'b0 ;
    end
    else
    begin
        if (pcd_ready)
        begin
            if (state == access_memory)
            begin
                nom_data <= (neighbor_num[0] > 5'd20) ? 1'b1 : 1'b0 ;
            end
            else
            begin
                nom_data <= 1'b0 ;
            end
        end
        else
        begin
            nom_data <= 1'b0 ;
        end
    end
end


// nom_valid
always@(posedge clk or posedge reset)
begin
    if (reset)
    begin
        nom_valid <= 1'b0 ;
    end
    else
    begin
        if (pcd_ready)
        begin
            if (state == access_memory)
            begin
                if (nom_addr[3:0] == 4'd15)
                begin
                    nom_valid <= 1'b0 ;
                end
                else
                begin
                    nom_valid <= 1'b1 ;
                end
            end
            else
            begin
                nom_valid <= 1'b0 ;
            end
        end
        else
        begin
            nom_valid <= 1'b0 ;
        end
    end
end


// nom_addr
always@(posedge clk or posedge reset)
begin
    if (reset)
    begin
        nom_addr <= 14'd0 ;
    end
    else
    begin
        if (pcd_ready)
        begin
            if (state == access_memory)
            begin
                nom_addr <= current - 14'd16 ;
            end
            else
            begin
                nom_addr <= nom_addr ;
            end
        end
        else
        begin
            nom_addr <= 14'd0 ;
        end
    end
end


always@(posedge clk or posedge reset)
begin
    if (reset)
    begin
        finish <= 1'b0 ;
    end
    else
    begin
        if (pcd_ready)
        begin
            if (state == access_memory)
            begin
                finish <= (nom_addr == 14'd11738) ? 1'b1 : finish ;
            end
            else
            begin
                finish <= finish ;
            end
        end
        else
        begin
            finish <= 1'b0 ;
        end
    end
end


endmodule


    module Distance_cal_cell(x_cal , y_cal , z_cal , x_current , y_current , z_current , true );

input signed [31:0] x_current , y_current , z_current ;
input signed [31:0] x_cal , y_cal , z_cal ;
output true ;

wire signed [31:0] x_bias , y_bias , z_bias ;
wire signed [63:0] x_mul , y_mul , z_mul ;
wire signed [63:0] distance ;

assign x_bias = x_cal - x_current ;
assign y_bias = y_cal - y_current ;
assign z_bias = z_cal - z_current ;

assign x_mul = x_bias * x_bias ;
assign y_mul = y_bias * y_bias ;
assign z_mul = z_bias * z_bias ;

assign distance = x_mul + y_mul + z_mul ;

assign true = (distance <= 64'h00000000_00A3D70A) ? 1'b1 : 1'b0 ;



endmodule

