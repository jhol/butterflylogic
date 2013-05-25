#------------------------------------------------------------------------------
#
# Copyright (C) 2013 Joel Holdsworth
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin St, Fifth Floor, Boston, MA 02110, USA
#
#------------------------------------------------------------------------------

PROJECT_DIR=prj/xilinx

syn: $(PROJECT_NAME).bit

include prj/xilinx/prj.mk

$(PROJECT_NAME)_top.ngc: $(PROJECT_DIR)/$(PROJECT_NAME)_top.xst \
	$(PROJECT_DIR)/$(PROJECT_NAME)_top.prj
	rm -rf xst
	mkdir xst
	xst -ifn "$(PROJECT_DIR)/$(PROJECT_NAME)_top.xst"

$(PROJECT_NAME).ngd: $(CONSTRAINT_DIR)/$(CONSTRAINT_FILE) $(PROJECT_NAME)_top.ngc
	ngdbuild -p ${DEVICE_PART} -uc $(CONSTRAINT_DIR)/$(CONSTRAINT_FILE) -aul \
	$(PROJECT_NAME)_top.ngc $(PROJECT_NAME).ngd

$(PROJECT_NAME).ncd: $(PROJECT_NAME).ngd
	map -bp -timing -cm speed -equivalent_register_removal on \
	-logic_opt on -ol high -power off -register_duplication on \
	-retiming on -w -xe n $(PROJECT_NAME).ngd

$(PROJECT_NAME)_par.ncd: $(PROJECT_NAME).ncd
	par -ol high -w -xe n $(PROJECT_NAME).ncd $(PROJECT_NAME)_par.ncd

$(PROJECT_NAME).bit: $(PROJECT_NAME)_par.ncd
	bitgen -d -w $(PROJECT_NAME)_par.ncd $(PROJECT_NAME).bit

.PHONY: syn_xilinx
