{ mst/mst_wired.pas - the MST_WIRED module, the wired half of the segment
  tables.

  Image addresses:
    sau2  0x00E24304  MST_WIRED data (WIRED_DATA, 0x164 bytes)
    sau8  0x03C25EB0  MST_WIRED data (WIRED_DATA, 0x6E8 bytes)
    sau9  0x3C427298  MST_WIRED data (WIRED_DATA, 0xA58 bytes)

  One compilation unit: the map's MST_WIRED code segment in WIRED_PROC
  (0x570 bytes, MST_$VA_TO_SEGNO .. MST_$WIRE) and its data segment in
  WIRED_DATA (0x164 bytes).  The heading: `module mst_wired, wired_proc,
  wired_data;'.

  The data, 0x164 bytes, zero but for the 14 segment words from +0x146
  (the 68010's layout, in the define list below):

    +0x000  mst_$diskless_msg       0x80
    +0x080  mst_$asid_list          8     a set of ASIDs
    +0x088  mst_$map_alter_lock     0x12  (6 open bytes after it)
    +0x0A0  mst_$asid_allocate_lock 0x12  (6 open bytes after it)
    +0x0B8  mst_$asid_lock          0x12  (6 open bytes after it)

    +0x0D0  mst_asid_base           0x74  58 words
    +0x144  mst_$touch_count        2
    +0x146  mst_$global_b_size ..   2     14 segment words
            mst_$seg_tn
    +0x162  mst_$got_color          1     a boolean
    +0x163  (1 byte: the block's rounding)

  Build: dpc -I domain_os domain_os/mst/mst_wired.pas.  Check:
  tools/pascal_check.sh.
}
module mst_wired, wired_proc, wired_data;

%include 'base/base.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'uid/uid.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'mmap/mmap.ins.pas';
%include 'name/name.ins.pas';
%include 'file/file.ins.pas';
%include 'ast/ast.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'netlog/netlog.ins.pas';
%include 'area/area.ins.pas';
%include 'anon/anon.ins.pas';
%include 'peb/peb.ins.pas';
%include 'node/node.ins.pas';
%include 'mst/mst.ins.pas';
%include 'mst/mst_internal.ins.pas';

{ The global routines and variables this module defines (ref 7.3.4 and
  7.2.2, Method 2), in map order, the variables in the order of the data
  block (above), with the image's initial values.  Where a defined
  variable goes among the module's own: see the TODO(pascal) in
  log/log.pas. }

%if run_time_layout %then
{ With the layout chosen at boot, 0x6E8 bytes, zero but for the layout's
  words from +0x6B4 (the default layout's, in the define list below):

    +0x000  mst_$diskless_msg       0x80
    +0x080  mst_$asid_list          8
    +0x088  mst_$regions_active     0x3A0  16 bytes per ASID
    +0x428  bst_asid_base           0xE8   58 longwords
    +0x510  smap_asid_base          0xE8   58 longwords
    +0x5F8  mst_$map_alter_lock     0x12  (6 open bytes after it)
    +0x610  mst_$asid_allocate_lock 0x12  (6 open bytes after it)
    +0x628  mst_$asid_lock          0x12  (6 open bytes after it)
    +0x640  mst_asid_base           0x74   58 words
    +0x6B4  special_$seg            4
    +0x6B8  mst_$touch_count        2
    +0x6BA  region_$private_tn ..   2      8 region words
            region_$tn
    +0x6CA  mst_$global_b_size ..   2      14 segment words
            mst_$seg_tn
    +0x6E6  mst_$got_color          1
    +0x6E7  (1 byte: the block's rounding) }

define
  mst_$diskless_msg;                      { +0x000, zero }
  mst_$asid_list;                         { +0x080, zero }
  mst_$regions_active;                    { +0x088, zero }
  bst_asid_base;                          { +0x428, zero }
  smap_asid_base;                         { +0x510, zero }
  mst_$map_alter_lock;                    { +0x5F8, zero }
%elseif large_vm %then
{ The large VM layout's block, 0xA58 bytes, zero (the SAU9 map's
  MST_WIRED data segment):

    +0x000  mst_$diskless_msg       0x80
    +0x080  mst_$asid_list          8
    +0x088  mst_$regions_active     0x740  32 bytes per ASID
    +0x7C8  bst_asid_base           0xE8   58 longwords
    +0x8B0  smap_asid_base          0xE8   58 longwords
    +0x998  mst_$map_alter_lock     0x12  (6 open bytes after it)
    +0x9B0  mst_$asid_allocate_lock 0x12  (6 open bytes after it)
    +0x9C8  mst_$asid_lock          0x12  (6 open bytes after it)
    +0x9E0  mst_asid_base           0x74  58 words
    +0xA54  mst_$touch_count        2
    +0xA56  mst_$got_color          1
    +0xA57  (1 byte: the block's rounding) }

define
  mst_$diskless_msg;                      { +0x000, zero }
  mst_$asid_list;                         { +0x080, zero }
  mst_$regions_active;                    { +0x088, zero }
  bst_asid_base;                          { +0x7C8, zero }
  smap_asid_base;                         { +0x8B0, zero }
  mst_$map_alter_lock;                    { +0x998, zero }
%else
define
  mst_$diskless_msg;                      { +0x000, zero }
  mst_$asid_list;                         { +0x080, zero }
  mst_$map_alter_lock;                    { +0x088, zero }
%endif

var
  unused_9a: array[1..3] of integer;      { +0x09A, stand-in }

define
  mst_$asid_allocate_lock;                { +0x0A0, zero }

var
  unused_b2: array[1..3] of integer;      { +0x0B2, stand-in }

define
  mst_$asid_lock;                         { +0x0B8, zero }

var
  unused_ca: array[1..3] of integer;      { +0x0CA, stand-in }

define
  mst_asid_base;                          { +0x0D0, zero }
%if run_time_layout %then
  special_$seg := 16#03980000;            { +0x6B4 }
%endif
  mst_$touch_count;                       { +0x144 }
%if run_time_layout %then
  region_$private_tn := 26;               { +0x6BA }
  region_$private_a_size := 25;           { +0x6BC }
  region_$global_a := 16#19;              { +0x6BE }
  region_$global_a_size := 3;             { +0x6C0 }
  region_$global_b := 16#1D;              { +0x6C2 }
  region_$global_b_size := 3;             { +0x6C4 }
  region_$private_b := 16#1C;             { +0x6C6 }
  region_$tn := 32;                       { +0x6C8 }
  mst_$global_b_size := 192;              { +0x6CA }
  mst_$seg_mem_top := 16#800;             { +0x6CC }
  mst_$seg_high := 16#7F0;                { +0x6CE }
  mst_$seg_global_b_offset := 16#680;     { +0x6D0 }
  mst_$seg_global_b := 16#740;            { +0x6D2 }
  mst_$seg_private_b_offset := 16#C0;     { +0x6D4 }
  mst_$seg_private_b_end := 16#73F;       { +0x6D6 }
  mst_$seg_private_b := 16#700;           { +0x6D8 }
  mst_$seg_private_a_end := 16#63F;       { +0x6DA }
  mst_$private_a_size := 1600;            { +0x6DC }
  mst_$seg_global_a_end := 16#6FF;        { +0x6DE }
  mst_$seg_global_a := 16#640;            { +0x6E0 }
  mst_$global_a_size := 192;              { +0x6E2 }
  mst_$seg_tn := 1664;                    { +0x6E4 }
%elseif not large_address_space %then
  mst_$global_b_size := 96;               { +0x146 }
  mst_$seg_mem_top := 16#200;             { +0x148 }
  mst_$seg_high := 16#1F8;                { +0x14A }
  mst_$seg_global_b_offset := 16#140;     { +0x14C }
  mst_$seg_global_b := 16#1A0;            { +0x14E }
  mst_$seg_private_b_offset := 16#60;     { +0x150 }
  mst_$seg_private_b_end := 16#19F;       { +0x152 }
  mst_$seg_private_b := 16#198;           { +0x154 }
  mst_$seg_private_a_end := 16#137;       { +0x156 }
  mst_$private_a_size := 312;             { +0x158 }
  mst_$seg_global_a_end := 16#197;        { +0x15A }
  mst_$seg_global_a := 16#138;            { +0x15C }
  mst_$global_a_size := 96;               { +0x15E }
  mst_$seg_tn := 320;                     { +0x160 }
%endif
  mst_$got_color;                         { +0x162 }

define
  mst_$va_to_segno;
  mst_$touch;
  mst_$remove_seg;
%if pmap_threads %then
  mst_$unthread_pmap;
  mst_$bst_to_va;
  mst_$assoc;
  mst_$install_ioppn;
  mst_$remove_ioppn;
%endif
  mst_$find;
  mst_$wire;


{ ---- WIRED_PROC ---- }
%include 'mst/va_to_segno.pas';           { MST_$VA_TO_SEGNO }
%include 'mst/touch.pas';                 { MST_$TOUCH }
%include 'mst/remove_seg.pas';            { MST_$REMOVE_SEG }
%if pmap_threads %then
%include 'mst/unthread_pmap.pas';         { MST_$UNTHREAD_PMAP }
%include 'mst/bst_to_va.pas';             { MST_$BST_TO_VA }
%include 'mst/va_to_aste.pas';            { mst_$va_to_aste }
%include 'mst/assoc.pas';                 { MST_$ASSOC }
%include 'mst/install_ioppn.pas';         { MST_$INSTALL_IOPPN }
%include 'mst/remove_ioppn.pas';          { MST_$REMOVE_IOPPN }
%endif
%include 'mst/find.pas';                  { MST_$FIND }
%include 'mst/wire.pas';                  { MST_$WIRE }
