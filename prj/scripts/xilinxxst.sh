#!/bin/bash
#------------------------------------------------------------------------------
#
# Copyright (C) 2011 Raul Fajardo
# Copyright (C) 2013 Joel Holdsworth <joel@airwebreathe.org.uk>
#
# This source file may be used and distributed without restriction provided
# that this copyright statement is not removed from the file and that any
# derivative work contains the original copyright notice and the associated
# disclaimer.
#
# This source file is free software; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This source is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public
# License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this source; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
#
#------------------------------------------------------------------------------

ROOT_DIR=$1
PROJECT=$2
DIR_OUTPUT=$3
PROJECT_FILE=$4
TOP_MODULE_NAME=$5
TOP_MODULE=$6
DEVICE_PART=$7

ENV=`uname -o`

function adaptpath
{
	if [ "$ENV" == "Cygwin" ]
	then
		local cygpath=`cygpath -w $1`
		echo "$cygpath"
	else
		echo "$1"
	fi
}

if [ ! -f $PROJECT ]
then
	echo "Unexistent project file."
	exit 1
fi

if [ -z "$DIR_OUTPUT" ]
then
	echo "Second argument should be the destintion file for the directory inclusions."
	exit 1
fi
echo -n "" > $DIR_OUTPUT

source $PROJECT

echo "set -tmpdir "./xst"" >> $DIR_OUTPUT
echo "run" >> $DIR_OUTPUT

DIR_PATH="-vlgincdir {"

for dir in "${PROJECT_DIR[@]}"
do
	adapted_dir=`adaptpath $ROOT_DIR/$dir`
	DIR_PATH="$DIR_PATH \"$adapted_dir\" "
done

DIR_PATH="$DIR_PATH }"
echo $DIR_PATH >> $DIR_OUTPUT

adapted_project_file=`adaptpath $ROOT_DIR/prj/xilinx/${PROJECT_FILE}`

cat >> $DIR_OUTPUT <<EOF
-ifn $adapted_project_file
-ifmt Verilog
-ofn ${TOP_MODULE_NAME}
-ofmt NGC
-p ${DEVICE_PART}
-top ${TOP_MODULE_NAME}
-opt_mode Speed
-opt_level 1
EOF

if [ -n "$TOP_MODULE" ]
then
	echo "-iobuf yes" >> $DIR_OUTPUT
else
	echo "-iobuf no" >> $DIR_OUTPUT
fi
