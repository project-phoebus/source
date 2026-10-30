{ pacct/pacct.pas - the PACCT module, process accounting.

  Image addresses:
    sau2  0x00E817EC  PACCT data (.DATA, 0x20 bytes)

  One compilation unit: the map's PACCT code segments in OS_INIT_PROC
  (PACCT_$INIT, headed `[section(os_init_proc, os_init_data)]', which
  reaches the block by its address) and in .TEXT (PACCT_$SHUTDN ..
  PACCT_$LOG, two module-local routines among them), and its data
  segment in .DATA (32 bytes).

  The data, all zero in the image, no map symbol inside:
    +0x00  pacct_owner          8 bytes, the accounting file's UID
    +0x08  pacct_lock_handle    4 bytes
    +0x0C  pacct_buf_remaining  4 bytes
    +0x10  pacct_write_ptr      4 bytes, where PACCT_$LOG copies to

    +0x14  pacct_map_offset     4 bytes, MST_$MAPS' map_info
    +0x18  pacct_map_ptr        4 bytes, MST_$MAPS' result
    +0x1C  pacct_file_pos       4 bytes
  The two pointers are integer32, advanced by 128 a record.

  Build: dpc -I domain_os domain_os/pacct/pacct.pas.  Check:
  tools/pascal_check.sh.
}
module pacct;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'time/time.ins.pas';
%include 'cal/cal.ins.pas';
%include 'mst/mst.ins.pas';
%include 'file/file.ins.pas';
%include 'acl/acl.ins.pas';
%include 'rgyc/rgyc.ins.pas';
%include 'pacct/pacct.ins.pas';

{ The global routines this module defines (ref 7.3.4), in map order. }
define
  pacct_$init;
  pacct_$shutdn;
  pacct_$start;
  pacct_$stop;
  pacct_$on;
  pacct_$log;

{ The module's variables, in the order of the block (above). }
var
  pacct_owner: uid_$t;                    { +0x00 }
  pacct_lock_handle: integer32;           { +0x08 }
  pacct_buf_remaining: integer32;         { +0x0C }
  pacct_write_ptr: integer32;             { +0x10 }
  pacct_map_offset: integer32;            { +0x14 }
  pacct_map_ptr: integer32;               { +0x18 }
  pacct_file_pos: integer32;              { +0x1C }

{ ---- OS_INIT_PROC ---- }
%include 'pacct/init.pas';                  { PACCT_$INIT }

{ ---- .TEXT ---- }
%include 'pacct/shutdn.pas';                { PACCT_$SHUTDN }
%include 'pacct/start.pas';                 { PACCT_$START }
%include 'pacct/stop.pas';                  { PACCT_$STOP }
%include 'pacct/on.pas';                    { PACCT_$ON }
%include 'pacct/compress.pas';              { pacct_$compress }
%include 'pacct/clock_to_comp.pas';         { pacct_$clock_to_comp }
%include 'pacct/log.pas';                   { PACCT_$LOG }
