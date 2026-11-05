{ io/dctes.pas - the DCTES module, the static device controller table
  entries and their list.

  Image addresses:
    sau2  0x00E2C8BC  DCTES data (WIRED_DATA, 0xD0 bytes)
    sau3  0x00E2B608  DCTES data (WIRED_DATA, 0xD0 bytes)
    sau4  0x0F82F3E0  DCTES data (WIRED_DATA, 0x168 bytes)
    sau5  0x00E2DB28  DCTES data (WIRED_DATA, 0x158 bytes)
    sau6  0x78030BC4  DCTES data (WIRED_DATA, 0x268 bytes)
    sau7  0x3C433850  DCTES data (WIRED_DATA, 0x3A4 bytes)
    sau8  0x03C2ED18  DCTES data (WIRED_DATA, 0x2A4 bytes)
    sau9  0x3C430FB4  DCTES data (WIRED_DATA, 0x774 bytes)

  A map module of data only, `module dctes, , wired_data;': the DCTES
  segment in WIRED_DATA, its DCTEs and DEV_DCTES, which lists them from
  the last to the first, ended by nil.  The units reach them by their
  absolute addresses.

  The SAU2's are RING_DCTE, FLP_DCTE and WIN_DCTE; the SAU5's CTAPE_DCTE
  (`ct_qic02'), SMD_DCTE_1 and SMD_DCTE_0 (`smd_disk'), RING_DCTE and
  WIN_DCTE; the SAU3's SMD_DCTE_1, SMD_DCTE_0 and RING_DCTE (no
  WIN_DCTE without `winchester_config'); the SAU4's SMD_DCTE_1,
  SMD_DCTE_0, RING_DCTE, FLP_DCTE and WIN_DCTE.  Each is kind 1, 64
  bytes, controller 0, with its init and interrupt routines and register
  block, but for the SAU4's FLP_DCTE (`floppy_dcte_request'), of kind 3
  as the SAU8's (below), on the system bus.

  The SAU9's (`named_dctes') are kind 2, 28 of them: two 802.5 rings,
  two Ethernets, two rings, eight SCSI tapes and eight SCSI disks (one
  per target), the SCSI bus, the timer and four serial lines.  Each has
  its unit's name and, at 0x1C, the PROM's device record for it
  (os/os.ins.pas's os_$prom_device_t, written as its bytes: its name is
  the longword at byte 3), which IO_$INIT matches
  against the PROM's configuration record; and, for the units with
  one, its I/O descriptor (io/io_desc.pas) in disk_dinit.

  The SAU8's (`named_dctes' too) are 17: two 802.5 rings, two
  Ethernets and two rings of kind 2, named, as the SAU9's; FLP_DCTE
  (`floppy_disk') and WIN8_DCTE (`winchester_ctlr') of kind 3, 76
  bytes, unnamed, whose bytes from 0x28 are the request their units'
  initialization routines give IO_$MAP_CSR (io/io.ins.pas's
  io_$acquire_rec_t: the interrupt, the CSR page, the AT bus), then the
  disk error queue's word; CTAPE_DCTE (`ct_qic02') of kind 2, unnamed,
  with its I/O descriptor.  DEV_DCTES lists them from WIN8_DCTE, then
  FLP_DCTE and CTAPE_DCTE, then the others from the last to the first,
  and after them the display drivers' DCTEs, which their own data
  segments hold (`color4_driver', `color5_driver', `mono_driver').

  The SAU7's are the SAU8's and three more: WIN7_DCTE_1 and WIN7_DCTE_0
  (`win_mailbox_ctlr'), the mailbox Winchester controllers' of kind 3,
  their requests' attributes bit 0 set, before WIN8_DCTE, and
  SCSI7_DCTE (`scsi_mailbox_ctlr'), the SCSI host adapter's of kind 2,
  unnamed, with its I/O descriptor, after it.  DEV_DCTES lists
  SCSI7_DCTE, WIN8_DCTE, WIN7_DCTE_0 and WIN7_DCTE_1 first, then the
  SAU8's from FLP_DCTE, and among the display drivers' DCTEs COLOR6's
  three units' first (`color6_driver') and COLOR7's last
  (`color7_driver').  The SAU9's DCTEs of the SCSI targets and its
  SCSI bus's are the NCR 53C90 driver's, not the mailbox adapter's.

  RING_DCTE's vector is 16#1B on the SAU2 and SAU3 (SYSBUS_$INIT
  installs it), 0 on the SAU5, 16#90 on the SAU4 (`sysbus_vectors_90',
  WIN_DCTE's too), 16#88 on the SAU6 (`sysbus_vectors_88': WIN_DCTE's
  and CTAPE_DCTE's 16#8C, WIN6_DCTE's and CTAPE6_DCTE's 16#90, the
  Ethernets' 16#F5 and 16#F6).

  The SAU6's are kind 1, nine of them: two Ethernets (`ethernet_driver'
  without `named_dctes', their register pages ETHERNET1 and ETHERNET2),
  CTAPE6_DCTE and WIN6_DCTE (`win6_ct6_board', the WIN6 page), and the
  SAU5's CTAPE_DCTE, SMD_DCTE_1, SMD_DCTE_0, RING_DCTE and WIN_DCTE.  The DCTEs are static_dcte_t, dcte_t with a univ_ptr init
  routine: dpc refuses the routines' `addr' as dcte_t's routine pointer.

  Check: tools/pascal_check.sh.
}

