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
SRC_OUTPUT=$3
TOP_MODULE=$4

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

if [ -z "$SRC_OUTPUT" ]
then
	echo "Third argument should be the destintion file for the source inclusions."
	exit 1
fi
echo -n "" > $SRC_OUTPUT

source $PROJECT

for file in "${PROJECT_SRC[@]}"
do
	FOUND=0

	for dir in "${PROJECT_DIR[@]}"
	do
		if [ -f $ROOT_DIR/$dir/$file ]
		then
			adapted_file=`adaptpath $ROOT_DIR/$dir/$file`
			echo -n '`include "' >> $SRC_OUTPUT
			echo -n "$adapted_file" >> $SRC_OUTPUT
			echo '"' >> $SRC_OUTPUT
			FOUND=1
			break
		fi
	done

	if [ $FOUND != 1 ]
	then
		echo "FILE NOT FOUND: $file"
		exit 1
	fi
done

