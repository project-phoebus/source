{ flp/flp.pas - the FLP_ module, the floppy disk driver (NEC uPD765 class
  controller, DN3xx).

  Image addresses:
    sau2  0x00E7AEF4  FLP_ data (.DATA, 0x13C bytes)
    sau8  0x03C902F4  FLP_ data (.DATA, 0x1FC bytes)

  One compilation unit, in two code sections and one data section: the
  map's FLP_ code segments in WIRED_PROC (0xAC bytes, FLP_$INT) and in
  .TEXT (0x8CC bytes: FLP_$REVALIDATE, FLP_DO_IO, FLP_$DO_IO, FLP_$CINIT,
  FLP_$DINIT, FLP_$SHUTDOWN, EXCS, SHAKE), and its FLP_ data segment in
  .DATA (0x13C bytes, with the map symbols FLP_$EC and FLP_$SREGS
  inside).

  FLP_DCTE is not this unit's: it lies in the map's DCTES data, the IO
  manager's static DCTEs (io/io.ins.pas), and holds the addresses of
  FLP_$CINIT (+0x0C) and FLP_$INT (+0x38) and the controller's base
  (+0x34).  The routine between FLP_$REVALIDATE and FLP_DO_IO has no map
  symbol: flp_format_track, module-local.  The map symbols without `$'
  (FLP_DO_IO, EXCS, SHAKE) are globals.

  The module name is the map segments' name, FLP_.  Its data are module
  variables in .DATA, the defaults, so the heading names no section (ref
  7.1.1).  FLP_$INT, in WIRED_PROC, reaches the block by its absolute
  address: it is headed `[section(wired_proc, wired_data)]', the code
  section's partner (there is no FLP_ block in WIRED_DATA).

  The data, 0x13C bytes:

    +0x000 flp_jump_table   7 longwords: nil, FLP_$SHUTDOWN, FLP_$DINIT,
                            FLP_$REVALIDATE, FLP_$DO_IO, nil, nil; its
                            address passed to DISK_$REGISTER
    +0x01C flp_sregs_array  8 words; not read
    +0x02C flp_fmt_cmd      FORMAT TRACK, 6 words

    +0x038 flp_w_038        9 words; not read
    +0x04A flp_rw_cmd       READ/WRITE DATA, 9 words
    +0x05C flp_w_05c        2 words 0; not read
    +0x060 FLP_$EC          defined (map symbol), 12 bytes 0
    +0x06C flp_w_06c        2 words 0; not read
    +0x070 FLP_$SREGS       defined (map symbol), 4 words 0

    +0x078 flp_unit_cyl     4 words 0
    +0x080 flp_io_buffer    26 4-byte sector IDs, 0 (the FORMAT TRACK
                            table)
    +0x0E8 flp_ctlr_table   2 slots of 8 bytes, 0
    +0x0F8 flp_l_0f8        0; not read
    +0x0FC flp_fmt_buf_pa   0

    +0x100 flp_w_100        0; not read
    +0x102 flp_fmt_n        3 (its low byte read)
    +0x104 flp_w_104        0; not read
    +0x106 flp_base_cmd     16#40
    +0x108 flp_specify_cmd  SPECIFY, 4 words
    +0x110 flp_sense_cmd    SENSE DRIVE STATUS, 2 words

    +0x114 flp_recal_cmd    RECALIBRATE, 2 words
    +0x118 flp_seek_cmd     SEEK, 4 words
    +0x120 flp_unit_active  4 booleans 0
    +0x124 flp_disk_change  4 booleans 0
    +0x128 flp_buf_pa       0
    +0x12C flp_hw_addr      0, the controller base in use

    +0x130 flp_dma_retry    0
    +0x132 flp_cmd_retry    0
    +0x134 flp_w_134        0; not read
    +0x136 flp_unit_count   16#8000 (DISK_$REGISTER's units, by address)
    +0x138 flp_initialized  boolean 0
    +0x139 (3 bytes 0: the block's rounding to 4)

  The objects nothing reads are kept as variables with their bytes;
  their names are their offsets.

  The routines live in one fragment file each (flp/<name>.pas), included
  below in image order within each section.  None nests another.

  The SAU8's form (`floppy_atbus', base/config.ins.pas) is the other
  arm of the declarations and the include list: the controller on the AT
  bus, a block of 0x1FC bytes, and four routines more in .TEXT
  (FLP_$SHUT_DOWN_MOTOR, SET_FLP_TIMER, FLP_$TURN_MOTOR_ON,
  FLP_$MOTOR_CALLBACK; 0xCCC bytes with the rest).

  Its block holds FLP_$OVERRUN_REC, FLP_$OVRRUN_CTR, FLP_$USED and
  FLP_$MOTOR_ON besides FLP_$EC and FLP_$SREGS.  Each module variable
  starts on a word, so its last booleans take two bytes each.

  Only the SAUs with the floppy have the module (the part `floppy_disk',
  base/config.ins.pas: the SAU2, SAU4, SAU7 and SAU8); the SAU5's map
  has no FLP_ segment, so there the whole body is configured out, as
  FLP_DCTE is in io/dctes.pas.

  Build: dpc -I domain_os domain_os/flp/flp.pas.  Check:
  tools/pascal_check.sh.
}
module flp_;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%if floppy_disk %then
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'wp/wp.ins.pas';
%include 'dma/dma.ins.pas';
%include 'parity/parity.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'io/io.ins.pas';
%include 'disk/disk.ins.pas';
%include 'flp/flp.ins.pas';

%if floppy_atbus %then
{ The AT bus controller's form (`floppy_atbus'; the SAU8's FLP_ data
  segment, 0x1FC bytes): the routines in map order, then the block's
  objects in its order, the map symbols defined where they lie. }
