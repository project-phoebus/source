{ IO_$GET_CONFIG - report which optional controllers are configured.

  Image addresses:
    sau2  0x00E72334  IO_$GET_CONFIG
    sau5  0x00E794A8  IO_$GET_CONFIG
    sau9  0x3C479D0C  IO_$GET_CONFIG

  - By CHK: config1's members 0 (Winchester), 2 (storage module disk,
    `smd_disk') and 1 (floppy, `floppy_disk'); config2's 0 (ring) and 1
    (Ethernet, `ethernet_driver').
  - config3's 1 when PBU_$MCB's first flag is set (`pbu_mcb_config');
    config3 is [3] with the AT bus (`atbus_routines');
    config4's 0 for MT_$PRESENT's answer and 1 for the cartridge tape
    (`ct_driver').

  Status stored: none.
}

{ TODO(sau) IO_$GET_CONFIG's forms on the SAUs not translated

  The SAU2, SAU5 and SAU9 forms are written (the SAU6's, SAU7's and
  SAU8's are the same parts').  The others differ: the SAU3 has no
  Winchester test, a loop over eight table entries for config2's member
  2 and config3 := [1]; the SAU4 assigns config3 := [0] for PBU_$MCB.
  Each needs its part when that SAU is translated. }

{ TODO(pascal) 4 frame bytes unexplained (stand-in unused_4)

  The SAU2 frame is 4 bytes, with no local: a global procedure reserves
  no slot, so the 4 bytes are the stand-in unused_4. }

[section(procedure$, data$)]
procedure io_$get_config(out config1: io_$config_t; out config2: io_$config_t;
                         out config3: io_$config_t; out config4: io_$config_t);
var
  unused_4: integer32;                    { the stand-in (TODO) }
begin
  config1 := [];
  if chk(0) then
    config1 := config1 + [0];
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

%if atbus_routines %then
  config3 := [3];
%else
  config3 := [];
%endif
%if pbu_mcb_config %then
  if pbu_$mcb.present then
    config3 := config3 + [1];
%endif
  config4 := [];
  if io_$config_flag then
    config4 := config4 + [0];
%if ct_driver %then
  if chk(5) then
    config4 := config4 + [1];
%endif
end;
