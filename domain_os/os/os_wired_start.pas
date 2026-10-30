{ os/os_wired_start.pas - the OS_WIRED_START module, the shutdown
  eventcount.

  Image addresses:
    sau2  0x00E1DC00  OS_WIRED_START data (WIRED_DATA, 0xC bytes)

  A unit with data only: the map's OS_WIRED_START data segment in
  WIRED_DATA (0xC bytes, the map symbols OS_$SHUTDOWN_EC and
  OS_DATA_WIRED at its start).  The block is the first of WIRED_DATA:
  OS_DATA_WIRED, the map's label of the wired data's start, is its
  address.

  It holds one object, OS_$SHUTDOWN_EC, a level-1 eventcount of value 0
  whose waiter list is linked to itself (os/os.ins.pas
  os_$shutdown_ec_t).  No code of a unit of its own reaches it, so the
  unit has no code section: `module os_wired_start, , wired_data;'
  (AUDIT_WIRED's and HINT_WIRED's form).

  The name is the map's segment name; the object's is the map's symbol.

  Check: tools/pascal_check.sh (found by its module heading).
}
module os_wired_start, , wired_data;

%include 'base/base.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'os/os.ins.pas';

define
  os_$shutdown_ec := [value := 0,
                      waiter_list_head := addr(os_$shutdown_ec),
                      waiter_list_tail := addr(os_$shutdown_ec)];
                                                   { +0x00 }
