// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

/*
 * jtag_pkg.sv
 * Francesco Conti <fconti@iis.ee.ethz.ch>
 * Antonio Pullini <pullinia@iis.ee.ethz.ch>
 */

package jtag_pkg;

   parameter int unsigned JTAG_SOC_INSTR_WIDTH                                 = 5;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_IDCODE                 = 5'b00001;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_DTMCSR                 = 5'b10000;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_DMIACCESS              = 5'b10001;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_AXIREG                 = 5'b00100;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_BBMUXREG               = 5'b00101;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_CLKGATEREG             = 5'b00110;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_CONFREG                = 5'b00111;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_TESTMODEREG            = 5'b01000;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_BISTREG                = 5'b01001;
   parameter logic [JTAG_SOC_INSTR_WIDTH-1:0]  JTAG_SOC_BYPASS                 = 5'b11111;
   parameter int unsigned JTAG_SOC_IDCODE_WIDTH                                = 32;
   parameter int unsigned JTAG_SOC_AXIREG_WIDTH                                = 96;
   parameter int unsigned JTAG_SOC_BBMUXREG_WIDTH                              = 21;
   parameter int unsigned JTAG_SOC_CLKGATEREG_WIDTH                            = 11;
   parameter int unsigned JTAG_SOC_CONFREG_WIDTH                               = 16;
   parameter int unsigned JTAG_SOC_TESTMODEREG_WIDTH                           =  4;
   parameter int unsigned JTAG_SOC_BISTREG_WIDTH                               = 20;

   parameter int unsigned JTAG_CLUSTER_INSTR_WIDTH                             = 5;
   parameter logic [JTAG_CLUSTER_INSTR_WIDTH-1:0]  JTAG_CLUSTER_IDCODE         = 5'b0010;
   parameter logic [JTAG_CLUSTER_INSTR_WIDTH-1:0]  JTAG_CLUSTER_SAMPLE_PRELOAD = 5'b0001;
   parameter logic [JTAG_CLUSTER_INSTR_WIDTH-1:0]  JTAG_CLUSTER_EXTEST         = 5'b0000;
   parameter logic [JTAG_CLUSTER_INSTR_WIDTH-1:0]  JTAG_CLUSTER_DEBUG          = 5'b1000;
   parameter logic [JTAG_CLUSTER_INSTR_WIDTH-1:0]  JTAG_CLUSTER_MBIST          = 5'b1001;
   parameter logic [JTAG_CLUSTER_INSTR_WIDTH-1:0]  JTAG_CLUSTER_BYPASS         = 5'b1111;
   parameter int unsigned JTAG_CLUSTER_IDCODE_WIDTH                            = 32;

   parameter int unsigned JTAG_IDCODE_WIDTH                                    = JTAG_SOC_IDCODE_WIDTH;
   parameter int unsigned JTAG_INSTR_WIDTH                                     = JTAG_SOC_INSTR_WIDTH;

   parameter DMI_SIZE = 32+7+2;

   task automatic jtag_wait_halfperiod(input int cycles);
      #(50000*cycles);
   endtask

   task automatic jtag_clock(
      input int cycles,
      ref logic s_tck
   );
      for(int i=0; i<cycles; i=i+1) begin
         s_tck = 1'b0;
         jtag_wait_halfperiod(1);
         s_tck = 1'b1;
         jtag_wait_halfperiod(1);
         s_tck = 1'b0;
      end
   endtask

   task automatic jtag_reset(
      ref logic s_tck,
      ref logic s_tms,
      ref logic s_trstn,
      ref logic s_tdi
   );
      s_tms   = 1'b0;
      s_tck   = 1'b0;
      s_trstn = 1'b0;
      s_tdi   = 1'b0;
      jtag_wait_halfperiod(2);
      s_trstn = 1'b1;
   endtask

   task automatic jtag_softreset(
      ref logic s_tck,
      ref logic s_tms,
      ref logic s_trstn,
      ref logic s_tdi
   );
      s_tms   = 1'b1;
      s_trstn = 1'b1;
      s_tdi   = 1'b0;
      jtag_clock(5, s_tck); //enter RST
      s_tms   = 1'b0;
      jtag_clock(1, s_tck); // back to IDLE
      $display("JTAG: SoftReset Done(%t)",$realtime);

   endtask

   class JTAG_reg #(int unsigned size = 32, logic [(JTAG_CLUSTER_INSTR_WIDTH+JTAG_SOC_INSTR_WIDTH)-1:0] instr = 'h0);

      task idle(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         s_trstn = 1'b1;
         // from SHIFT_DR to RUN_TEST : tms sequence 10
         s_tms   = 1'b1;
         s_tdi   = 1'b0;
         jtag_clock(1, s_tck);
         s_tms   = 1'b0;
         jtag_clock(1, s_tck);
      endtask

      task update_and_goto_shift(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         s_trstn = 1'b1;
         // from SHIFT_DR to RUN_TEST : tms sequence 110
         s_tms   = 1'b1;
         s_tdi   = 1'b0;
         jtag_clock(1, s_tck);
         s_tms   = 1'b1;
         jtag_clock(1, s_tck);
         s_tms   = 1'b0;
         jtag_clock(1, s_tck);
         jtag_clock(1, s_tck);
      endtask

      task jtag_goto_SHIFT_IR(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         s_trstn = 1'b1;
         s_tdi   = 1'b0;
         // from IDLE to SHIFT_IR : tms sequence 1100
         s_tms   = 1'b1;
         jtag_clock(2, s_tck);
         s_tms   = 1'b0;
         jtag_clock(2, s_tck);
      endtask

      task jtag_goto_SHIFT_DR(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         s_trstn = 1'b1;
         s_tdi   = 1'b0;
         // from IDLE to SHIFT_IR : tms sequence 100
         s_tms   = 1'b1;
         jtag_clock(1, s_tck);
         s_tms   = 1'b0;
         jtag_clock(2, s_tck);
      endtask

      task jtag_goto_UPDATE_DR_FROM_SHIFT_DR(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         //$display("I am at jtag_goto_UPDATE_DR_FROM_SHIFT_DR (%t)",$realtime);
         s_trstn = 1'b1;
         s_tdi   = 1'b1;
         // from SHIFT DR to UPDATE DR : tms sequence 11
         s_tms   = 1'b1;
         jtag_clock(1, s_tck);
         // back to Idle : tms sequence 0
         s_tms   = 1'b0;
         jtag_clock(50, s_tck);
      endtask

      task jtag_goto_CAPTURE_DR_FROM_UPDATE_DR_GETDATA(
         output logic [DMI_SIZE-1:0] dataout,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         //$display("I am at jtag_goto_CAPTURE_DR_FROM_UPDATE_DR_GETDATA (%t)",$realtime);
         s_trstn = 1'b1;
         s_tdi   = 1'b1;
         // from UPDATE DR to CAPTURE DR : tms sequence 10
         s_tms   = 1'b1;
         jtag_clock(1, s_tck);
         s_tms   = 1'b0;
         jtag_clock(1, s_tck);
         //back to Idle: tms sequence 110
         s_tms   = 1'b1;
         jtag_clock(2, s_tck);
         s_tms   = 1'b0;
         jtag_clock(1, s_tck);
         // go to SHIFT DR: tms sequence 100
         s_tms   = 1'b1;
         jtag_clock(1, s_tck);
         s_tms   = 1'b0;
         jtag_clock(2, s_tck);
         s_tms   = 1'b0;
         for(int i=0; i<DMI_SIZE; i=i+1) begin
            if (i == (DMI_SIZE-1))
               s_tms = 1'b1;
            s_tdi = 1'b0;
            jtag_clock(1, s_tck);
            dataout[i] = s_tdo;
         end

      endtask

      task jtag_goto_CAPTURE_DR_FROM_SHIFT_DR_GETDATA(
         output logic [DMI_SIZE-1:0] dataout,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         //$display("I am at jtag_goto_CAPTURE_DR_FROM_SHIFT_DR_GETDATA (%t)",$realtime);
         s_trstn = 1'b1;
         s_tdi   = 1'b1;
         // from UPDATE DR to CAPTURE DR : tms sequence 110
         s_tms   = 1'b1;
         jtag_clock(2, s_tck);
         s_tms   = 1'b0;
         jtag_clock(1, s_tck);
         // go to SHIFT DR
         s_tms   = 1'b0;
         jtag_clock(1, s_tck);
         s_tms   = 1'b0;
         for(int i=0; i<DMI_SIZE; i=i+1) begin
            if (i == (DMI_SIZE-1))
               s_tms = 1'b1;
            s_tdi = 1'b0;
            jtag_clock(1, s_tck);
            dataout[i] = s_tdo;
         end

      endtask

      task jtag_shift_SHIFT_IR(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         s_trstn = 1'b1;
         s_tms   = 1'b0;
         for(int i=0; i<JTAG_SOC_INSTR_WIDTH + JTAG_CLUSTER_INSTR_WIDTH; i=i+1) begin
            if (i==(JTAG_SOC_INSTR_WIDTH+JTAG_CLUSTER_INSTR_WIDTH-1))
                 s_tms = 1'b1;
            s_tdi = instr[i];
            jtag_clock(1, s_tck);
         end
      endtask

      task jtag_shift_NBITS_SHIFT_DR (
         input int unsigned     numbits,
         input logic[size-1:0]  datain,
         output logic[size-1:0] dataout,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         s_trstn = 1'b1;
         s_tms   = 1'b0;
         for(int i=0; i<numbits; i=i+1) begin
            if (i == (numbits-1))
               s_tms = 1'b1;
            s_tdi = datain[i];
            jtag_clock(1, s_tck);
            dataout[i] = s_tdo;
         end
      endtask

      task shift_nbits_noex(
         input int unsigned     numbits,
         input logic[size-1:0]  datain,
         output logic[size-1:0] dataout,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         s_trstn = 1'b1;
         s_tms   = 1'b0;
         for(int i=0; i<numbits; i=i+1) begin
            s_tdi = datain[i];
            jtag_clock(1, s_tck);
            dataout[i] = s_tdo;
         end
      endtask

      task start_shift(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         this.jtag_goto_SHIFT_DR(s_tck, s_tms, s_trstn, s_tdi);
      endtask

      task shift_nbits(
         input int unsigned     numbits,
         input logic[size-1:0]  datain,
         output logic[size-1:0] dataout,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
           this.jtag_shift_NBITS_SHIFT_DR(numbits, datain, dataout, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
      endtask

      task setIR(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         this.jtag_goto_SHIFT_IR(s_tck, s_tms, s_trstn, s_tdi);
         this.jtag_shift_SHIFT_IR(s_tck, s_tms, s_trstn, s_tdi);
         this.idle(s_tck, s_tms, s_trstn, s_tdi);
      endtask

      task shift(
         input logic[size-1:0]  datain,
         output logic[size-1:0] dataout,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         this.jtag_goto_SHIFT_DR(s_tck, s_tms, s_trstn, s_tdi);
         this.jtag_shift_NBITS_SHIFT_DR(size, datain, dataout, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.idle(s_tck, s_tms, s_trstn, s_tdi);
      endtask

   endclass

   task automatic jtag_get_idcode(
      ref logic s_tck,
      ref logic s_tms,
      ref logic s_trstn,
      ref logic s_tdi,
      ref logic s_tdo
   );
      automatic JTAG_reg #(.size(JTAG_IDCODE_WIDTH), .instr(JTAG_SOC_IDCODE)) jtag_idcode = new;
      logic [31:0] s_idcode;
      jtag_idcode.setIR(s_tck, s_tms, s_trstn, s_tdi);
      jtag_idcode.shift('0, s_idcode, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
      $display("JTAG: Tap ID: %h (%t)",s_idcode[31:0], $realtime);
      if(s_idcode[31:0] != 32'h249511C3) begin
         $display("JTAG: Tap ID Test FAILED (%t)", $realtime);
      end else begin
         $display("JTAG: Tap ID Test PASSED (%t)", $realtime);
      end
   endtask

   task automatic jtag_bypass_test(
      ref logic s_tck,
      ref logic s_tms,
      ref logic s_trstn,
      ref logic s_tdi,
      ref logic s_tdo
   );
      automatic JTAG_reg #(.size(255), .instr({JTAG_SOC_BYPASS, JTAG_SOC_BYPASS})) jtag_bypass = new;
                logic [255:0] result_data;
      automatic logic [255:0] test_data = {     32'hDEADBEEF, 32'h0BADF00D, 32'h01234567, 32'h89ABCDEF,
                                                32'hAAAABBBB, 32'hCCCCDDDD, 32'hEEEEFFFF, 32'h00001111};
      jtag_bypass.setIR(s_tck, s_tms, s_trstn, s_tdi);
      jtag_bypass.shift(test_data, result_data, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
      if (test_data[253:0] == result_data[255:2])
         $display("JTAG: Bypass Test Passed (%t)", $realtime);
      else
      begin
         $display("JTAG: Bypass Test Failed");
         $display("JTAG:   LSB WORD TEST = %h (%t)",test_data[31:0], $realtime);
         $display("JTAG:   LSB WORD RES  = %h (%t)",result_data[32:1], $realtime);
      end
   endtask

   class test_mode_if_t;

      task init(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         JTAG_reg #(.size(256), .instr(JTAG_SOC_CONFREG)) jtag_soc_dbg = new;
         jtag_soc_dbg.setIR(s_tck, s_tms, s_trstn, s_tdi);
         $display("[test_mode_if] %t - Init", $realtime);
      endtask

      task set_confreg(
         input  logic [8:0] confreg,
         output logic [8:0] dataout,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         JTAG_reg #(.size(256), .instr(JTAG_SOC_CONFREG)) jtag_soc_dbg = new;
         jtag_soc_dbg.start_shift(s_tck, s_tms, s_trstn, s_tdi);
         jtag_soc_dbg.shift_nbits(9, confreg, dataout, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         jtag_soc_dbg.idle(s_tck, s_tms, s_trstn, s_tdi);
         $display("[test_mode_if] %t - Setting confreg to value %X.", $realtime, confreg);
      endtask

      task get_confreg(
         input logic [8:0] confreg,
         output bit  [8:0] rec,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         logic [255:0] dataout;
         JTAG_reg #(.size(256), .instr(JTAG_SOC_CONFREG)) jtag_soc_dbg = new;
         jtag_soc_dbg.start_shift(s_tck, s_tms, s_trstn, s_tdi);
         jtag_soc_dbg.shift_nbits(9, confreg, dataout, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         jtag_soc_dbg.idle(s_tck, s_tms, s_trstn, s_tdi);
         rec = dataout [8:0];
         // `DEBUG_MANAGER_INST.printf(STDOUT, 0, $sformatf("%s[TEST_MODE_IF] %s%t - %sGet confreg value = %X%s\n", `ESC_BLUE_BOLD, `ESC_WHITE, $realtime, `ESC_MAGENTA, rec, `ESC_DEFAULT));
      endtask

   endclass

   class debug_mode_if_t;

      task init(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         //Read Info
         JTAG_reg #(.size(32), .instr(JTAG_SOC_DTMCSR)) jtag_soc_dbg = new;
         jtag_soc_dbg.setIR(s_tck, s_tms, s_trstn, s_tdi);
         $display("[debug_mode_if_t] %t - Init", $realtime);

      endtask

      task init_dmi(
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi
      );
         //Read Info
         JTAG_reg #(.size(32), .instr(JTAG_SOC_DMIACCESS)) jtag_soc_dbg = new;
         jtag_soc_dbg.setIR(s_tck, s_tms, s_trstn, s_tdi);
         $display("[debug_mode_if_t] %t - Init DMI Access", $realtime);

      endtask

      task read_dtmcs(
        // output logic [31:0] dataout,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         logic [31:0] dataout;
         JTAG_reg #(.size(32), .instr(JTAG_SOC_DTMCSR)) jtag_soc_dbg = new;
         jtag_soc_dbg.start_shift(s_tck, s_tms, s_trstn, s_tdi);
         jtag_soc_dbg.shift_nbits(32, '0, dataout, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         jtag_soc_dbg.idle(s_tck, s_tms, s_trstn, s_tdi);
         $display("[debug_mode_if] %t - Reading dtmcs %X.", $realtime, dataout);
         jtag_soc_dbg.start_shift(s_tck, s_tms, s_trstn, s_tdi);
         jtag_soc_dbg.shift_nbits(32, dataout, dataout, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         jtag_soc_dbg.idle(s_tck, s_tms, s_trstn, s_tdi);
      endtask



      task set_dmi(
         input  logic [1:0]  op_i,
         input  logic [6:0]  address_i,
         input  logic [31:0] data_i,
         output logic [DMI_SIZE-1:0]  data_o,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         logic [DMI_SIZE-1:0] buffer;
         JTAG_reg #(.size(DMI_SIZE), .instr(JTAG_SOC_DMIACCESS)) jtag_soc_dbg = new;
         jtag_soc_dbg.start_shift(s_tck, s_tms, s_trstn, s_tdi);
         jtag_soc_dbg.shift_nbits(DMI_SIZE, {address_i,data_i,op_i}, buffer, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         jtag_soc_dbg.jtag_goto_UPDATE_DR_FROM_SHIFT_DR(s_tck, s_tms, s_trstn, s_tdi);
         //#150us
         jtag_soc_dbg.jtag_goto_CAPTURE_DR_FROM_UPDATE_DR_GETDATA(buffer, s_tck, s_tms, s_trstn, s_tdi,s_tdo);
         while(buffer[1:0] == 2'b11) begin
            //$display("buffer is set_dmi is %x (OP %x address %x datain %x) (%t)",buffer, buffer[1:0], buffer[8:2], buffer[DMI_SIZE-1:9], $realtime);
            jtag_soc_dbg.jtag_goto_CAPTURE_DR_FROM_SHIFT_DR_GETDATA(buffer, s_tck, s_tms, s_trstn, s_tdi,s_tdo);
         end
         //$display("dataout is set_dmi is %x (OP %x address %x datain %x) (%t)",buffer, buffer[1:0], buffer[40:34],  buffer[33:2], $realtime);
         data_o[1:0]   = buffer[1:0];
         data_o[40:34] = buffer[40:34];
         data_o[33:2]  = buffer[33:2];
         jtag_soc_dbg.idle(s_tck, s_tms, s_trstn, s_tdi);

      endtask

      task set_sbreadonaddr(
         input logic sbreadonaddr,
         ref   logic s_tck,
         ref   logic s_tms,
         ref   logic s_trstn,
         ref   logic s_tdi,
         ref   logic s_tdo
      );

         automatic logic [1:0]         dm_op;
         automatic logic [31:0]        dm_data;
         automatic logic [6:0]         dm_addr;

         this.set_dmi(
            2'b01, //read
            7'h38, //sbcs,
            32'h0, //whatever
            {dm_addr, dm_data, dm_op},
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );
         dm_data[20] = sbreadonaddr;
         this.set_dmi(
            2'b10, //write
            7'h38, //sbcs,
            dm_data, //whatever
            {dm_addr, dm_data, dm_op},
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );
      endtask

      task set_sbautoincrement(
         input logic sbautoincrement,
         ref   logic s_tck,
         ref   logic s_tms,
         ref   logic s_trstn,
         ref   logic s_tdi,
         ref   logic s_tdo
      );

         automatic logic [1:0]         dm_op;
         automatic logic [31:0]        dm_data;
         automatic logic [6:0]         dm_addr;

         this.set_dmi(
            2'b01, //read
            7'h38, //sbcs,
            32'h0, //whatever
            {dm_addr, dm_data, dm_op},
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );
         dm_data[16] = sbautoincrement;
         this.set_dmi(
            2'b10, //write
            7'h38, //sbcs,
            dm_data, //whatever
            {dm_addr, dm_data, dm_op},
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );
      endtask

      task readMem(
         input  logic [31:0] addr_i,
         output logic [31:0] data_o,
         ref    logic s_tck,
         ref    logic s_tms,
         ref    logic s_trstn,
         ref    logic s_tdi,
         ref    logic s_tdo
      );

         automatic logic [1:0]         dm_op;
         automatic logic [31:0]        dm_data;
         automatic logic [6:0]         dm_addr;

         //NOTE sbreadonaddr must be 1

         //Write the Address
         this.set_dmi(
            2'b10,        //write
            7'h39,        //sbaddress0,
            addr_i,       //address
            {dm_addr, dm_data, dm_op},
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );

         this.set_dmi(
            2'b01,     //read
            7'h3C,     //sbdata0,
            32'h0,     //whatever
            {dm_addr, dm_data, dm_op},
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );

         data_o = dm_data;


      endtask

      task writeMem(
         input  logic [31:0] addr_i,
         input  logic [31:0] data_i,
         ref    logic s_tck,
         ref    logic s_tms,
         ref    logic s_trstn,
         ref    logic s_tdi,
         ref    logic s_tdo
      );

         automatic logic [1:0]         dm_op;
         automatic logic [31:0]        dm_data;
         automatic logic [6:0]         dm_addr;

         //NOTE sbreadonaddr must be 1

         //Write the Address
         this.set_dmi(
            2'b10,        //write
            7'h39,        //sbaddress0,
            addr_i,       //address
            {dm_addr, dm_data, dm_op},
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );

         this.set_dmi(
            2'b10,        //write
            7'h3C,        //sbdata0,
            data_i,      //data_i
            {dm_addr, dm_data, dm_op},
            s_tck,
            s_tms,
            s_trstn,
            s_tdi,
            s_tdo
         );

      endtask


      task load_L2(
         input int   num_stim,
         ref   logic [95:0] stimuli [100000:0],
         ref   logic s_tck,
         ref   logic s_tms,
         ref   logic s_trstn,
         ref   logic s_tdi,
         ref   logic s_tdo
      );

         automatic logic [1:0][31:0]   jtag_data;
         automatic logic [31:0]        jtag_addr;
         automatic logic [31:0]        spi_addr;
         automatic logic [31:0]        spi_addr_old;
         automatic logic               more_stim = 1;
         automatic logic [1:0]         dm_op;
         automatic logic [31:0]        dm_data;
         automatic logic [6:0]         dm_addr;

         spi_addr        = stimuli[num_stim][95:64]; // assign address
         jtag_data[0]    = stimuli[num_stim][63:0];  // assign data

         this.set_sbreadonaddr(1'b0, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.set_sbautoincrement(1'b0, s_tck, s_tms, s_trstn, s_tdi, s_tdo);

         $display("[JTAG] Loading L2 with jtag interface");

         spi_addr_old = spi_addr - 32'h8;

         while (more_stim) begin // loop until we have no more stimuli

            jtag_addr = stimuli[num_stim][95:64];
            for (int i=0;i<256;i=i+2) begin
               spi_addr       = stimuli[num_stim][95:64]; // assign address
               jtag_data[0]   = stimuli[num_stim][31:0];  // assign data
               jtag_data[1]   = stimuli[num_stim][63:32]; // assign data

               if (spi_addr != (spi_addr_old + 32'h8))
                  begin
                     spi_addr_old = spi_addr - 32'h8;
                     break;
                  end
               else begin
                  num_stim = num_stim + 1;
               end
               if (num_stim > $size(stimuli) || stimuli[num_stim]===96'bx ) begin // make sure we have more stimuli
                  more_stim = 0;                    // if not set variable to 0, will prevent additional stimuli to be applied
                  break;
               end
               spi_addr_old = spi_addr;

               this.set_dmi(
                  2'b10,           //write
                  7'h39,           //sbaddress0,
                  spi_addr[31:0], //bootaddress
                  {dm_addr, dm_data, dm_op},
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );

               this.set_dmi(
                  2'b10,           //write
                  7'h3C,           //sbdata0,
                  jtag_data[0],    //data
                  {dm_addr, dm_data, dm_op},
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );
               //$display("[JTAG] Loading L2 - Written %x at %x (%t)", jtag_data[0], spi_addr[31:0], $realtime);
               this.set_dmi(
                  2'b10,             //write
                  7'h39,             //sbaddress0,
                  spi_addr[31:0]+4, //bootaddress
                  {dm_addr, dm_data, dm_op},
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );

               this.set_dmi(
                  2'b10,           //write
                  7'h3C,           //sbdata0,
                  jtag_data[1],    //data
                  {dm_addr, dm_data, dm_op},
                  s_tck,
                  s_tms,
                  s_trstn,
                  s_tdi,
                  s_tdo
               );
            end
            $display("[JTAG] Loading L2 - Written up to %x (%t)", spi_addr[31:0]+4, $realtime);

         end
         this.set_sbreadonaddr(1'b1, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         this.set_sbautoincrement(1'b0, s_tck, s_tms, s_trstn, s_tdi, s_tdo);

      endtask

/*
      task get_confreg(
         input logic [8:0] confreg,
         output bit  [8:0] rec,
         ref logic s_tck,
         ref logic s_tms,
         ref logic s_trstn,
         ref logic s_tdi,
         ref logic s_tdo
      );
         logic [255:0] dataout;
         JTAG_reg #(.size(256), .instr(JTAG_SOC_CONFREG)) jtag_soc_dbg = new;
         jtag_soc_dbg.start_shift(s_tck, s_tms, s_trstn, s_tdi);
         jtag_soc_dbg.shift_nbits(9, confreg, dataout, s_tck, s_tms, s_trstn, s_tdi, s_tdo);
         jtag_soc_dbg.idle(s_tck, s_tms, s_trstn, s_tdi);
         rec = dataout [8:0];
         // `DEBUG_MANAGER_INST.printf(STDOUT, 0, $sformatf("%s[TEST_MODE_IF] %s%t - %sGet confreg value = %X%s\n", `ESC_BLUE_BOLD, `ESC_WHITE, $realtime, `ESC_MAGENTA, rec, `ESC_DEFAULT));
      endtask
*/
   endclass




endpackage
