# 1. Load Everything
read_liberty /home/lee/OpenROAD/test/Nangate45/Nangate45_typ.lib
read_lef /home/lee/OpenROAD/test/Nangate45/Nangate45.lef
read_verilog pwm_netlist.v
link_design pwm_controller

# 2. Floorplan (60x60 um is plenty for this)
initialize_floorplan -die_area "0 0 100 100" -core_area "10 10 90 90" -site FreePDK45_38x28_10R_NP_162NW_34O
make_tracks

# 3. Placement
set_placement_padding -global -left 2 -right 2
place_pins -hor_layers metal1 -ver_layers metal2
global_placement
detailed_placement

# 4. The Clock Tree (Crucial for the 8-bit counter)
# Create a simple SDC file first or use this command:
create_clock -name clk -period 10.0 [get_ports clk]
clock_tree_synthesis

# 5. Route and View
global_route
detailed_route
gui::show
