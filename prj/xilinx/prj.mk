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

PROJECTS = $(PROJECT_NAME)_top.prj
SRC_DIR = prj/src
SCRIPTS_DIR = prj/scripts
XILINX_PRJ_DIR = prj/xilinx

ROOT_DIR=.

XILINX_PRJ_FILES = $(addprefix $(XILINX_PRJ_DIR)/, \
	$(addsuffix .prj, $(basename $(PROJECTS))))
XILINX_XST_FILES = $(addprefix $(XILINX_PRJ_DIR)/, \
	$(addsuffix .xst, $(basename $(PROJECTS))))

$(XILINX_PRJ_DIR)/$(PROJECT_NAME)_top.xst: $(SRC_DIR)/$(PROJECT_NAME)_top.prj
	bash $(SCRIPTS_DIR)/xilinxxst.sh $(ROOT_DIR) $^ $@ \
		$(PROJECT_NAME)_top.prj $(PROJECT_NAME)_top topmodule \
		$(DEVICE_PART)

$(XILINX_PRJ_DIR)/$(PROJECT_NAME)_top.prj: $(SRC_DIR)/$(PROJECT_NAME)_top.prj
	bash $(SCRIPTS_DIR)/xilinxprj.sh $(ROOT_DIR) $^ $@ topmodule

$(XILINX_PRJ_DIR)/%.xst: $(SRC_DIR)/%.prj
	bash $(SCRIPTS_DIR)/xilinxxst.sh $(ROOT_DIR) $^ $@ $*.prj $*

$(XILINX_PRJ_DIR)/%.prj: $(SRC_DIR)/%.prj
	bash $(SCRIPTS_DIR)/xilinxprj.sh $(ROOT_DIR) $^ $@
