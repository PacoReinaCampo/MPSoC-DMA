////////////////////////////////////////////////////////////////////////////////
//                                            __ _      _     _               //
//                                           / _(_)    | |   | |              //
//                __ _ _   _  ___  ___ _ __ | |_ _  ___| | __| |              //
//               / _` | | | |/ _ \/ _ \ '_ \|  _| |/ _ \ |/ _` |              //
//              | (_| | |_| |  __/  __/ | | | | | |  __/ | (_| |              //
//               \__, |\__,_|\___|\___|_| |_|_| |_|\___|_|\__,_|              //
//                  | |                                                       //
//                  |_|                                                       //
//                                                                            //
//                                                                            //
//              Peripheral-GPIO for MPSoC                                     //
//              General Purpose Input Output for MPSoC                        //
//              AMBA4 APB-Lite Bus Interface                                  //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

/* Copyright (c) 2018-2019 by the author(s)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * =============================================================================
 * Author(s):
 *   Paco Reina Campo <pacoreinacampo@queenfield.tech>
 */

module peripheral_bfm_apb4 #(
  parameter PDATA_SIZE = 32
)
  (
    input                         PRESETn,
    input                         PCLK,

    output                        PSEL,
    output                        PENABLE,
    output     [             3:0] PADDR,
    output     [PDATA_SIZE/8-1:0] PSTRB,
    output     [PDATA_SIZE  -1:0] PWDATA,
    input      [PDATA_SIZE  -1:0] PRDATA,
    output                        PWRITE,
    input                         PREADY,
    input                         PSLVERR,

    input      [PDATA_SIZE  -1:0] gpio_o,
    input      [PDATA_SIZE  -1:0] gpio_oe,
    output reg [PDATA_SIZE  -1:0] gpio_i,

    input                         irq_o
  );

  //////////////////////////////////////////////////////////////////////////////
  //
  // Constants
  //

  localparam MODE      = 0;
  localparam DIRECTION = 1;
  localparam OUTPUT    = 2;
  localparam INPUT     = 3;
  localparam TYPE      = 4;
  localparam LVL0      = 5;
  localparam LVL1      = 6;
  localparam STATUS    = 7;
  localparam IRQ_ENA   = 8;

  localparam PSTRB_SIZE=PDATA_SIZE/8;

  localparam VERBOSE=0;

  //////////////////////////////////////////////////////////////////////////////
  //
  // Variables
  //
  int reset_watchdog;
  int got_reset;
  int errors;

  //////////////////////////////////////////////////////////////////////////////
  //
  // Instantiate the APB-Master
  //
  peripheral_bfm_master_apb4 #(
    .PADDR_SIZE (          4 ),
    .PDATA_SIZE ( PDATA_SIZE )
  )
  bfm_master_apb4 (
    .*
  );

  initial begin
      errors         = 0;
      reset_watchdog = 0;
      got_reset      = 0;

      forever begin
        reset_watchdog++;
        @(posedge PCLK);
        if (!got_reset && reset_watchdog == 1000) begin
          $fatal(-1,"PRESETn not asserted\nTestbench requires an APB reset");
        end
      end
    end

  always @(negedge PRESETn) begin
    //wait for reset to negate
    @(posedge PRESETn);
    got_reset = 1;

    repeat(5) @(posedge PCLK);

    welcome_text();

    //check reset values
    test_reset_register_values();

    //basic IO test
    test_io_basic();

    //random IO test
    test_io_random();

    //clear STATUS register test
    test_clear_status();

    //Trigger Level LOW test
    test_trigger_level_low();

    //Trigger level HI test
    test_trigger_level_high();

    //Trigger level random test
    test_trigger_level_random();

    //Trigger Falling-Edge test
    test_trigger_edge_fall();

    //Trigger Rising-Edge test
    test_trigger_edge_rise();

    //Trigger Random-Edge test
    test_trigger_edge_random();

    //IRQ test
    test_irq();

    //Finish simulation
    repeat (100) @(posedge PCLK);
    finish_text();
    $finish();
  end

  //////////////////////////////////////////////////////////////////////////////
  //
  // Tasks
  //
  task welcome_text();
    $display ("---------------------------------------------------------------------------------------------------------");
    $display ("                                                                                                         ");
    $display ("                                                                                                         ");
    $display ("                                                              ***                     ***          **    ");
    $display ("                                                            ** ***    *                ***          **   ");
    $display ("                                                           **   ***  ***                **          **   ");
    $display ("                                                           **         *                 **          **   ");
    $display ("    ****    **   ****                                      **                           **          **   ");
    $display ("   * ***  *  **    ***  *    ***       ***    ***  ****    ******   ***        ***      **      *** **   ");
    $display ("  *   ****   **     ****    * ***     * ***    **** **** * *****     ***      * ***     **     ********* ");
    $display (" **    **    **      **    *   ***   *   ***    **   ****  **         **     *   ***    **    **   ****  ");
    $display (" **    **    **      **   **    *** **    ***   **    **   **         **    **    ***   **    **    **   ");
    $display (" **    **    **      **   ********  ********    **    **   **         **    ********    **    **    **   ");
    $display (" **    **    **      **   *******   *******     **    **   **         **    *******     **    **    **   ");
    $display (" **    **    **      **   **        **          **    **   **         **    **          **    **    **   ");
    $display ("  *******     ******* **  ****    * ****    *   **    **   **         **    ****    *   **    **    **   ");
    $display ("   ******      *****   **  *******   *******    ***   ***  **         *** *  *******    *** *  *****     ");
    $display ("       **                   *****     *****      ***   ***  **         ***    *****      ***    ***      ");
    $display ("       **                                                                                                ");
    $display ("       **                                                                                                ");
    $display ("        **                                                                                               ");
    $display (" APB GPIO Testbench Initialized                                                                          ");
    $display ("---------------------------------------------------------------------------------------------------------");
  endtask : welcome_text

  task finish_text();
    if (errors>0) begin
        $display ("------------------------------------------------------------");
        $display (" APB GPIO Testbench failed with (%0d) errors @%0t", errors, $time);
        $display ("------------------------------------------------------------");
      end
    else begin
        $display ("------------------------------------------------------------");
        $display (" APB GPIO Testbench finished successfully @%0t", $time);
        $display ("------------------------------------------------------------");
      end
  endtask : finish_text

  task check (
    input string           name,
    input [PDATA_SIZE-1:0] actual,
    expected
  );
    if (VERBOSE > 2) $display("Checking %s for %b==%b", name, actual, expected);
    if (actual !== expected) error_msg(name, actual, expected);
  endtask : check

  task error_msg(
    input string           name,
    input [PDATA_SIZE-1:0] actual,
    expected
  );
    errors++;
    $display("ERROR  : Incorrect %s value. Expected: %b, received: %b @%0t", name, expected, actual, $time);
  endtask : error_msg

  //Reset Test. Test if all register are zero after reset
  task test_reset_register_values;
    logic [PDATA_SIZE-1:0] readdata;

    $display ("Checking reset values ...");

    //read register(s) contents
    bfm_master_apb4.read(MODE, readdata);
    check("MODE", readdata, {PDATA_SIZE{1'b0}});

    bfm_master_apb4.read(DIRECTION, readdata);
    check("DIRECTION", readdata, {PDATA_SIZE{1'b0}});

    bfm_master_apb4.read(OUTPUT, readdata);
    check("OUTPUT", readdata, {PDATA_SIZE{1'b0}});

    bfm_master_apb4.read(TYPE, readdata);
    check("TriggerType", readdata, {PDATA_SIZE{1'b0}});

    bfm_master_apb4.read(LVL0, readdata);
    check("TriggerLevelEdge0", readdata, {PDATA_SIZE{1'b0}});

    bfm_master_apb4.read(LVL1, readdata);
    check("TriggerLevelEdge1", readdata, {PDATA_SIZE{1'b0}});

    bfm_master_apb4.read(STATUS, readdata);
    check("STATUS", readdata, {PDATA_SIZE{1'b0}});

    bfm_master_apb4.read(IRQ_ENA, readdata);
    check("IRQ", readdata, {PDATA_SIZE{1'b0}});
  endtask : test_reset_register_values

  //Basic IO tests
  task test_io_basic;
    logic [PDATA_SIZE-1:0] readdata;

    $display ("Basic IO test ...");

    //basic output
    for (int mode=0; mode <= 1; mode++) begin
      for (int dir =0; dir <= 1; dir++) begin
        for (int d   =0; d <= 1<<PDATA_SIZE; d++) begin
          gpio_i = d;

          bfm_master_apb4.write(MODE     , {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{mode[0]}});
          bfm_master_apb4.write(DIRECTION, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{dir [0]}});
          bfm_master_apb4.write(OUTPUT   , {PSTRB_SIZE{1'b1}}, d);
          bfm_master_apb4.read (INPUT    , readdata);

          //check read data
          check("INPUT", readdata, d[PDATA_SIZE-1:0]);

          //check gpio_o/gpio_oe
          if (mode) begin
            //open-drain
            check("GPIO_OE", gpio_oe, {PDATA_SIZE{dir[0]}} & ~d[PDATA_SIZE-1:0]);
            check("GPIO_O ", gpio_o , {PDATA_SIZE{1'b0}});
          end
          else begin
            //push-pull
            check("GPIO_OE", gpio_oe, {PDATA_SIZE{dir[0]}});
            check("GPIO_O ", gpio_o , d[PDATA_SIZE-1:0]);
          end
        end
      end
    end
  endtask : test_io_basic

  //Random IO tests
  task test_io_random(input int runs=10000);
    logic [PDATA_SIZE-1:0] mode;
    logic [PDATA_SIZE-1:0] dir;
    logic [PDATA_SIZE-1:0] d;
    logic [PDATA_SIZE-1:0] readdata;
    logic [PDATA_SIZE-1:0] expected;

    $display ("Random IO test ...");

    //basic output
    for (int run=0; run < runs; run++) begin
        if (VERBOSE > 0) $display("Random IO test Run=%0d", run);
        mode=$random;
        dir =$random;
        d   =$random;

        gpio_i = $random;

        bfm_master_apb4.write(MODE     , {PSTRB_SIZE{1'b1}}, mode);
        bfm_master_apb4.write(DIRECTION, {PSTRB_SIZE{1'b1}}, dir );
        bfm_master_apb4.write(OUTPUT   , {PSTRB_SIZE{1'b1}}, d   );
        bfm_master_apb4.read (INPUT    , readdata);

        //check read data
        check($sformatf("INPUT   (%0d %0d %0d %0d)", run, mode, dir, d), readdata, gpio_i);

        //check gpio_o
        for (int b=0; b < PDATA_SIZE; b++) expected[b] = mode[b] ? 1'b0 : d[b];
        check($sformatf("GPIO_O  (%0d %0d %0d %0d)", run, mode, dir, d), gpio_o, expected);

        //check gpio_oe
        for (int b=0; b < PDATA_SIZE; b++) expected[b] = mode[b] ? dir[b] & ~d[b] : dir[b];
        check($sformatf("GPIO_OE (%0d %0d %0d %0d)", run, mode, dir, d), gpio_oe, expected);
      end //next run
  endtask : test_io_random

  //Clear STATUS test
  task test_clear_status;
    logic [PDATA_SIZE-1:0] readdata;

    $display ("Clear Status Register test ...");

    //drive gpio_i low
    gpio_i = {PDATA_SIZE{1'b0}};

    //set trigger type to level
    bfm_master_apb4.write(TYPE, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b0}});

    //enable LVL0
    bfm_master_apb4.write(LVL0, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b1}});

    //wait for data to propagate
    @(posedge PCLK);

    //read STATUS register
    bfm_master_apb4.read(STATUS, readdata);
    check("STATUS-0", readdata, {PDATA_SIZE{1'b1}});

    //disable LVL0
    bfm_master_apb4.write(LVL0, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b0}});

    //check STATUS register (should not have changed)
    bfm_master_apb4.read(STATUS, readdata);
    check("STATUS-1", readdata, {PDATA_SIZE{1'b1}});

    //clear STATUS register
    bfm_master_apb4.write(STATUS, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b1}});

    //check STATUS register
    bfm_master_apb4.read(STATUS, readdata);
    check("STATUS-2", readdata, {PDATA_SIZE{1'b0}});
  endtask : test_clear_status

  //Trigger Level Low test
  task test_trigger_level_low(input int runs=1<<PDATA_SIZE);
    logic [PDATA_SIZE-1:0] gpio_data,
    readdata;

    $display ("Trigger Level-Low test ...");

    //drive gpio_i high
    gpio_i = {PDATA_SIZE{1'b1}};

    //set trigger type to level
    bfm_master_apb4.write(TYPE, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b0}});

    //disble LVL1
    bfm_master_apb4.write(LVL1, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b0}});

    //enable LVL0
    bfm_master_apb4.write(LVL0, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b1}});

    for (int run=0; run < runs; run++) begin
      if (VERBOSE > 0) $display("  Trigger Level-Low test run=%0d", run);

      //clear STATUS register
      bfm_master_apb4.write(STATUS, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b1}});

      //drive gpio_i
      gpio_data = $random;
      gpio_i    = gpio_data;
      @(posedge PCLK);

      //drive gpio_i high
      gpio_i = {PDATA_SIZE{1'b1}};

      //wait for data to propagate
      repeat(3) @(posedge PCLK);

      //read STATUS register
      bfm_master_apb4.read(STATUS, readdata);
      check("STATUS", readdata, ~gpio_data);
    end
  endtask : test_trigger_level_low

  //Trigger Level High test
  task test_trigger_level_high(input int runs=1<<PDATA_SIZE);
    logic [PDATA_SIZE-1:0] gpio_data;
    logic [PDATA_SIZE-1:0] readdata;

    $display ("Trigger Level-High test ...");

    //drive gpio_i low
    gpio_i = {PDATA_SIZE{1'b0}};

    //set trigger type to level
    bfm_master_apb4.write(TYPE, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b0}});

    //disbale LVL0
    bfm_master_apb4.write(LVL0, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b0}});

    //enable LVL1
    bfm_master_apb4.write(LVL1, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b1}});

    for (int run=0; run < runs; run++) begin
      if (VERBOSE > 0) $display("  Trigger Level-High test run=%0d", run);

      //clear STATUS register
      bfm_master_apb4.write(STATUS, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b1}});

      //drive gpio_i
      gpio_data = $random;
      gpio_i    = gpio_data;
      @(posedge PCLK);

      //drive gpio_i high
      gpio_i = {PDATA_SIZE{1'b0}};

      //wait for data to propagate
      repeat(3) @(posedge PCLK);

      //read STATUS register
      bfm_master_apb4.read(STATUS, readdata);
      check("STATUS", readdata, gpio_data);
    end
  endtask : test_trigger_level_high

  //Trigger Level Random test
  task test_trigger_level_random(input int runs=10000);
    logic [PDATA_SIZE-1:0] lvl0;
    logic [PDATA_SIZE-1:0] lvl1;
    logic [PDATA_SIZE-1:0] gpio_data;
    logic [PDATA_SIZE-1:0] readdata;
    logic [PDATA_SIZE-1:0] expected;

    $display ("Trigger Level-Random test ...");

    //drive gpio_i high
    gpio_i = {PDATA_SIZE{1'b1}};

    //set trigger type to level
    bfm_master_apb4.write(TYPE, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b0}});

    for (int run=0; run < runs; run++) begin
      if (VERBOSE > 0) $display("  Trigger Level-Random test run=%0d", run);

      //disable LVL0
      bfm_master_apb4.write(LVL0, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b0}});

      //disable LVL1
      bfm_master_apb4.write(LVL1, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b0}});

      //clear STATUS register
      bfm_master_apb4.write(STATUS, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b1}});

      //drive gpio_i
      gpio_data = $random;
      gpio_i    = gpio_data;

      //wait for data to propagate
      repeat(4) @(posedge PCLK);

      //randomize level triggers
      lvl0 = $random;
      lvl1 = $random;
      bfm_master_apb4.write(LVL0, {PSTRB_SIZE{1'b1}}, lvl0);
      bfm_master_apb4.write(LVL1, {PSTRB_SIZE{1'b1}}, lvl1);

      //allow data to propagate
      @(posedge PCLK);

      //read STATUS register
      bfm_master_apb4.read(STATUS, readdata);

      for (int b=0; b<PDATA_SIZE; b++) begin
        expected[b] = (lvl0[b] & ~gpio_data[b]) | (lvl1[b] & gpio_data[b]);
      end

      check("STATUS", readdata, expected);
    end
  endtask : test_trigger_level_random

  //Trigger Falling Edge test
  task test_trigger_edge_fall(input int runs=4* 1<<PDATA_SIZE);
    logic [PDATA_SIZE-1:0] gpio_data0,
    gpio_data1,
    readdata,
    expected;

    $display ("Trigger Falling-Edge test ...");

    //set trigger type to edge
    bfm_master_apb4.write(TYPE, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b1}});

    //disble LVL1 (rising edge)
    bfm_master_apb4.write(LVL1, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b0}});

    //enable LVL0 (falling edge)
    bfm_master_apb4.write(LVL0, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b1}});

    for (int run=0; run < runs; run++) begin
      if (VERBOSE > 0) $display("  Trigger Falling-Edge test run=%0d", run);

      //drive 1st data onto gpio_i
      gpio_data0 = $random;
      gpio_i     = gpio_data0;
      @(posedge PCLK);

      //wait for data to propagate
      repeat(3) @(posedge PCLK);

      //clear STATUS register
      bfm_master_apb4.write(STATUS, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b1}});

      //drive 2nd data onto gpio_i
      gpio_data1 = $random;
      gpio_i     = gpio_data1;
      @(posedge PCLK);

      //wait for data to propagate (one extra stage for edge detector)
      repeat(4) @(posedge PCLK);

      //read STATUS register
      bfm_master_apb4.read(STATUS, readdata);

      for (int b=0; b<PDATA_SIZE; b++) begin
        expected[b] = gpio_data0[b] & ~gpio_data1[b];
      end

      check("STATUS", readdata, expected);
    end
  endtask : test_trigger_edge_fall

  //Trigger Rising Edge test
  task test_trigger_edge_rise(input int runs=4* 1<<PDATA_SIZE);
    logic [PDATA_SIZE-1:0] gpio_data0,
    gpio_data1,
    readdata,
    expected;

    $display ("Trigger Rising-Edge test ...");

    //set trigger type to edge
    bfm_master_apb4.write(TYPE, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b1}});

    //disble LVL0 (falling edge)
    bfm_master_apb4.write(LVL0, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b0}});

    //enable LVL1 (rising edge)
    bfm_master_apb4.write(LVL1, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b1}});

    for (int run=0; run < runs; run++) begin
      if (VERBOSE > 0) $display("  Trigger Rising-Edge test run=%0d", run);

      //drive 1st data onto gpio_i
      gpio_data0 = $random;
      gpio_i     = gpio_data0;
      @(posedge PCLK);

      //wait for data to propagate
      repeat(3) @(posedge PCLK);

      //clear STATUS register
      bfm_master_apb4.write(STATUS, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b1}});

      //drive 2nd data onto gpio_i
      gpio_data1 = $random;
      gpio_i     = gpio_data1;
      @(posedge PCLK);

      //wait for data to propagate (one extra stage for edge detector)
      repeat(4) @(posedge PCLK);

      //read STATUS register
      bfm_master_apb4.read(STATUS, readdata);

      for (int b=0; b<PDATA_SIZE; b++) begin
        expected[b] = ~gpio_data0[b] & gpio_data1[b];
      end

      check("STATUS", readdata, expected);
    end
  endtask : test_trigger_edge_rise

  //Trigger Rising Random test
  task test_trigger_edge_random(input int runs=40000);
    logic [PDATA_SIZE-1:0] gpio_data0;
    logic [PDATA_SIZE-1:0] gpio_data1;
    logic [PDATA_SIZE-1:0] lvl0;
    logic [PDATA_SIZE-1:0] lvl1;
    logic [PDATA_SIZE-1:0] readdata;
    logic [PDATA_SIZE-1:0] expected;

    $display ("Trigger Random-Edge test ...");

    //set trigger type to edge
    bfm_master_apb4.write(TYPE, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b1}});

    for (int run=0; run < runs; run++) begin
      if (VERBOSE > 0) $display("  Trigger Random-Edge test run=%0d", run);

      //randomize trigger edge(s)
      lvl0 = $random;
      lvl1 = $random;
      bfm_master_apb4.write(LVL0, {PSTRB_SIZE{1'b1}}, lvl0);
      bfm_master_apb4.write(LVL1, {PSTRB_SIZE{1'b1}}, lvl1);

      //drive 1st data onto gpio_i
      gpio_data0 = $random;
      gpio_i     = gpio_data0;
      @(posedge PCLK);

      //wait for data to propagate
      repeat(3) @(posedge PCLK);

      //clear STATUS register
      bfm_master_apb4.write(STATUS, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b1}});

      //drive 2nd data onto gpio_i
      gpio_data1 = $random;
      gpio_i     = gpio_data1;
      @(posedge PCLK);

      //wait for data to propagate (one extra stage for edge detector)
      repeat(4) @(posedge PCLK);

      //read STATUS register
      bfm_master_apb4.read(STATUS, readdata);

      for (int b=0; b<PDATA_SIZE; b++) begin
        expected[b] = (lvl0[b] &  gpio_data0[b] & ~gpio_data1[b]) | (lvl1[b] & ~gpio_data0[b] &  gpio_data1[b]);
      end

      check("STATUS", readdata, expected);
    end
  endtask : test_trigger_edge_random

  //IRQ test
  task test_irq;
    logic [PDATA_SIZE-1:0] gpio_data0,
    gpio_data1,
    lvl0,
    lvl1,
    readdata,
    expected;

    $display ("IRQ test ...");

    //disable all triggers
    bfm_master_apb4.write(LVL0, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b0}});
    bfm_master_apb4.write(LVL1, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b0}});

    //clear STATUS
    bfm_master_apb4.write(STATUS, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b1}});

    //IRQ should be low
    check("irq_o-0", irq_o, 1'b0);
    
    //Test 1, check if trigger propagates to IRQ

    //enable level-high triggers
    gpio_i = {PDATA_SIZE{1'b0}};
    bfm_master_apb4.write(TYPE, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b0}});
    bfm_master_apb4.write(LVL0, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b0}});
    bfm_master_apb4.write(LVL1, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b1}});

    //enable IRQs
    bfm_master_apb4.write(IRQ_ENA, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b1}});

    //trigger all inputs
    gpio_i = {PDATA_SIZE{1'b1}};
    @(posedge PCLK);
    gpio_i = {PDATA_SIZE{1'b0}};

    //wait for data to propagate (one more for irq_o flipflop)
    repeat(3) @(posedge PCLK);

    //check irq_o
    repeat(2) @(posedge PCLK); //it takes 2 cycles for irq_o to propagate and check
    check("irq_o-1", irq_o, 1'b1);
    
    //Test 2, test IRQ_ENA

    //disable IRQs
    bfm_master_apb4.write(IRQ_ENA, {PSTRB_SIZE{1'b1}}, {PDATA_SIZE{1'b0}});

    //check irq_o
    repeat(2) @(posedge PCLK);
    check("irq_o-2", irq_o, 1'b0);

    // Test 3, check STAT/ENA combination

    //Check STAT is all ones
    bfm_master_apb4.read(STATUS, readdata);
    check("STATUS", readdata, {PDATA_SIZE{1'b1}});

    for (int b=0; b < PDATA_SIZE; b++) begin
      //Enable bitwise IRQs
      bfm_master_apb4.write(IRQ_ENA, {PSTRB_SIZE{1'b1}}, 1<<b);

      //check irq_o
      repeat(2) @(posedge PCLK);
      check($sformatf("irq_o-3-%0d",b), irq_o, 1'b1);

      //clear status bit
      bfm_master_apb4.write(STATUS, {PSTRB_SIZE{1'b1}}, 1<<b);

      //check irq_o
      repeat(2) @(posedge PCLK);
      check($sformatf("irq_o-3-%0d",b), irq_o, 1'b0);
    end
  endtask : test_irq
endmodule : peripheral_bfm_apb4
