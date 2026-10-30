{ rem_name/rem_name.pas - the REM_NAME module, the remote naming
  service's client.

  Image addresses:
    sau2  0x00E7DBB8  REM_NAME data (.DATA, 0x40 bytes)

  One compilation unit, in one code section and one data section: the
  map's REM_NAME code segment in .TEXT (0xB20 bytes: REM_NAME_SERVER_LOCAL,
  LOCATE_SERVER, REM_NAME_$REGISTER_SERVER .. REM_NAME_$FIND_UID) and its
  REM_NAME data segment in .DATA (0x40 bytes).  Every map symbol is a
  global, REM_NAME_SERVER_LOCAL and LOCATE_SERVER too; the one routine
  without a map symbol is rem_name_$send_request, module-local.

  The block's objects are module variables, the code is .TEXT's and the
  block .DATA's, the defaults (ref 7.1.1), so `module rem_name;'
  (hint/hint.pas's and netlog/netlog.pas's shape).

  The data, 0x40 bytes:

    +0x00  rem_name_$config       30  the request template
    +0x1E  (2 bytes: the next object's alignment, zero)
    +0x20  rem_name_$server_timeout  4  2400
    +0x24  rem_name_$reserved2     4  16#4B0; no routine addresses it

    +0x28  REM_NAME_$TIME_HEARD_FROM_SERVER  defined
    +0x2C  REM_NAME_$LAST_STATUS   defined, the fail bit set
    +0x30  REM_NAME_$CURR_NODE     defined
    +0x34  REM_NAME_$CURR_NET      defined

    +0x38  REM_NAME_$SERVICE_DELAY defined, 16
    +0x3A  rem_name_$retry_count   2  LOCATE_SERVER's attempts
    +0x3C  REM_NAME_$HEARD_FROM_SERVER  defined
    +0x3D  (3 bytes: the block's rounding to 4)

  As in netbuf/netbuf.pas, the var parts and the define part are in the
  block's order.

  The routines live in one fragment file each (rem_name/<name>.pas),
  included below in image order.  The calls go backward but
  LOCATE_SERVER's to REM_NAME_$LOCATE_SERVER, whose extern heading in
  rem_name/rem_name.ins.pas comes first.

  Build: dpc -I domain_os domain_os/rem_name/rem_name.pas.  Check:
  tools/pascal_check.sh.
}
module rem_name;

%include 'base/base.ins.pas';
%include 'ec/ec.ins.pas';
%include 'time/time.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'os/os.ins.pas';
%include 'node/node.ins.pas';
%include 'pkt/pkt.ins.pas';
%include 'netbuf/netbuf.ins.pas';
%include 'sock/sock.ins.pas';
%include 'name/name.ins.pas';
%include 'rem_name/rem_name.ins.pas';

{ The module's own variables and the globals it defines (ref 7.2.2 and
  7.3.4, Method 2), in the order of the block (above), the routines in
  map order. }
var
  rem_name_$config: rem_name_$config_t :=
    [16#10, 2, 2, 16#8031, 16#FFFF, 0, 16#FFFF, 0, 0, 0, 0, 0, 0, 0, 0];
                                                   { +0x00 }
  rem_name_$server_timeout: linteger := 2400;      { +0x20 }
  rem_name_$reserved2: integer32 := 16#4B0;        { +0x24 }

define
  rem_name_$time_heard_from_server;               { +0x28, zero }
  rem_name_$last_status := [fail := true, subsys := 0, modc := 0,
                            code := 0];            { +0x2C }
  rem_name_$curr_node;                             { +0x30, zero }
  rem_name_$curr_net;                              { +0x34, zero }
  rem_name_$service_delay := 16;                   { +0x38 }

var
  rem_name_$retry_count: integer;                  { +0x3A, zero }

define
  rem_name_$heard_from_server;                     { +0x3C, zero: false }

define
  rem_name_server_local;
  locate_server;
  rem_name_$register_server;
  rem_name_$get_entry_by_name;
  rem_name_$get_info;
  rem_name_$locate_server;
  rem_name_$get_entry_by_node_id;
  rem_name_$get_entry_by_uid;
  rem_name_$read_dir;
  rem_name_$read_rep;
  rem_name_$dir_readu;
  rem_name_$get_entry;
  rem_name_$find_network;
  rem_name_$find_uid;

{ ---- .TEXT ---- }
%include 'rem_name/server_local.pas';        { REM_NAME_SERVER_LOCAL }
%include 'rem_name/locate_server_internal.pas';  { LOCATE_SERVER }
%include 'rem_name/register_server.pas';     { REM_NAME_$REGISTER_SERVER }
%include 'rem_name/send_request.pas';        { rem_name_$send_request }
%include 'rem_name/get_entry_by_name.pas';   { REM_NAME_$GET_ENTRY_BY_NAME }
%include 'rem_name/get_info.pas';            { REM_NAME_$GET_INFO }
%include 'rem_name/locate_server.pas';       { REM_NAME_$LOCATE_SERVER }
%include 'rem_name/get_entry_by_node_id.pas';  { REM_NAME_$GET_ENTRY_BY_NODE_ID }
%include 'rem_name/get_entry_by_uid.pas';    { REM_NAME_$GET_ENTRY_BY_UID }
%include 'rem_name/read_dir.pas';            { REM_NAME_$READ_DIR }
%include 'rem_name/read_rep.pas';            { REM_NAME_$READ_REP }
%include 'rem_name/dir_readu.pas';           { REM_NAME_$DIR_READU }
%include 'rem_name/get_entry.pas';           { REM_NAME_$GET_ENTRY }
%include 'rem_name/find_network.pas';        { REM_NAME_$FIND_NETWORK }
%include 'rem_name/find_uid.pas';            { REM_NAME_$FIND_UID }
