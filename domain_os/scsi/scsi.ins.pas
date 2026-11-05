{ scsi/scsi.ins.pas - SCSI_ routine headings, constants, types and
  variables, for the Domain Pascal tree.

  The SCSI_ module (scsi/scsi.pas).  Without the driver (the SAU2) two
  stubs and one variable; with `scsi_driver' (base/config.ins.pas) the
  driver of the NCR 53C90 SCSI controller, as the SAU9 (DN2500) has it.
  Apollo's customer insert files of SR10.2 declare nothing of SCSI: the
  names below are the map's, the 53C90's and the SCSI standard's, or
  descriptive.  The driver's own declarations are scsi/scsi_c90.ins.pas.
  Include base/base.ins.pas and, for the driver's headings,
  ec/ec.ins.pas before it. }

var
  { SCSI_$PRESENT (map symbol, in SCSI_WIRED_DATA): set once SCSI_$INIT
    has set up a bus.  The SAU2's 4-byte SCSI_ data segment holds only
    it, zero, and nothing addresses it; the SAU9's code sets it with
    `st' and tests its byte: a boolean, followed by the segment's
    rounding. }
  scsi_$present: extern boolean;

{ SCSI_$CINIT - initialize the SCSI controller.  With the mailbox
  host adapter (`scsi_mailbox_ctlr') it is the controller's DCTE's
  init routine, its heading scsi/scsi_mbox.ins.pas's (it takes
  io/io.ins.pas's dcte_t). }
%if not scsi_mailbox_ctlr %then
function scsi_$cinit: integer32; extern;
%endif

{ SCSI_$FREE_ASID - free a process's SCSI resources. }
procedure scsi_$free_asid(in asid: integer); extern;

%if scsi_driver %then
{ ---- The NCR 53C90 driver (`scsi_driver', base/config.ins.pas). ---- }

const
  { The SCSI manager's statuses (subsystem 16#38, stcode.db.10.2's "OS /
    SCSI manager"; its texts in the comments).  The names follow the
    texts. }
  status_$scsi_bus_not_present = 16#00380001;     { SCSI bus not present }
  status_$scsi_bad_handle = 16#00380002;          { bad handle passed in call }
  status_$scsi_device_in_use = 16#00380003;       { device in use }
  status_$scsi_device_not_acquired = 16#00380004; { device not acquired }
  status_$scsi_device_already_acquired = 16#00380005;
                                        { device already acquired }
  status_$scsi_bad_parameter = 16#00380006;       { bad parameter }
  status_$scsi_buffer_too_large = 16#00380007;    { buffer too large }
  status_$scsi_page_not_wired = 16#00380008;      { page not wired }
  status_$scsi_page_already_wired = 16#00380009;  { page already wired }
  status_$scsi_too_many_wired_pages = 16#0038000A; { too many wired pages }
  status_$scsi_bad_length = 16#0038000B;          { bad length }
  status_$scsi_unsupported_function = 16#0038000D; { unsupported function }
  status_$scsi_device_already_allocated = 16#0038000F;
                                        { device already allocated }
  status_$scsi_operation_timeout = 16#00380010;   { operation timeout }
  status_$scsi_hardware_timeout = 16#00380011;    { hardware timeout }
  status_$scsi_hardware_failure = 16#00380012;    { hardware failure }
  status_$scsi_internal_error = 16#00380013;      { internal manager error }
  status_$scsi_quit_fault = 16#00380014;          { quit fault received
                                                    during wait }
  status_$scsi_all_devices_in_use = 16#00380015;  { all devices in use }
  status_$scsi_illegal_bus_revision = 16#00380016; { illegal bus revision }
  status_$scsi_protection_violation = 16#00380017; { protection violation }
  status_$scsi_no_resources = 16#00380018;        { no resources available }
  status_$scsi_command_in_progress = 16#00380019; { command in progress }
  status_$scsi_dma_overrun = 16#0038001A;         { DMA overrun }
  status_$scsi_dma_underrun = 16#0038001B;        { DMA underrun }
  status_$scsi_parity_error = 16#0038001C;        { parity error }
  status_$scsi_illegal_data_direction = 16#0038001E;
                                        { illegal data direction }
  status_$scsi_target_disconnected = 16#0038001F; { scsi target disconnected }
  status_$scsi_target_not_available = 16#00380020;
                                        { scsi target not available }
  status_$scsi_no_such_operation = 16#00380021;   { no such operation }
  status_$scsi_selected_by_initiator = 16#00380022;
                                        { host selected by another
                                          initiator }
  status_$scsi_bus_reset_detected = 16#00380023;  { scsi bus reset detected }
  status_$scsi_illegal_reselection = 16#00380024; { host illegally reselected }
  status_$scsi_unknown_message = 16#00380025;     { unknown message sent to
                                                    host }
  status_$scsi_illegal_bus_phase = 16#00380026;   { illegal scsi bus phase }
  status_$scsi_not_system_device = 16#00380027;   { target is not a system
                                                    device }
  status_$scsi_illegal_sys_device_cmd = 16#00380028;
                                        { illegal system device command }

  { The bus and target numbers.  One bus (SCSI_$INIT sets the count to
    1); SCSI_$SETUP takes buses 0..3 and targets 0..7, the controller
    itself being target 7, and the handle checks take targets 0..6. }
  scsi_max_bus = 3;
  scsi_host_id = 7;
  scsi_max_target = 6;

  { A transfer's direction (the request's `dir'). }
  scsi_$dir_in = 0;                       { from the device }
  scsi_$dir_out = 1;                      { to the device }

  { The largest transfer, in bytes (SCSI_$GET_INFO's answer, the length
    checks), and the request's page lists: 33 pages cover 32768 bytes
    at any alignment. }
  scsi_$max_transfer = 32768;
  scsi_max_pages = 33;

  { The SCSI status byte's code (bits 4..1), as the request's
    scsi_status keeps it: the code halved; 16, any other code, is also
    the value of a request no status phase answered. }
  scsi_$st_good = 0;
  scsi_$st_check_condition = 1;
  scsi_$st_condition_met = 2;
  scsi_$st_busy = 4;
  scsi_$st_intermediate = 8;
  scsi_$st_reservation_conflict = 12;
  scsi_$st_other = 16;

type
  { A device's handle, 4 bytes: the target's generation (SCSI_$SETUP's
    clock word), the bus and the target.  The routines build it in a
    cleared longword. }
  scsi_$handle_t = record
    case integer of
      1: (gen: integer;                   { 0x00 }
          bus: [byte] 0..255;             { 0x02 }
          target: [byte] 0..255);         { 0x03 }
      2: (all: integer32);                { 0x00 }
      3: (unused_gen: integer;            { 0x00 }
          dev: pinteger);                 { 0x02: bus * 256 + target }
  end;

  { A command descriptor block, 12 bytes: its bytes, and byte 1's
    logical unit number (bits 7..5); the fields of a 6-byte command
    that the Winchester driver sets (win_scsi/: MODE SENSE's page
    control and page code, MODE SELECT's PF and SP bits, the start or
    prevent bit), of a 10-byte one (READ's and WRITE's block address
    and transfer length), and of the cartridge tape's 6-byte commands
    (ct/: the transfer length or count in bytes 2..4). }
  scsi_$cdb_t = record
    case integer of
      1: (b: array[0..11] of char);       { 0x00 }
      2: (f: packed record
            op: 0..255;                   { 0x00 }
            lun: 0..7;                    { 0x01, bits 7..5 }
            rest: 0..31;                  { 0x01, bits 4..0 }
          end);
      3: (g0: packed record
            op: 0..255;                   { 0x00 }
            lun: 0..7;                    { 0x01, bits 7..5 }
            pf: boolean;                  { 0x01, bit 4 }
            unused_1_3: 0..7;             { 0x01, bits 3..1 }
            sp: boolean;                  { 0x01, bit 0 }
            pc: 0..3;                     { 0x02, bits 7..6 }
            page: 0..63;                  { 0x02, bits 5..0 }
            unused_3: 0..255;             { 0x03 }
            unused_4_7: 0..127;           { 0x04, bits 7..1 }
            start: boolean;               { 0x04, bit 0 }
          end);
      4: (g1: packed record
            op: 0..255;                   { 0x00 }
            lun: 0..7;                    { 0x01, bits 7..5 }
            rest: 0..31;                  { 0x01, bits 4..0 }
            lba: integer32;               { 0x02 }
            unused_6: 0..255;             { 0x06 }
            len: 0..65535;                { 0x07 }
          end);
      5: (t: packed record
            op: 0..255;                   { 0x00 }
            lun: 0..7;                    { 0x01, bits 7..5 }
            rest: 0..31;                  { 0x01, bits 4..0 }
            len: 0..16#FFFFFF;            { 0x02 }
            control: 0..255;              { 0x05 }
          end);
  end;

  { The physical pages of a transfer (SCSI_$DO_COMMAND_PHYS's list:
    physical addresses). }
  scsi_$phys_list_t = array[1..32] of integer32;

  { What SCSI_$WAIT returns of a request, 12 bytes: its id, its status,
    its SCSI status code (scsi_$st_...). }
  scsi_$result_t = record
    id: integer32;                        { 0x00 }
    status: status_$t;                    { 0x04 }
    scsi_status: integer32;               { 0x08 }
  end;

  { SCSI_$GET_INFO's answer: the version (1) and the largest transfer
    (linteger: WIN_SCSI_$DINIT divides it unsigned). }
  scsi_$info_t = record
    version: integer32;                   { 0x00 }
    max_transfer: linteger;               { 0x04 }
  end;

  { A system device's command routine (SCSI_$SET_SYS_DEVICE):
    SCSI_$DO_SYS_DEVICE_CMD passes it its own twelve arguments, all by
    address, the bus and target first and the status last. }
  scsi_$sys_cmd_proc_t = ^procedure(in bus: integer; in target: integer;
                                     var arg3: univ_ptr; var arg4: univ_ptr;
                                     var arg5: univ_ptr; var arg6: univ_ptr;
                                     var arg7: univ_ptr; var arg8: univ_ptr;
                                     var arg9: univ_ptr; var arg10: univ_ptr;
                                     var arg11: univ_ptr;
                                     out status: status_$t);

{ ---- The globals' headings, in map order, but for SCSI_$INIT
  (io/io.ins.pas: IO_'s DCTE names it) and the two interrupt routines
  (scsi/scsi_c90.ins.pas).  The default convention (every argument by
  address). ---- }

{ SCSI_$HP_WRITE and SCSI_$HP_READ (SCSI_ASM, hand assembly,
  scsi/sau9/scsi_asm.s): move bytes between memory and the DMA port at
  most a FIFO's worth (write) or while the port has data (read); the
  four arguments by address, the result in D0 the bytes moved. }
function scsi_$hp_write(in fifo_flags: univ_ptr; in port: univ_ptr;
                        in buf: univ_ptr; in count: integer32): integer;
  extern;
function scsi_$hp_read(in fifo_flags: univ_ptr; in port: univ_ptr;
                       in buf: univ_ptr; in count: integer32): integer;
  extern;

{ SCSI_$ABORT_OPERATION - abort a device's command in progress. }
procedure scsi_$abort_operation(in handle: scsi_$handle_t;
                                out status: status_$t);
  extern;

{ SCSI_$DO_COMMAND_PHYS - start a command on physical pages. }
procedure scsi_$do_command_phys(in handle: scsi_$handle_t;
                                in cdb: scsi_$cdb_t;
                                in pages: scsi_$phys_list_t;
                                in npages: pinteger;
                                in len: linteger;
                                in dir: integer;
                                out id: integer32;
                                out status: status_$t);
  extern;

{ SCSI_$DO_COMMAND - start a command on a buffer. }
procedure scsi_$do_command(in handle: scsi_$handle_t; in cdb: scsi_$cdb_t;
                           in buf: univ char; in len: integer32;
                           in dir: integer; out id: integer32;
                           out status: status_$t);
  extern;

{ SCSI_$SET_SYS_DEVICE - make a device a system device. }
procedure scsi_$set_sys_device(in handle: scsi_$handle_t;
                               in cmd_proc: scsi_$sys_cmd_proc_t;
                               out status: status_$t);
  extern;

{ SCSI_$GET_EC - return a device's eventcount. }
procedure scsi_$get_ec(in handle: scsi_$handle_t; in which: integer;
                       out ec: ec2_$ptr_t; out status: status_$t);
  extern;

{ SCSI_$GET_INFO - return the driver's limits. }
procedure scsi_$get_info(in handle: scsi_$handle_t; in size: pinteger;
                         out info: scsi_$info_t; out status: status_$t);
  extern;

{ SCSI_$RELEASE - release a device. }
procedure scsi_$release(in handle: scsi_$handle_t; out status: status_$t);
  extern;

{ SCSI_$RESET_DEVICE - reset a device. }
procedure scsi_$reset_device(in handle: scsi_$handle_t;
                             out status: status_$t);
  extern;

{ SCSI_$SETUP - acquire a device. }
procedure scsi_$setup(in bus: integer; in target: integer;
                      out handle: scsi_$handle_t; out status: status_$t);
  extern;

{ SCSI_$UNWIRE - unwire a device's buffer. }
procedure scsi_$unwire(in handle: scsi_$handle_t; in buf: univ char;
                       in len: integer32; in touch: boolean;
                       out status: status_$t);
  extern;

{ SCSI_$WAIT - wait for a device's command to end. }
function scsi_$wait(in handle: scsi_$handle_t; in timeout: integer32;
                    in allow_quit: boolean; in id: integer32;
                    in max_results: integer; out result: scsi_$result_t;
                    out count: integer; out status: status_$t): integer;
  extern;

{ SCSI_$WIRE - wire a device's buffer. }
procedure scsi_$wire(in handle: scsi_$handle_t; in buf: univ char;
                     in len: integer32; out status: status_$t);
  extern;

{ SCSI_$DO_SYS_DEVICE_CMD - pass a command to a system device's
  routine. }
procedure scsi_$do_sys_device_cmd(in bus: integer; in target: integer;
                                  var arg3: univ_ptr; var arg4: univ_ptr;
                                  var arg5: univ_ptr; var arg6: univ_ptr;
                                  var arg7: univ_ptr; var arg8: univ_ptr;
                                  var arg9: univ_ptr; var arg10: univ_ptr;
                                  var arg11: univ_ptr;
                                  out status: status_$t);
  extern;
%endif
