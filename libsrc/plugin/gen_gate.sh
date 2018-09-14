#!/bin/sh
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2018 OpenLink Software
#
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#

#
#  Exit script on error
#
#set -e


#
#  Parse args
#
list=$1
[ -z "$list" ] && list="default.h"


#
#  Basename of plugin
#
outname=`echo "$list" | sed 's/.h//g'`


#
#  Make sure temp work directory is empty
#
[ -d tmp ] || mkdir tmp
rm -f tmp/*


#
#  Name of generated files
#
importh="import_$outname.h"
exportc="export_$outname.c"
importc="import_$outname.c"


#
# ======================================================================
#  Extract list of all include files needed
# ======================================================================
#
grep '^#include[ \t]*"[A-Za-z0-9./_-]*"' < $list > tmp/includes.txt


#
# ======================================================================
#  Generate helper script to extract EXE_EXPORT lines from include files
# ======================================================================
#
cat <<- "EOF" > tmp/process.sh
	gen_gate_4_file()
	{
	  grep 'EXE_EXPORT' < "$1" >> tmp/exports.txt
	}

EOF
sed 's/^#include\([ \t]*\)"\([A-Za-z0-9./_-]*\)"/gen_gate_4_file \2 #/g' < tmp/includes.txt >> tmp/process.sh

chmod a+x tmp/process.sh

#
#  Run helper script
#
./tmp/process.sh


#
# ======================================================================
#  Extract list of names
# ======================================================================
#

#
#  Extract EXE_EXPORT declarations
#
grep '^[ \t]*EXE_EXPORT[ \t]*([^,)]*,[ ]*[A-Za-z][A-Za-z0-9_]*[ \t]*,' < tmp/exports.txt > tmp/decls.txt


#
#  Extract export names from declarations
#
sed 's/^\([ \t]*\)EXE_EXPORT\([ \t]*\)(\([^,)]*\),\([ ]*\)\([A-Za-z][A-Za-z0-9_]*\)\([ \t]*\),\(.*\)$/\5@typeof__\5/g' < tmp/decls.txt > tmp/export_names_raw.txt

#
#  Extract EXE_EXPORT_TYPED type declarations
#
grep '^[ \t]*EXE_EXPORT_TYPED[ \t]*([ ]*[A-Za-z][A-Za-z0-9_]*[ \t]*,[ ]*[A-Za-z][A-Za-z0-9_]*[ \t]*)' < tmp/exports.txt > tmp/decls_t.txt

#
# Extract export names from type declarations
#
sed 's/^\([ \t]*\)EXE_EXPORT_TYPED\([ \t]*\)(\([ ]*\)\([A-Za-z][A-Za-z0-9_]*\)\([ \t]*\),\([ ]*\)\([A-Za-z][A-Za-z0-9_]*\)\([ \t]*\))\(.*\)$/\7@\4/g' < tmp/decls_t.txt >> tmp/export_names_raw.txt

#
#  Generate sorted list of uniq export names
#
sort -u < tmp/export_names_raw.txt > tmp/export_names.txt


#
# ======================================================================
#  Generate defines and types
# ======================================================================
#
sed 's/^\(.*\)$/#define \1 (_gate._\1._ptr)/g' < tmp/export_names.txt > tmp/gate_use.txt
sed 's/^\(.*\)$/  struct { typeof__\1 *_ptr; const char *_name; } _\1;/g' < tmp/export_names.txt > tmp/gate_decl.txt
sed 's/^\(.*\)$/  { NULL, "\1" },/g' < tmp/export_names.txt > tmp/gate_idef.txt
sed 's/^\(.*\)$/  { \&\1, "\1" },/g' < tmp/export_names.txt > tmp/gate_edef.txt

sed 's/^\([^@]*\)@\(.*\)$/#define \1 (_gate._\1._ptr)/g' < tmp/export_names.txt > tmp/gate_use.txt
sed 's/^\([^@]*\)@\(.*\)$/  struct { \2 *_ptr; const char *_name; } _\1;/g' < tmp/export_names.txt > tmp/gate_decl.txt
sed 's/^\([^@]*\)@\(.*\)$/  { NULL, "\1" },/g' < tmp/export_names.txt > tmp/gate_idef.txt
sed 's/^\([^@]*\)@\(.*\)$/  { \&\1, "\1" },/g' < tmp/export_names.txt > tmp/gate_edef.txt


#
# ======================================================================
#  Generate import gate header
# ======================================================================
#
cat <<- EOF > $importh.tmp
	/* This file is automatically generated by plugin/gen_gate.sh */
	#ifndef __gate_import_h_
	#define __gate_import_h_

	/* First we should include all imported header files to define data types of arguments and return values */
EOF

cat < tmp/includes.txt >> $importh.tmp

cat <<- EOF >> $importh.tmp

	/* Now we should declare dictionary structure with one member per one imported function. */
	/* At connection time, executable will fill an instance of this structure with actual pointers to functions. */
	struct _gate_s {
EOF

cat < tmp/gate_decl.txt >> $importh.tmp

cat <<- EOF >> $importh.tmp
	  struct { void *_ptr; const char *_name; } _gate_end;
	};

	/* Only one instance of _gate_s will exist, and macro definitions will be used to access functions of main executable */
	/* via members of this instance. */
	extern struct _gate_s _gate;

EOF

cat < tmp/gate_use.txt >> $importh.tmp

cat <<- EOF >> $importh.tmp

	#endif
EOF


#
# ======================================================================
#  Generate import gate source
# ======================================================================
#
cat <<- EOF >> $importc.tmp
	/* This file is automatically generated by plugin/gen_gate.sh */
	#include <stdlib.h>
	#include "$importh"

	struct _gate_s _gate = {
EOF

cat < tmp/gate_idef.txt >> $importc.tmp

cat <<- EOF >> $importc.tmp
	  { NULL, "." }
	};
EOF


#
# ======================================================================
#  Generate export gate source
# ======================================================================
#
cat <<- EOF > $exportc.tmp
	/* This file is automatically generated by plugin/gen_gate.sh */
	#define EXPORT_GATE
	#include "exe_export.h"
	#include <string.h>

	/* First we should include all imported header files to declare names of all exported functions */
EOF

cat < tmp/includes.txt >> $exportc.tmp

cat <<- EOF >> $exportc.tmp

	/* Now we should declare dictionary array with one item per one exported function. */
	/* At connection time, executable will fill _gate structures of plugins with data from this table. */

	extern _gate_export_item_t _gate_export_data[];

	int _gate_export (_gate_export_item_t *tgt)
	{
	  int err = 0;
	  _gate_export_item_t *src = _gate_export_data;
	  for (/* no init */; '.' != tgt->_name[0]; tgt++)
	    {
	      err = -1;
	      for (/* no init */; '.' != src->_name[0]; src++)
	        {
	          if (strcmp (src->_name, tgt->_name))
	            continue;
	          tgt->_ptr = src->_ptr;
	          err = 0;
	          break;
	        }
	      if (err)
	        break;
	    }
	  return err;
	}

	_gate_export_item_t _gate_export_data[] = {
EOF

cat < tmp/gate_edef.txt >> $exportc.tmp

cat <<- EOF >> $exportc.tmp
	  { NULL, "." }
	};
EOF


#
# ======================================================================
#  Compare newly generated version against current version 
#  to reduce unnecessary rebuilds
# ======================================================================
#
for i in $importh $exportc $importc
do
   cmp $i.tmp $i 2>/dev/null >/dev/null || mv $i.tmp $i
   rm -f $i.tmp
done

exit 0
