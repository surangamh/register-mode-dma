### This tcl file includes all the commands from Vivado project creation all the way through bitstream generation

# Create Vivado project
#start_gui
create_project trafficgen_dma ./trafficgen_dma -part xc7z010clg400-1
# Set board part
set_property board_part digilentinc.com:zybo-z7-10:part0:1.0 [current_project]
# Add IP repo and update IP catalog
set_property  ip_repo_paths  ./ip_repo [current_project]
update_ip_catalog
#update_compile_order -fileset sources_1
#update_ip_catalog -rebuild -scan_changes
# Create block design
create_bd_design "design_1"
# Add PS to the design
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
endgroup
# Use HP port for memory access, use fabric interrupts
set_property -dict [list CONFIG.PCW_USE_S_AXI_HP0 {1} CONFIG.PCW_USE_FABRIC_INTERRUPT {1} CONFIG.PCW_IRQ_F2P_INTR {1}] [get_bd_cells processing_system7_0]
# Run connection automation
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]

#Add AXI DMA IP
startgroup
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0
endgroup

#Disable scatter gather DMA and disable read channel
set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_sg_include_stscntrl_strm {0} CONFIG.c_include_mm2s {0}] [get_bd_cells axi_dma_0]

# Run connection automation
startgroup
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/axi_dma_0/S_AXI_LITE} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/axi_dma_0/M_AXI_S2MM} Slave {/processing_system7_0/S_AXI_HP0} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins processing_system7_0/S_AXI_HP0]
endgroup
# Add IP repo path
#set_property  ip_repo_paths  /home/suranga/ip_repo [current_project]
# Set up traffic generator
startgroup
create_bd_cell -type ip -vlnv user.org:user:trafficgen:1.0 trafficgen_0
endgroup
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/processing_system7_0/FCLK_CLK0 (50 MHz)} Clk_slave {Auto} Clk_xbar {/processing_system7_0/FCLK_CLK0 (50 MHz)} Master {/processing_system7_0/M_AXI_GP0} Slave {/trafficgen_0/S00_AXI} ddr_seg {Auto} intc_ip {/ps7_0_axi_periph} master_apm {0}}  [get_bd_intf_pins trafficgen_0/S00_AXI]

# Make connections
connect_bd_net [get_bd_pins trafficgen_0/m00_axis_aclk] [get_bd_pins processing_system7_0/FCLK_CLK0]
connect_bd_net [get_bd_pins trafficgen_0/m00_axis_aresetn] [get_bd_pins rst_ps7_0_50M/peripheral_aresetn]
connect_bd_intf_net [get_bd_intf_pins trafficgen_0/M00_AXIS] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]
connect_bd_net [get_bd_pins processing_system7_0/IRQ_F2P] [get_bd_pins axi_dma_0/s2mm_introut]

save_bd_design

# Create wrapper
make_wrapper -files [get_files ./trafficgen_dma/trafficgen_dma.srcs/sources_1/bd/design_1/design_1.bd] -top
add_files -norecurse ./trafficgen_dma/trafficgen_dma.srcs/sources_1/bd/design_1/hdl/design_1_wrapper.v

# Implement the design all the way down to bitstream generation
launch_runs impl_1 -to_step write_bitstream -jobs 2

