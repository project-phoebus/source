{ dir/dir_wired.pas - the DIR_WIRED module, DIR_'s wired eventcounts and
  exclusion locks.

  Image addresses:
    sau2  0x00E2C048  DIR_WIRED data (WIRED_DATA, 0x1BC bytes)

  A map module of data only: the DIR_WIRED segment in WIRED_DATA (444
  bytes, all zero), `module dir_wired, , wired_data;'.  DIR's routines
  name its objects by their absolute addresses, so they are this unit's
  globals; their extern declarations are in dir/dir.pas.

  The objects, in the map's order:
    +0x000  DIR_$WT_FOR_HDNL_EC   ec_$eventcount_t, 12 bytes
    +0x00C  (4 bytes up to the next symbol)
    +0x010  DIR_$WAIT_ECS         array[0..31] of ec_$eventcount_t, 384
                                  bytes

    +0x190  DIR_$LINK_BUF_MUTEX   ml_$exclusion_t, 20 bytes
    +0x1A4  (4 bytes up to the next symbol)
    +0x1A8  DIR_$MUTEX            ml_$exclusion_t, 20 bytes, to the
                                  map's size 444

  Check: tools/pascal_check.sh.
}
module dir_wired, , wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';

{ TODO(pascal) the two runs of 4 bytes between DIR_WIRED's objects

  The map puts DIR_$WAIT_ECS at +0x10, 4 bytes after the 0xC-byte
  DIR_$WT_FOR_HDNL_EC, and DIR_$MUTEX at +0x1A8, 4 bytes after the
  0x14-byte DIR_$LINK_BUF_MUTEX; dpc lays the four objects out back to
  back (+0x00, +0x0C, +0x18C, +0x1A0).  Every object starts at a
  multiple of 8 from the block, as if objects of 8 bytes or more were
  8-aligned in a data block; not settled.  Two 4-byte stand-ins
  (unused_00c, unused_1a4) put every object at its map offset and the
  block at the map's 0x1BC; nothing addresses them.  When the alignment
  rule is settled, dpc's own layout may replace them. }

var
  dir_$wt_for_hdnl_ec: extern ec_$eventcount_t;
  dir_$wait_ecs: extern array[0..31] of ec_$eventcount_t;
  dir_$link_buf_mutex: extern ml_$exclusion_t;
  dir_$mutex: extern ml_$exclusion_t;

define
  dir_$wt_for_hdnl_ec;                             { +0x000, zero }

var
  unused_00c: integer32;                           { +0x00C, zero: a
                                                     stand-in (TODO) }

define
  dir_$wait_ecs;                                   { +0x010, zero }
  dir_$link_buf_mutex;                             { +0x190, zero }

var
  unused_1a4: integer32;                           { +0x1A4, zero: a
                                                     stand-in (TODO) }

define
  dir_$mutex;                                      { +0x1A8, zero }
