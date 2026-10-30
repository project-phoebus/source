{ dbuf/dbuf.pas - the DBUF module, the disk buffer cache.

  Image addresses:
    sau2  0x00E78B58  DBUF data (.DATA, 0x920 bytes)

  One compilation unit: the map's DBUF code segment in .TEXT (0x770
  bytes: DBUF_$GET_BLOCK, DBUF_$SET_BUFF, DBUF_$INVALIDATE,
  DBUF_$UPDATE_VOL, DBUF_$INIT) and its data segment in .DATA (0x920
  bytes, map symbols DBUF and DBUF_$TROUBLE).  The heading names no
  sections (the defaults, ref 7.1.1).

  The data, 0x920 bytes, all zero in the image (DBUF_$INIT builds the
  list):

    +0x000  dbuf_$eventcount  0x0C
    +0x00C  unused_0c         4     nothing addresses it (TODO below)
    +0x010  DBUF              0x900 (map symbol, defined here) 64
                                    entries of 0x24
    +0x910  dbuf_spin_lock    4     ML_$SPIN_LOCK and _UNLOCK's lock

    +0x914  dbuf_$head        4     the LRU list's head
    +0x918  dbuf_$waiters     2
    +0x91A  dbuf_$count       2     the entries in use, compared signed
    +0x91C  DBUF_$TROUBLE     2     (map symbol, defined here)
    +0x91E  (2 bytes)               the block rounded to a longword

  Build (when dpc supports what this needs): dpc -I domain_os
  domain_os/dbuf/dbuf.pas.  Check: tools/pascal_check.sh.
}

{ TODO(pascal) the entry array at +0x10, 4 bytes after the eventcount

  The eventcount takes +0x00..+0x0B; the array of 0x24-byte entries
  starts at +0x10, where longword alignment would put it at +0x0C.
  Nothing addresses +0x0C..+0x0F.  The 8-byte alignment lead (objects of
  8 bytes or more at multiples of 8 in a data block) would explain it; dpc
  aligns to at most 4, so the stand-in unused_0c is declared. }
module dbuf;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'mmap/mmap.ins.pas';
%include 'wp/wp.ins.pas';
%include 'time/time.ins.pas';
%include 'netlog/netlog.ins.pas';
%include 'disk/disk.ins.pas';
%include 'dbuf/dbuf.ins.pas';

{ The global routines and variables this module defines (ref 7.3.4 and
  7.2.2, Method 2), in map order, and the module's own variables, in the
  order of the data block (above).  Where the defined variables go among
  the module's own: see the TODO(pascal) in log/log.pas. }
define
  dbuf_$get_block;
  dbuf_$set_buff;
  dbuf_$invalidate;
  dbuf_$update_vol;
  dbuf_$init;

var
  dbuf_$eventcount: ec_$eventcount_t;     { +0x000 }
  unused_0c: integer32;                   { +0x00C, see the TODO }

define
  dbuf;                                   { +0x010 }

var
  dbuf_spin_lock: integer32;              { +0x910 }
  dbuf_$head: dbuf_$entry_ptr_t;          { +0x914 }
  dbuf_$waiters: integer;                 { +0x918 }
  dbuf_$count: integer;                   { +0x91A }

define
  dbuf_$trouble;                          { +0x91C }

{ ---- .TEXT ---- }
%include 'dbuf/get_block.pas';              { DBUF_$GET_BLOCK    }
%include 'dbuf/set_buff.pas';               { DBUF_$SET_BUFF     }
%include 'dbuf/invalidate.pas';             { DBUF_$INVALIDATE   }
%include 'dbuf/update_vol.pas';             { DBUF_$UPDATE_VOL   }
%include 'dbuf/init.pas';                   { DBUF_$INIT         }
