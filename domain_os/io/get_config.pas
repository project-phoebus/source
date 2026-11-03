{ IO_$GET_CONFIG - report which optional controllers are configured.

  Image addresses:
    sau2  0x00E72334  IO_$GET_CONFIG
    sau3  0x00E73A08  IO_$GET_CONFIG
    sau4  0x0F87F8E8  IO_$GET_CONFIG
    sau5  0x00E794A8  IO_$GET_CONFIG
    sau8  0x03C7CBDC  IO_$GET_CONFIG
    sau9  0x3C479D0C  IO_$GET_CONFIG

  - By CHK: config1's members 0 (Winchester, `winchester_config'), 2
    (storage module disk, `smd_disk') and 1 (floppy, `floppy_disk');
    config2's 0 (ring) and 1 (Ethernet, `ethernet_driver').
  - config2's 2 when a routing port of the internet interface
    controller is active (`iic_port_config').
  - config3's 1 when PBU_$MCB's first flag is set (`pbu_mcb_config';
    its 0 with `mcb_config_member_0'), or always (`pbu_config_always');
    config3 is [3] with the AT bus (`atbus_routines');
    config4's 0 for MT_$PRESENT's answer and 1 for the cartridge tape
    (`ct_driver').

  Status stored: none.
}

[section(procedure$, data$)]
procedure io_$get_config(out config1: io_$config_t; out config2: io_$config_t;
                         out config3: io_$config_t; out config4: io_$config_t);
var
  i: integer;                             { the ports' index; declared on
                                            every SAU, as the SAU2 image's
                                            frame shows }
begin
  config1 := [];
%if winchester_config %then
  if chk(0) then
    config1 := config1 + [0];
%endif
%if smd_disk %then
  if chk(4) then
    config1 := config1 + [2];
%endif
%if floppy_disk %then
  if chk(1) then
    config1 := config1 + [1];
%endif

  config2 := [];
  if chk(2) then
    config2 := config2 + [0];
%if ethernet_driver %then
  if chk(6) then
    config2 := config2 + [1];
%endif
%if iic_port_config %then
  for i := 0 to 7 do
    with route_$port[i] do
      if (active <> 0) and then (port_type = route_$port_type_iic) then
        config2 := config2 + [2];
%endif

%if atbus_routines %then
  config3 := [3];
%elseif pbu_config_always %then
  config3 := [1];
%else
  config3 := [];
%endif
%if pbu_mcb_config %then
  if pbu_$mcb.present then
%if mcb_config_member_0 %then
    config3 := config3 + [0];
%else
    config3 := config3 + [1];
%endif
%endif
  config4 := [];
  if io_$config_flag then
    config4 := config4 + [0];
%if ct_driver %then
  if chk(5) then
    config4 := config4 + [1];
%endif
end;