define
  flp_$int;
  flp_$revalidate;
  flp_$shut_down_motor;
  set_flp_timer;
  flp_$turn_motor_on;
  flp_$motor_callback;
  flp_do_io;
  flp_$do_io;
  flp_$cinit;
  flp_$dinit;
  flp_$shutdown;
  excs;
  shake;

var
  flp_jump_table: array[0..6] of univ_ptr :=     { +0x000 }
    [nil, addr(flp_$shutdown), addr(flp_$dinit), addr(flp_$revalidate),
     addr(flp_$do_io), nil, nil];
  unused_01c: integer32;                         { +0x01C }

define
  flp_$overrun_rec;                              { +0x020 }

var
  flp_w_070: array[0..5] of pinteger :=          { +0x070 }
    [16#0D, 0, 0, 16#1A, 16#1B, 16#4E];
  flp_fmt_cmd: array[0..5] of pinteger :=        { +0x07C }
    [16#4D, 0, 3, 8, 16#74, 16#4E];
  flp_w_088: array[0..8] of pinteger :=          { +0x088 }
    [0, 0, 0, 0, 0, 0, 16#1A, 7, 16#80];
  flp_rw_cmd: array[0..8] of pinteger :=         { +0x09A }
    [0, 0, 0, 0, 0, 3, 8, 16#35, 16#FF];
  flp_w_0ac: array[0..1] of pinteger;            { +0x0AC }

define
  flp_$ec;                                       { +0x0B0 }

var
  flp_w_0bc: array[0..1] of pinteger;            { +0x0BC }

define
  flp_$sregs;                                    { +0x0C0 }

var
  flp_unit_cyl: array[0..3] of pinteger;         { +0x0C8 }
  flp_io_buffer: array[1..26] of flp_$id_entry_t;  { +0x0D0 }
  flp_timer_elem: time_$queue_elem_t;            { +0x138 }
  unused_152: array[1..3] of integer;            { +0x152 }
  flp_ctlr_table: array[0..1] of flp_$ctlr_entry_t;  { +0x158 }
  flp_l_168: integer32;                          { +0x168 }
  flp_spin_lock: integer32;                      { +0x16C }
  unused_170: integer32;                         { +0x170 }

define
  flp_$ovrrun_ctr;                               { +0x174 }

var
  flp_ovrrun_va: univ_ptr;                       { +0x178 }
  flp_ovrrun_ppn: integer32;                     { +0x17C }
  unused_180: array[1..3] of integer32;          { +0x180 }
  flp_ovrrun_last: ^integer32;                   { +0x18C }
  flp_page_last: ^integer32;                     { +0x190 }
  flp_rb_param: ^integer32;                      { +0x194 }
  flp_rb_req: disk_$io_req_ptr_t;                { +0x198 }
  flp_motor_time: time_$clock_t :=               { +0x19C: 30000000 }
    [high := 16#1C9, low := 16#C380];
  unused_1a2: integer;                           { +0x1A2 }
  flp_w_1a4: pinteger;                           { +0x1A4 }
  flp_fmt_n: pinteger := 3;                      { +0x1A6 }
  flp_w_1a8: pinteger;                           { +0x1A8 }
  flp_base_cmd: pinteger := 16#40;               { +0x1AA }
  flp_specify_cmd: array[0..3] of pinteger :=    { +0x1AC }
    [3, 16#DF, 16#3C, 0];
  flp_sense_cmd: array[0..1] of pinteger :=      { +0x1B4 }
    [4, 0];
  flp_recal_cmd: array[0..1] of pinteger :=      { +0x1B8 }
    [7, 0];
  flp_seek_cmd: array[0..3] of pinteger :=       { +0x1BC }
    [16#0F, 0, 0, 0];
  flp_unit_active: array[0..3] of boolean;       { +0x1C4 }
  flp_disk_change: array[0..3] of boolean;       { +0x1C8 }
  flp_buf_pa: integer32;                         { +0x1CC }
  flp_hw_addr: flp_$regs_ptr_t;                  { +0x1D0 }
  flp_callback_arg: univ_ptr;                    { +0x1D4 }
  flp_fmt_buf_pa: integer32;                     { +0x1D8 }
  flp_fmt_buf_pa2: integer32;                    { +0x1DC }
  unused_1e0: integer32;                         { +0x1E0 }
  flp_dma_retry: integer;                        { +0x1E4 }
  flp_cmd_retry: integer;                        { +0x1E6 }
  flp_delay: integer;                            { +0x1E8 }
  flp_io_unit: io_$unit_num_t;                   { +0x1EA }
  flp_unit_count: pinteger := 16#8000;           { +0x1EC }
  flp_need_ovrrun_page: boolean := true;         { +0x1EE }
  flp_w_1f0: integer;                            { +0x1F0 }
  flp_b_1f2: boolean;                            { +0x1F2 }
  flp_fmt_ready: boolean;                        { +0x1F4 }

define
  flp_$used;                                     { +0x1F6 }
  flp_$motor_on;                                 { +0x1F8 }

{ ---- WIRED_PROC ---- }
%include 'flp/int.pas';                     { FLP_$INT }

{ ---- .TEXT ---- }
%include 'flp/revalidate.pas';              { FLP_$REVALIDATE }
%include 'flp/shut_down_motor.pas';         { FLP_$SHUT_DOWN_MOTOR }
%include 'flp/set_flp_timer.pas';           { SET_FLP_TIMER }
%include 'flp/turn_motor_on.pas';           { FLP_$TURN_MOTOR_ON }
%include 'flp/motor_callback.pas';          { FLP_$MOTOR_CALLBACK }
%include 'flp/format_track.pas';            { flp_format_track }
%include 'flp/flp_do_io.pas';               { FLP_DO_IO }
%include 'flp/do_io.pas';                   { FLP_$DO_IO }
%include 'flp/cinit.pas';                   { FLP_$CINIT }
%include 'flp/dinit.pas';                   { FLP_$DINIT }
%include 'flp/shutdown.pas';                { FLP_$SHUTDOWN }
%include 'flp/excs.pas';                    { EXCS }
%include 'flp/shake.pas';                   { SHAKE }
%else
{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order, then the module's variables and the two defined globals in the
  order of the block (as log/log.pas: see its TODO on where a defined
  extern variable is allocated). }
define
  flp_$int;
  flp_$revalidate;
  flp_do_io;
  flp_$do_io;
  flp_$cinit;
  flp_$dinit;
  flp_$shutdown;
  excs;
  shake;

var
  flp_jump_table: array[0..6] of univ_ptr :=     { +0x000 }
    [nil, addr(flp_$shutdown), addr(flp_$dinit), addr(flp_$revalidate),
     addr(flp_$do_io), nil, nil];
  flp_sregs_array: array[0..7] of pinteger :=    { +0x01C }
    [0, 0, 16#0D, 0, 0, 16#1A, 16#1B, 16#4E];
  flp_fmt_cmd: array[0..5] of pinteger :=        { +0x02C }
    [16#4D, 0, 3, 8, 16#74, 16#4E];
  flp_w_038: array[0..8] of pinteger :=          { +0x038 }
    [0, 0, 0, 0, 0, 0, 16#1A, 7, 16#80];
  flp_rw_cmd: array[0..8] of pinteger :=         { +0x04A }
    [0, 0, 0, 0, 0, 3, 8, 16#35, 16#FF];
  flp_w_05c: array[0..1] of pinteger;            { +0x05C }

define
  flp_$ec;                                       { +0x060 }

var
  flp_w_06c: array[0..1] of pinteger;            { +0x06C }

define
  flp_$sregs;                                    { +0x070 }

var
  flp_unit_cyl: array[0..3] of pinteger;         { +0x078 }
  flp_io_buffer: array[1..26] of flp_$id_entry_t;  { +0x080 }
  flp_ctlr_table: array[0..1] of flp_$ctlr_entry_t;  { +0x0E8 }
  flp_l_0f8: integer32;                          { +0x0F8 }
  flp_fmt_buf_pa: integer32;                     { +0x0FC }
  flp_w_100: pinteger;                           { +0x100 }
  flp_fmt_n: pinteger := 3;                      { +0x102 }
  flp_w_104: pinteger;                           { +0x104 }
  flp_base_cmd: pinteger := 16#40;               { +0x106 }
  flp_specify_cmd: array[0..3] of pinteger :=    { +0x108 }
    [3, 16#DF, 16#3C, 0];
  flp_sense_cmd: array[0..1] of pinteger :=      { +0x110 }
    [4, 0];
  flp_recal_cmd: array[0..1] of pinteger :=      { +0x114 }
    [7, 0];
  flp_seek_cmd: array[0..3] of pinteger :=       { +0x118 }
    [16#0F, 0, 0, 0];
  flp_unit_active: array[0..3] of boolean;       { +0x120 }
  flp_disk_change: array[0..3] of boolean;       { +0x124 }
  flp_buf_pa: integer32;                         { +0x128 }
  flp_hw_addr: flp_$regs_ptr_t;                  { +0x12C }
  flp_dma_retry: integer;                        { +0x130 }
  flp_cmd_retry: integer;                        { +0x132 }
  flp_w_134: pinteger;                           { +0x134 }
  flp_unit_count: pinteger := 16#8000;           { +0x136 }
  flp_initialized: boolean;                      { +0x138 }

{ ---- WIRED_PROC ---- }
%include 'flp/int.pas';                     { FLP_$INT }

{ ---- .TEXT ---- }
%include 'flp/revalidate.pas';              { FLP_$REVALIDATE }
%include 'flp/format_track.pas';            { flp_format_track }
%include 'flp/flp_do_io.pas';               { FLP_DO_IO }
%include 'flp/do_io.pas';                   { FLP_$DO_IO }
%include 'flp/cinit.pas';                   { FLP_$CINIT }
%include 'flp/dinit.pas';                   { FLP_$DINIT }
%include 'flp/shutdown.pas';                { FLP_$SHUTDOWN }
%include 'flp/excs.pas';                    { EXCS }
%include 'flp/shake.pas';                   { SHAKE }
%endif
%endif