module dctes, , wired_data;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'ml/ml.ins.pas';
%include 'time/time.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'os/os.ins.pas';
%include 'io/io.ins.pas';
%include 'node/node.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'network/network.ins.pas';
%include 'netlog/netlog.ins.pas';
%include 'route/route.ins.pas';
%include 'sock/sock.ins.pas';
%include 'net/net.ins.pas';
%include 'rip/rip.ins.pas';
%include 'net_io/net_io.ins.pas';
%include 'mac_os/mac_os.ins.pas';
%include 'fim/fim.ins.pas';
%include 'mst/mst.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'parity/parity.ins.pas';
%include 'cal/cal.ins.pas';
%include 'dma/dma.ins.pas';
%include 'wp/wp.ins.pas';
%include 'disk/disk.ins.pas';
%include 'flp/flp.ins.pas';
%include 'win/win.ins.pas';
%include 'sm/sm.ins.pas';                     { SM_$CINIT, SM_BLK_HDR }
%include 'sm_c/sm_c.ins.pas';                 { SM_C_$CINIT }
%include 'ring/ring.ins.pas';
%include 'ring/ring_driver.ins.pas';
%if named_dctes or ethernet_driver %then
%include 'ethernet/ethernet.ins.pas';
%endif
%if named_dctes %then
%include 'timer/timer.ins.pas';
%endif

