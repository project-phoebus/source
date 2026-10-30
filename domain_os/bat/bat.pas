{ bat/bat.pas - the BAT_ module, the block allocation table.

  Image addresses:
    sau2  0x00E79478  BAT_ data (.DATA, 0xD54 bytes)

  One compilation unit, one code segment and one data segment: the map's
  BAT_ code segment in .TEXT (0xE60 bytes: BAT_$ALLOC_FM ..
  BAT_$GET_BAT_STEP, eleven routines, all global) and its BAT_ data
  segment in .DATA (0xD54 bytes, BAT_DATA its first symbol).  BAT_$UID
  is in UID_LIST's table (bat/bat.ins.pas).  The heading names no
  sections (dbuf/dbuf.pas's shape).

  The data, 0xD54 bytes, all zero in the image:

    +0x000  BAT_DATA             0xD38  defined (map symbol): six
                                        0x234-byte volume records from
                                        volume 1 (bat/bat.ins.pas)
    +0xD38  bat_$cached_buffer   4      the cached bitmap block
    +0xD3C  bat_$cached_block    4      its block number

    +0xD40  bat_$volume_flags    6      new-format flags from volume 1
    +0xD46  unused_d46           2      a stand-in, nothing addresses it
    +0xD48  bat_$mounted         6      mount flags from volume 1
    +0xD4E  bat_$cached_dirty    2      DBUF_$SET_BUFF's flags for the
                                        cached block
    +0xD50  bat_$cached_vol      2      its volume

    +0xD52  (2 bytes: the block's rounding to 4)

  Module variables, not statics: several routines share each object.
  As in netbuf/netbuf.pas, the define part and the var part are in the
  block's order.  Whether the original rounded arrays of booleans to
  longwords, or had a seventh flag, at +0xD46 is not known.

  The routines live in one fragment file each (bat/<name>.pas), included
  below in image order.  BAT_$ALLOC_FM and BAT_$ALLOC_VTOCE call
  BAT_$ALLOCATE before its body; its extern heading in bat.ins.pas comes
  first.

  Build: dpc -I domain_os domain_os/bat/bat.pas.  Check:
  tools/pascal_check.sh.
}
module bat_;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'node/node.ins.pas';
%include 'uid/uid.ins.pas';
%include 'disk/disk.ins.pas';
%include 'dbuf/dbuf.ins.pas';
%include 'fm/fm.ins.pas';
%include 'vtoc/vtoc.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'network/network.ins.pas';
%include 'bat/bat.ins.pas';

{ The module's own variables and the global it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above), the routines in
  map order. }
define
  bat_data;                               { +0x000, zero }

var
  bat_$cached_buffer: bat_$bitmap_ptr_t;  { +0xD38, zero (nil) }
  bat_$cached_block: linteger;            { +0xD3C }
  bat_$volume_flags: array[1..6] of boolean;   { +0xD40 }
  unused_d46: integer;                    { +0xD46, see above }
  bat_$mounted: array[1..6] of boolean;   { +0xD48 }
  bat_$cached_dirty: integer;             { +0xD4E }
  bat_$cached_vol: integer;               { +0xD50 }

define
  bat_$alloc_fm;
  bat_$add_part_vtoce;
  bat_$alloc_vtoce;
  bat_$allocate;
  bat_$free;
  bat_$mount;
  bat_$dismount;
  bat_$n_free;
  bat_$reserve;
  bat_$cancel;
  bat_$get_bat_step;

{ ---- .TEXT ---- }
%include 'bat/alloc_fm.pas';                { BAT_$ALLOC_FM }
%include 'bat/add_part_vtoce.pas';          { BAT_$ADD_PART_VTOCE }
%include 'bat/alloc_vtoce.pas';             { BAT_$ALLOC_VTOCE }
%include 'bat/allocate.pas';                { BAT_$ALLOCATE }
%include 'bat/free.pas';                    { BAT_$FREE }
%include 'bat/mount.pas';                   { BAT_$MOUNT }
%include 'bat/dismount.pas';                { BAT_$DISMOUNT }
%include 'bat/n_free.pas';                  { BAT_$N_FREE }
%include 'bat/reserve.pas';                 { BAT_$RESERVE }
%include 'bat/cancel.pas';                  { BAT_$CANCEL }
%include 'bat/get_bat_step.pas';            { BAT_$GET_BAT_STEP }
