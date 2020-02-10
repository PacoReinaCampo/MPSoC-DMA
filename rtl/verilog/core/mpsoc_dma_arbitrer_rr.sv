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
//              MPSoC-RISCV CPU                                               //
//              Direct Access Memory Interface                                //
//              AMBA3 AHB-Lite Bus Interface                                  //
//              WishBone Bus Interface                                        //
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
 *   Francisco Javier Reina Campo <frareicam@gmail.com>
 */

module mpsoc_dma_arbitrer_rr #(
  parameter N = 2
)
  (
    input  [N-1:0] req,
    input  [N-1:0] gnt,
    output [N-1:0] nxt_gnt
  );

  //////////////////////////////////////////////////////////////////
  //
  // Variables
  //

  reg [N-1:0] mask [0:N-1];

  integer i,j;

  genvar k;

  //////////////////////////////////////////////////////////////////
  //
  // Module body
  //

  always @(*) begin
    for (i=0;i<N;i=i+1) begin
      mask[i] = {N{1'b0}};
      if(i>0)
        mask[i][i-1] = ~gnt[i-1];
      else
        mask[i][N-1] = ~gnt[N-1];
      for (j=2;j<N;j=j+1) begin
        if (i-j>=0)
          mask[i][i-j] = mask[i][i-j+1] & ~gnt[i-j];
        else if(i-j+1>=0)
          mask[i][i-j+N] = mask[i][i-j+1] & ~gnt[i-j+N];
        else
          mask[i][i-j+N] = mask[i][i-j+N+1] & ~gnt[i-j+N];
      end
    end
  end // always @ (*)

  generate
    for (k=0;k<N;k=k+1) begin
      assign nxt_gnt[k] = (~|(mask[k] & req) & req[k]) | (~|req & gnt[k]);
    end
  endgenerate
endmodule