type
  { A static DCTE, 0x40 bytes: io/io.ins.pas's dcte_t with the init
    routine's cell a univ_ptr (above). }
  static_dcte_t = record
    kind: pinteger;                       { 0x00 }
    length: pinteger;                     { 0x02 }
    ctype: pinteger;                      { 0x04 }
    cnum: pinteger;                       { 0x06 }
    nextp: dcte_ptr_t;                    { 0x08 }
    csrsytr: univ_ptr;                    { 0x0C }
    cstatus: status_$t;                   { 0x10 }
    name: array[1..8] of char;            { 0x14 }
    reserved_1c: array[1..12] of char;    { 0x1C }
    vector_ptr: integer32;                { 0x28 }
    io_va: univ_ptr;                      { 0x2C }
    io_pa: integer32;                     { 0x30 }
    disk_dinit: univ_ptr;                 { 0x34 }
    disk_do_io: univ_ptr;                 { 0x38 }
    disk_error_que: integer32;            { 0x3C }
  end;

%if named_dctes or floppy_dcte_request %then
  { A kind-3 static DCTE, 0x4C bytes: static_dcte_t's first 0x28 bytes,
    then the unit's request (io/io.ins.pas's io_$acquire_rec_t, its CSR
    page's address a univ_ptr for the initializer's `addr'), then the
    disk error queue's word, which the floppy's initialization routine
    passes to DISK_$REGISTER as it passes the kind-1 DCTE's at 0x3C. }
  static_dcte3_t = record
    kind: pinteger;                       { 0x00 }
    length: pinteger;                     { 0x02 }
    ctype: pinteger;                      { 0x04 }
    cnum: pinteger;                       { 0x06 }
    nextp: dcte_ptr_t;                    { 0x08 }
    csrsytr: univ_ptr;                    { 0x0C }
    cstatus: status_$t;                   { 0x10 }
    name: array[1..8] of char;            { 0x14 }
    reserved_1c: array[1..12] of char;    { 0x1C }
    unused_28: integer32;                 { 0x28: the request's 0x00 }
    int: io_$int_info_t;                  { 0x2C }
    csr_va: univ_ptr;                     { 0x34 }
    csr_pa: linteger;                     { 0x38 }
    csr_pages: integer;                   { 0x3C }
    has_csr: boolean;                     { 0x3E }
    unused_3f: char;                      { 0x3F }
    tag: integer;                         { 0x40 }
    bus: integer;                         { 0x42 }
    attrs: io_$attr_t;                    { 0x44 }
    unused_46: integer;                   { 0x46 }
    disk_error_que: integer32;            { 0x48 }
  end;

%endif
%if named_dctes %then
{ Three of the SAU9 DCTEs' initialization routines, declared here as
  their headers do (ring_8025/ring_8025.ins.pas, win_scsi/win_scsi.ins.pas,
  sio16550/sio16550.ins.pas): those headers need their own modules'
  header sets, which conflict with this one.  Only their addresses are
  used. }
%if ring_8025_driver %then
function ring_8025_$init(var dcte: dcte_t): integer32; extern;
%endif
%if win_scsi_disk %then
function win_scsi_$cinit(var dcte: dcte_t): integer32; extern;
%endif
%if sio16550_lines %then
function sio16550_$init(var dcte: dcte_t): integer32; extern;
%endif
%if scsi_mailbox_ctlr %then
function scsi_$cinit(var dcte: dcte_t): integer32; extern;
%endif

var
  { The units' I/O descriptors (map symbols of IO_DESC,
    io/io_desc.pas).  Only their addresses are used. }
%if ring_8025_driver %then
  ring_8025_2_io_desc, ring_8025_1_io_desc: extern char;
%endif
%if ethernet_driver %then
  ethernet2_io_desc, ethernet1_io_desc: extern char;
%endif
%if ring8_controller %then
  ring2_io_desc, ring1_io_desc: extern char;
%endif
%if scsi_mailbox_ctlr %then
  scsi_io_desc: extern char;
%elseif scsi_driver %then
  scsi9_io_desc: extern char;
%endif
%if sio16550_lines %then
  sio3_io_desc, sio2_io_desc, sio1_io_desc, sio0_io_desc: extern char;
%endif
%if ct_qic02 %then
  tape_io_desc: extern char;
%endif

  { The pages of the floppy's and the Winchester's registers (map
    symbols of the I/O pages).  Only their addresses are used. }
%if floppy_disk %then
  flop: extern char;
%endif
%if win_mailbox_ctlr %then
  win2: extern char;
%endif
%if winchester_ctlr %then
  win: extern char;
%endif

  { The display drivers' DCTEs (map symbols of their own data segments,
    COLOR6_DCTE, COLOR4_DCTE, COLOR5_DCTE, MONO_DCTE, COLOR7_DCTE), which
    DEV_DCTES lists.  Only their addresses are used. }
%if color6_driver %then
  color6_$unit_1, color6_$unit_2, color6_$unit_3: extern char;
%endif
%if color4_driver %then
  color4_$unit_2, color4_$unit_1: extern char;
%endif
%if color5_driver %then
  color5_$dcte1, color5_$dcte2: extern char;
%endif
%if mono_driver %then
  mono_$unit_big1, mono_$unit_small1, mono_$unit_small1a,
    mono_$unit_small2: extern char;
%endif
%if color7_driver %then
  color7_$dcte: extern char;
%endif

{ The module's objects, every one a map symbol defined here (ref 7.2.1,
  Method 1, and 7.2.2, Method 2, for DEV_DCTES, declared extern in
  io/io.ins.pas), in the order of the block. }
var
%if ring_8025_driver %then
  ring_8025_dcte_1: define static_dcte_t := { +0x000 }
    [kind := 2, length := 64, ctype := io_ctype_ring_8025, cnum := 1,
     nextp := nil, csrsytr := addr(ring_8025_$init),
     name := 'itr1    ',
     reserved_1c := [chr(16#33), chr(1), chr(0), 'T', ' ', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)],
     disk_dinit := addr(ring_8025_2_io_desc),
     disk_error_que := 16#00170000];
  ring_8025_dcte_0: define static_dcte_t := { +0x040 }
    [kind := 2, length := 64, ctype := io_ctype_ring_8025, cnum := 0,
     nextp := nil, csrsytr := addr(ring_8025_$init),
     name := 'itr0    ',
     reserved_1c := [chr(16#33), chr(0), chr(0), 'T', ' ', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)],
     disk_dinit := addr(ring_8025_1_io_desc),
     disk_error_que := 16#00170000];
%endif
%if ethernet_driver %then
  eth_dcte_1: define static_dcte_t :=     { +0x080 }
    [kind := 2, length := 64, ctype := io_ctype_ethernet, cnum := 1,
     nextp := nil, csrsytr := addr(ethernet_$init),
     name := 'enet1   ',
     reserved_1c := [chr(16#33), chr(1), chr(0), 'E', ' ', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)],
     disk_dinit := addr(ethernet2_io_desc),
     disk_error_que := 16#00170000];
  eth_dcte_0: define static_dcte_t :=     { +0x0C0 }
    [kind := 2, length := 64, ctype := io_ctype_ethernet, cnum := 0,
     nextp := nil, csrsytr := addr(ethernet_$init),
     name := 'enet0   ',
     reserved_1c := [chr(16#33), chr(0), chr(0), 'E', ' ', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)],
     disk_dinit := addr(ethernet1_io_desc),
     disk_error_que := 16#00170000];
%endif
%if ring8_controller %then
  ring2_dcte: define static_dcte_t :=     { +0x100 }
    [kind := 2, length := 64, ctype := io_ctype_ring, cnum := 1,
     nextp := nil, csrsytr := addr(ring_$init),
     name := 'ring1   ',
     reserved_1c := [chr(16#33), chr(1), chr(0), 'R', ' ', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)],
     disk_dinit := addr(ring2_io_desc),
     disk_error_que := 16#00180000];
  ring1_dcte: define static_dcte_t :=     { +0x140 }
    [kind := 2, length := 64, ctype := io_ctype_ring, cnum := 0,
     nextp := nil, csrsytr := addr(ring_$init),
     name := 'ring0   ',
     reserved_1c := [chr(16#33), chr(0), chr(0), 'R', ' ', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)],
     disk_dinit := addr(ring1_io_desc),
     disk_error_que := 16#00180000];
%endif
%if floppy_disk %then
  flp_dcte: define static_dcte3_t :=      { +0x180 on the SAU8 }
    [kind := 3, length := 76, ctype := io_ctype_flp, cnum := 0,
     nextp := nil, csrsytr := addr(flp_$cinit),
     int := [id := [vector := 6], has_int := true],
     csr_va := addr(flop), csr_pa := 16#3F0, csr_pages := 1,
     has_csr := true, tag := 2, bus := io_$bus_atbus,
     disk_error_que := 16#00160000];
  pad_flp: integer32;                     { +0x1CC on the SAU8: zero,
                                            addressed by nothing; the
                                            next DCTE at a multiple of
                                            8 from the block }
%endif
%if ct_qic02 %then
  ctape_dcte: define static_dcte_t :=     { +0x1D0 on the SAU8 }
    [kind := 2, length := 64, ctype := io_ctype_ctape, cnum := 0,
     nextp := nil, csrsytr := addr(ct_$cinit),
     disk_dinit := addr(tape_io_desc), disk_error_que := 16#00010000];
%endif
%if win_mailbox_ctlr %then
  win7_dcte_1: define static_dcte3_t :=   { +0x210 on the SAU7 }
    [kind := 3, length := 76, ctype := io_ctype_win, cnum := 1,
     nextp := nil, csrsytr := addr(win7_$cinit),
     int := [id := [vector := 16#F], has_int := true],
     csr_va := addr(win2), csr_pa := 16#1A8, csr_pages := 1,
     has_csr := true, tag := 2, bus := io_$bus_atbus, attrs := [0],
     disk_error_que := 16#00170000];
  pad_win7_1: integer32;                  { +0x25C on the SAU7: as
                                            pad_flp }
  win7_dcte_0: define static_dcte3_t :=   { +0x260 on the SAU7 }
    [kind := 3, length := 76, ctype := io_ctype_win, cnum := 0,
     nextp := nil, csrsytr := addr(win7_$cinit),
     int := [id := [vector := 16#E], has_int := true],
     csr_va := addr(win), csr_pa := 16#1A0, csr_pages := 1,
     has_csr := true, tag := 2, bus := io_$bus_atbus, attrs := [0],
     disk_error_que := 16#00170000];
  pad_win7_0: integer32;                  { +0x2AC on the SAU7: as
                                            pad_flp }
%endif
%if winchester_ctlr %then
  win8_dcte: define static_dcte3_t :=     { +0x210 on the SAU8; +0x2B0
                                            on the SAU7 }
    [kind := 3, length := 76, ctype := io_ctype_win, cnum := 0,
     nextp := nil, csrsytr := addr(win_$cinit),
     int := [id := [vector := 16#E], has_int := true],
     csr_va := addr(win), csr_pa := 16#1A0, csr_pages := 1,
     has_csr := true, tag := 2, bus := io_$bus_atbus,
     disk_error_que := 16#00170000];
%endif
%if scsi_mailbox_ctlr %then
  pad_win8: integer32;                    { +0x2FC on the SAU7: as
                                            pad_flp }
  scsi7_dcte: define static_dcte_t :=     { +0x300 on the SAU7 }
    [kind := 2, length := 64, ctype := io_ctype_none, cnum := 0,
     nextp := nil, csrsytr := addr(scsi_$cinit),
     disk_dinit := addr(scsi_io_desc)];
%endif
%if ct_scsi and not scsi_mailbox_ctlr %then
  scsi_ctape_dcte_7: define static_dcte_t := { +0x180 }
    [kind := 2, length := 64, ctype := io_ctype_ctape, cnum := 7,
     nextp := nil, csrsytr := addr(ct_$cinit),
     name := 'ctape7  ',
     reserved_1c := [chr(16#21), chr(0), chr(0), 'S', 'T', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)]];
  scsi_ctape_dcte_6: define static_dcte_t := { +0x1C0 }
    [kind := 2, length := 64, ctype := io_ctype_ctape, cnum := 6,
     nextp := nil, csrsytr := addr(ct_$cinit),
     name := 'ctape6  ',
     reserved_1c := [chr(16#21), chr(0), chr(0), 'S', 'T', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)]];
  scsi_ctape_dcte_5: define static_dcte_t := { +0x200 }
    [kind := 2, length := 64, ctype := io_ctype_ctape, cnum := 5,
     nextp := nil, csrsytr := addr(ct_$cinit),
     name := 'ctape5  ',
     reserved_1c := [chr(16#21), chr(0), chr(0), 'S', 'T', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)]];
  scsi_ctape_dcte_4: define static_dcte_t := { +0x240 }
    [kind := 2, length := 64, ctype := io_ctype_ctape, cnum := 4,
     nextp := nil, csrsytr := addr(ct_$cinit),
     name := 'ctape4  ',
     reserved_1c := [chr(16#21), chr(0), chr(0), 'S', 'T', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)]];
  scsi_ctape_dcte_3: define static_dcte_t := { +0x280 }
    [kind := 2, length := 64, ctype := io_ctype_ctape, cnum := 3,
     nextp := nil, csrsytr := addr(ct_$cinit),
     name := 'ctape3  ',
     reserved_1c := [chr(16#21), chr(0), chr(0), 'S', 'T', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)]];
  scsi_ctape_dcte_2: define static_dcte_t := { +0x2C0 }
    [kind := 2, length := 64, ctype := io_ctype_ctape, cnum := 2,
     nextp := nil, csrsytr := addr(ct_$cinit),
     name := 'ctape2  ',
     reserved_1c := [chr(16#21), chr(0), chr(0), 'S', 'T', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)]];
  scsi_ctape_dcte_1: define static_dcte_t := { +0x300 }
    [kind := 2, length := 64, ctype := io_ctype_ctape, cnum := 1,
     nextp := nil, csrsytr := addr(ct_$cinit),
     name := 'ctape1  ',
     reserved_1c := [chr(16#21), chr(0), chr(0), 'S', 'T', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)]];
  scsi_ctape_dcte_0: define static_dcte_t := { +0x340 }
    [kind := 2, length := 64, ctype := io_ctype_ctape, cnum := 0,
     nextp := nil, csrsytr := addr(ct_$cinit),
     name := 'ctape0  ',
     reserved_1c := [chr(16#21), chr(0), chr(0), 'S', 'T', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)]];
%endif
%if win_scsi_disk %then
  win_scsi_dcte_0: define static_dcte_t := { +0x380 }
    [kind := 2, length := 64, ctype := io_ctype_win, cnum := 0,
     nextp := nil, csrsytr := addr(win_scsi_$cinit),
     name := 'win0    ',
     reserved_1c := [chr(16#13), chr(0), chr(0), 'S', 'D', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)],
     disk_error_que := 16#00170000];
  win_scsi_dcte_1: define static_dcte_t := { +0x3C0 }
    [kind := 2, length := 64, ctype := io_ctype_win, cnum := 1,
     nextp := nil, csrsytr := addr(win_scsi_$cinit),
     name := 'win1    ',
     reserved_1c := [chr(16#13), chr(1), chr(0), 'S', 'D', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)],
     disk_error_que := 16#00170000];
  win_scsi_dcte_2: define static_dcte_t := { +0x400 }
    [kind := 2, length := 64, ctype := io_ctype_win, cnum := 2,
     nextp := nil, csrsytr := addr(win_scsi_$cinit),
     name := 'win2    ',
     reserved_1c := [chr(16#13), chr(2), chr(0), 'S', 'D', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)],
     disk_error_que := 16#00170000];
  win_scsi_dcte_3: define static_dcte_t := { +0x440 }
    [kind := 2, length := 64, ctype := io_ctype_win, cnum := 3,
     nextp := nil, csrsytr := addr(win_scsi_$cinit),
     name := 'win3    ',
     reserved_1c := [chr(16#13), chr(3), chr(0), 'S', 'D', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)],
     disk_error_que := 16#00170000];
  win_scsi_dcte_4: define static_dcte_t := { +0x480 }
    [kind := 2, length := 64, ctype := io_ctype_win, cnum := 4,
     nextp := nil, csrsytr := addr(win_scsi_$cinit),
     name := 'win4    ',
     reserved_1c := [chr(16#13), chr(4), chr(0), 'S', 'D', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)],
     disk_error_que := 16#00170000];
  win_scsi_dcte_5: define static_dcte_t := { +0x4C0 }
    [kind := 2, length := 64, ctype := io_ctype_win, cnum := 5,
     nextp := nil, csrsytr := addr(win_scsi_$cinit),
     name := 'win5    ',
     reserved_1c := [chr(16#13), chr(5), chr(0), 'S', 'D', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)],
     disk_error_que := 16#00170000];
  win_scsi_dcte_6: define static_dcte_t := { +0x500 }
    [kind := 2, length := 64, ctype := io_ctype_win, cnum := 6,
     nextp := nil, csrsytr := addr(win_scsi_$cinit),
     name := 'win6    ',
     reserved_1c := [chr(16#13), chr(6), chr(0), 'S', 'D', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)],
     disk_error_que := 16#00170000];
  win_scsi_dcte_7: define static_dcte_t := { +0x540 }
    [kind := 2, length := 64, ctype := io_ctype_win, cnum := 7,
     nextp := nil, csrsytr := addr(win_scsi_$cinit),
     name := 'win7    ',
     reserved_1c := [chr(16#13), chr(7), chr(0), 'S', 'D', ' ',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)],
     disk_error_que := 16#00170000];
%endif
%if scsi_driver and not scsi_mailbox_ctlr %then
  scsi9_dcte: define static_dcte_t :=     { +0x580 }
    [kind := 2, length := 64, ctype := io_ctype_none, cnum := 0,
     nextp := nil, csrsytr := addr(scsi_$init),
     name := 'scsi    ',
     disk_dinit := addr(scsi9_io_desc)];
%endif
%if timer_dcte %then
  timer_dcte: define static_dcte_t :=     { +0x5C0 }
    [kind := 2, length := 64, ctype := io_ctype_none, cnum := 0,
     nextp := nil, csrsytr := addr(timer_$init),
     name := 'timer   '];
%endif
%if sio16550_lines %then
  sio3_dcte: define static_dcte_t :=      { +0x600 }
    [kind := 2, length := 64, ctype := io_ctype_none, cnum := 3,
     nextp := nil, csrsytr := addr(sio16550_$init),
     name := 'sio3    ',
     reserved_1c := [chr(16#53), chr(3), chr(0), 'S', 'I', 'O',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)],
     disk_dinit := addr(sio3_io_desc)];
  sio2_dcte: define static_dcte_t :=      { +0x640 }
    [kind := 2, length := 64, ctype := io_ctype_none, cnum := 2,
     nextp := nil, csrsytr := addr(sio16550_$init),
     name := 'sio2    ',
     reserved_1c := [chr(16#53), chr(2), chr(0), 'S', 'I', 'O',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)],
     disk_dinit := addr(sio2_io_desc)];
  sio1_dcte: define static_dcte_t :=      { +0x680 }
    [kind := 2, length := 64, ctype := io_ctype_none, cnum := 1,
     nextp := nil, csrsytr := addr(sio16550_$init),
     name := 'sio1    ',
     reserved_1c := [chr(16#53), chr(1), chr(0), 'S', 'I', 'O',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)],
     disk_dinit := addr(sio1_io_desc)];
  sio0_dcte: define static_dcte_t :=      { +0x6C0 }
    [kind := 2, length := 64, ctype := io_ctype_none, cnum := 0,
     nextp := nil, csrsytr := addr(sio16550_$init),
     name := 'sio0    ',
     reserved_1c := [chr(16#53), chr(0), chr(0), 'K', 'B', 'D',
                     ' ', chr(0), chr(0), chr(0), chr(0), chr(0)],
     disk_dinit := addr(sio0_io_desc)];
%endif

{ The list, the block's DCTEs from the last to the first. }
define
  dev_dctes := [
%if sio16550_lines %then
                addr(sio0_dcte),
                addr(sio1_dcte),
                addr(sio2_dcte),
                addr(sio3_dcte),
%endif
%if timer_dcte %then
                addr(timer_dcte),
%endif
%if scsi_driver and not scsi_mailbox_ctlr %then
                addr(scsi9_dcte),
%endif
%if win_scsi_disk %then
                addr(win_scsi_dcte_7),
                addr(win_scsi_dcte_6),
                addr(win_scsi_dcte_5),
                addr(win_scsi_dcte_4),
                addr(win_scsi_dcte_3),
                addr(win_scsi_dcte_2),
                addr(win_scsi_dcte_1),
                addr(win_scsi_dcte_0),
%endif
%if ct_scsi and not scsi_mailbox_ctlr %then
                addr(scsi_ctape_dcte_0),
                addr(scsi_ctape_dcte_1),
                addr(scsi_ctape_dcte_2),
                addr(scsi_ctape_dcte_3),
                addr(scsi_ctape_dcte_4),
                addr(scsi_ctape_dcte_5),
                addr(scsi_ctape_dcte_6),
                addr(scsi_ctape_dcte_7),
%endif
%if scsi_mailbox_ctlr %then
                addr(scsi7_dcte),
%endif
%if winchester_ctlr %then
                addr(win8_dcte),
%endif
%if win_mailbox_ctlr %then
                addr(win7_dcte_0),
                addr(win7_dcte_1),
%endif
%if floppy_disk %then
                addr(flp_dcte),
%endif
%if ct_qic02 %then
                addr(ctape_dcte),
%endif
%if ring8_controller %then
                addr(ring1_dcte),
                addr(ring2_dcte),
%endif
%if ethernet_driver %then
                addr(eth_dcte_0),
                addr(eth_dcte_1),
%endif
%if ring_8025_driver %then
                addr(ring_8025_dcte_0),
                addr(ring_8025_dcte_1),
%endif
%if color6_driver %then
                addr(color6_$unit_1),
                addr(color6_$unit_2),
                addr(color6_$unit_3),
%endif
%if color4_driver %then
                addr(color4_$unit_1),
                addr(color4_$unit_2),
%endif
%if color5_driver %then
                addr(color5_$dcte1),
                addr(color5_$dcte2),
%endif
%if mono_driver %then
                addr(mono_$unit_small1),
                addr(mono_$unit_big1),
                addr(mono_$unit_small1a),
                addr(mono_$unit_small2),
%endif
%if color7_driver %then
                addr(color7_$dcte),
%endif
                nil];
                                          { +0x700; +0x25C on the SAU8;
                                            +0x340 on the SAU7 }
%else
var
  { The I/O pages the DCTEs name (map symbols of IODEFS,
    arch/m68k/sau2/iodefs.s on the SAU2): RING2, the ring's; DISK, the
    floppy's, and WIN, the Winchester's (one page, 0xFFA800, with
    CALENDAR); TAPE, the cartridge tape's (the same page on the SAU5).
    Only their addresses are used. }
  ring2: extern char;
%if floppy_dcte_request %then
  flop: extern char;
%elseif floppy_disk %then
  disk: extern char;
%endif
%if winchester_config %then
  win: extern char;
%endif
%if ct_qic02 %then
  tape: extern char;
%endif
%if ethernet_driver %then
  ethernet2, ethernet1: extern char;
%endif
%if win6_ct6_board %then
  tape6: extern char;
  win6: extern char;
%endif

{ The module's objects, every one a map symbol defined here (ref 7.2.1,
  Method 1, and 7.2.2, Method 2, for DEV_DCTES, declared extern in
  io/io.ins.pas), in the order of the block. }
var
%if ethernet_driver %then
  eth_dcte_1: define static_dcte_t :=     { +0x00 on the SAU6 }
    [kind := 1, length := 64, ctype := io_ctype_ethernet, cnum := 0,
     nextp := nil, csrsytr := addr(ethernet_$init),
     disk_dinit := addr(ethernet2), disk_error_que := 16#001700F6];
  eth_dcte_0: define static_dcte_t :=     { +0x40 on the SAU6 }
    [kind := 1, length := 64, ctype := io_ctype_ethernet, cnum := 0,
     nextp := nil, csrsytr := addr(ethernet_$init),
     disk_dinit := addr(ethernet1), disk_error_que := 16#001700F5];
%endif
%if win6_ct6_board %then
  ctape6_dcte: define static_dcte_t :=    { +0x80 on the SAU6 }
    [kind := 1, length := 64, ctype := io_ctype_ctape, cnum := 0,
     nextp := nil, csrsytr := addr(ct6_$cinit),
     disk_dinit := addr(tape6), disk_error_que := 16#00170090];
%endif
%if ct_qic02 %then
  ctape_dcte: define static_dcte_t :=     { +0x00 on the SAU5; +0xC0 on
                                            the SAU6 }
    [kind := 1, length := 64, ctype := io_ctype_ctape, cnum := 0,
     nextp := nil, csrsytr := addr(ct_$cinit),
     disk_dinit := addr(tape), disk_do_io := addr(ct_$int),
%if sysbus_vectors_88 %then
     disk_error_que := 16#0017008C];
%else
     disk_error_que := 16#00170000];
%endif
%endif
%if smd_disk %then
  smd_dcte_1: define static_dcte_t :=     { +0x40 on the SAU5; +0x00 on
                                            the SAU3 }
    [kind := 1, length := 64, ctype := io_ctype_smd, cnum := 0,
     nextp := nil, csrsytr := addr(sm_c_$cinit),
     io_va := addr(sm_blk_hdr), disk_error_que := 16#00150000];
  smd_dcte_0: define static_dcte_t :=     { +0x80 on the SAU5; +0x40 on
                                            the SAU3 }
    [kind := 1, length := 64, ctype := io_ctype_smd, cnum := 0,
     nextp := nil, csrsytr := addr(sm_$cinit),
     io_va := addr(sm_blk_hdr), disk_error_que := 16#00150000];
%endif
  ring_dcte: define static_dcte_t :=      { +0x00; +0xC0 on the SAU5;
                                            +0x80 on the SAU3 }
    [kind := 1, length := 64, ctype := io_ctype_ring, cnum := 0,
     nextp := nil, csrsytr := addr(ring_$init),
%if ring8_controller %then
     disk_dinit := addr(ring2), disk_do_io := nil,
%elseif ring_board_dma %then
     disk_dinit := addr(ring2), disk_do_io := addr(ring_$xmit_int),
%else
     disk_dinit := addr(ring2), disk_do_io := addr(ring_$int),
%endif
%if sysbus_vectors_90 %then
     disk_error_que := 16#00180090];
%elseif sysbus_vectors_88 %then
     disk_error_que := 16#00180088];
%elseif sysbus_routines %then
     disk_error_que := 16#0018001B];
%else
     disk_error_que := 16#00180000];
%endif
%if floppy_dcte_request %then
  flp_dcte: define static_dcte3_t :=      { +0xC0 on the SAU4 }
    [kind := 3, length := 76, ctype := io_ctype_flp, cnum := 0,
     nextp := nil, csrsytr := addr(flp_$cinit),
     int := [id := [vector := 16#F3], has_int := true],
     csr_va := addr(flop), csr_pa := 0, csr_pages := 1,
     has_csr := true, tag := 2, bus := io_$bus_sysbus,
     disk_error_que := 16#00160000];
  pad_flp: integer32;                     { +0x10C on the SAU4: zero,
                                            addressed by nothing; the
                                            next DCTE at a multiple of
                                            8 from the block }
%elseif floppy_disk %then
  flp_dcte: define static_dcte_t :=       { +0x40 }
    [kind := 1, length := 64, ctype := io_ctype_flp, cnum := 0,
     nextp := nil, csrsytr := addr(flp_$cinit),
     disk_dinit := addr(disk), disk_do_io := addr(flp_$int),
     disk_error_que := 16#00170000];
%endif
%if win6_ct6_board %then
  win6_dcte: define static_dcte_t :=      { +0x1C0 on the SAU6 }
    [kind := 1, length := 64, ctype := io_ctype_win, cnum := 0,
     nextp := nil, csrsytr := addr(win6_$cinit),
     disk_dinit := addr(win6), disk_error_que := 16#00170090];
%endif
%if winchester_config %then
  win_dcte: define static_dcte_t :=       { +0x80; +0x100 on the SAU5;
                                            +0x200 on the SAU6 }
    [kind := 1, length := 64, ctype := io_ctype_win, cnum := 0,
     nextp := nil, csrsytr := addr(win_$cinit),
     disk_dinit := addr(win), disk_do_io := addr(win_$int),
%if sysbus_vectors_90 %then
     disk_error_que := 16#00170090];
%elseif sysbus_vectors_88 %then
     disk_error_que := 16#0017008C];
%else
     disk_error_que := 16#00170000];
%endif
%endif

{ The list, the block's DCTEs from the last to the first. }
define
  dev_dctes := [
%if winchester_config %then
                addr(win_dcte),
%endif
%if win6_ct6_board %then
                addr(win6_dcte),
%endif
%if floppy_disk %then
                addr(flp_dcte),
%endif
                addr(ring_dcte),
%if smd_disk %then
                addr(smd_dcte_0), addr(smd_dcte_1),
%endif
%if ct_qic02 %then
                addr(ctape_dcte),
%endif
%if win6_ct6_board %then
                addr(ctape6_dcte),
%endif
%if ethernet_driver %then
                addr(eth_dcte_0), addr(eth_dcte_1),
%endif
                nil];
                                          { +0xC0; +0x140 on the SAU5;
                                            +0xC0 on the SAU3 }
%endif
