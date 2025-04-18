// Copyright 2022 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Authors:
// - Christopher Reinwardt <creinwar@ethz.ch>
// - Nicole Narr <narrn@ethz.ch>

`include "typedef.svh"

/// Protocol adapter which translates memory requests to the AXI4 protocol.
///
/// This module acts like an SRAM and makes AXI4 requests downstream.
///
/// Supports multiple outstanding requests and will have responses for reads **and** writes.
/// Response latency is not fixed and for sure **not 1** and depends on the AXI4 memory system.
/// The `mem_rsp_valid_o` can have multiple cycles of latency from the corresponding `mem_gnt_o`.
module axi_from_mem #(
  /// Memory request address width.
  parameter int unsigned    MemAddrWidth    = 32'd0,
  /// AXI4-Lite address width.
  parameter int unsigned    AxiAddrWidth    = 32'd0,
  /// Data width in bit of the memory request data **and** the Axi4-Lite data channels.
  parameter int unsigned    DataWidth       = 32'd0,
  /// How many requests can be in flight at the same time. (Depth of the response mux FIFO).
  parameter int unsigned    MaxRequests     = 32'd0,
  /// Protection signal the module should emit on the AXI4 transactions.
  parameter axi_pkg::prot_t AxiProt         = 3'b000,
  /// AXI4 request struct definition.
  parameter type            axi_req_t       = logic,
  /// AXI4 response struct definition.
  parameter type            axi_rsp_t       = logic
) (
  /// Clock input, positive edge triggered.
  input  logic                    clk_i,
  /// Asynchronous reset, active low.
  input  logic                    rst_ni,
  /// Memory slave port, request is active.
  input  logic                    mem_req_i,
  /// Memory slave port, request address.
  ///
  /// Byte address, will be extended or truncated to match `AxiAddrWidth`.
  input  logic [MemAddrWidth-1:0] mem_addr_i,
  /// Memory slave port, request is a write.
  ///
  /// `0`: Read request.
  /// `1`: Write request.
  input  logic                    mem_we_i,
  /// Memory salve port, write data for request.
  input  logic [DataWidth-1:0]    mem_wdata_i,
  /// Memory slave port, write byte enable for request.
  ///
  /// Active high.
  input  logic [DataWidth/8-1:0]  mem_be_i,
  /// Memory request is granted.
  output logic                    mem_gnt_o,
  /// Memory slave port, response is valid. For each request, regardless if read or write,
  /// this will be active once for one cycle.
  output logic                    mem_rsp_valid_o,
  /// Memory slave port, response read data. This is forwarded directly from the AXI4-Lite
  /// `R` channel. Only valid for responses generated by a read request.
  output logic [DataWidth-1:0]    mem_rsp_rdata_o,
  /// Memory request encountered an error. This is forwarded from the AXI4-Lite error response.
  output logic                    mem_rsp_error_o,
  /// AXI4 master port, slave aw cache signal
  input  axi_pkg::cache_t         slv_aw_cache_i,
  /// AXI4 master port, slave ar cache signal
  input  axi_pkg::cache_t         slv_ar_cache_i,
  /// AXI4 master port, request output.
  output axi_req_t                axi_req_o,
  /// AXI4 master port, response input.
  input  axi_rsp_t                axi_rsp_i
);

  `AXI_LITE_TYPEDEF_ALL(axi_lite, logic [AxiAddrWidth-1:0], logic [DataWidth-1:0], logic [DataWidth/8-1:0])
  axi_lite_req_t axi_lite_req;
  axi_lite_resp_t axi_lite_rsp;

  axi_lite_from_mem #(
    .MemAddrWidth    ( MemAddrWidth    ),
    .AxiAddrWidth    ( AxiAddrWidth    ),
    .DataWidth       ( DataWidth       ),
    .MaxRequests     ( MaxRequests     ),
    .AxiProt         ( AxiProt         ),
    .axi_req_t       ( axi_lite_req_t  ),
    .axi_rsp_t       ( axi_lite_resp_t )
  ) i_axi_lite_from_mem (
    .clk_i,
    .rst_ni,
    .mem_req_i,
    .mem_addr_i,
    .mem_we_i,
    .mem_wdata_i,
    .mem_be_i,
    .mem_gnt_o,
    .mem_rsp_valid_o,
    .mem_rsp_rdata_o,
    .mem_rsp_error_o,
    .axi_req_o       ( axi_lite_req    ),
    .axi_rsp_i       ( axi_lite_rsp    )
  );

  axi_lite_to_axi #(
    .AxiDataWidth    ( DataWidth       ),
    .req_lite_t      ( axi_lite_req_t  ),
    .resp_lite_t     ( axi_lite_resp_t ),
    .axi_req_t       ( axi_req_t       ),
    .axi_resp_t      ( axi_rsp_t       )
  ) i_axi_lite_to_axi (
    .slv_req_lite_i  ( axi_lite_req    ),
    .slv_resp_lite_o ( axi_lite_rsp    ),
    .slv_aw_cache_i,
    .slv_ar_cache_i,
    .mst_req_o       ( axi_req_o       ),
    .mst_resp_i      ( axi_rsp_i       )
  );

endmodule
