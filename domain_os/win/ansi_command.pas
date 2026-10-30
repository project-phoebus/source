{ win_$ansi_command - issue one ANSI command to the drive and wait for it.

  Image addresses:
    sau2  0x00E19128  win_$ansi_command (module-local)

  - The command byte goes to the drive's command register, and for a
    command of 16#40 or more the input byte to its parameter register;
    below 16#40 the parameter register's byte comes back through
    out_param, whatever the status.

  Returns:
    wait_for_controller's status: always

  Status stored: none.
}

{ TODO(pascal) eight frame bytes in win_$ansi_command

  The SAU2 frame is 24 bytes; the reserved slot (4), regs (4), has_input
  (2, and 2 of alignment) and the 4-byte result variable explain 16.
  Nothing in the routine addresses the frame.  The stand-in unused_10
  holds the other 8; what they were is not known (many frames have such
  bytes). }

function win_$ansi_command(unit: pinteger; cmd: pinteger;
                           in in_param: univ win_$byte_t;
                           out out_param: win_$byte_t): integer32;
  internal;
var
  regs: win_$regs_ptr_t;
  has_input: boolean;
  unused_10: array[1..2] of integer32;    { never addressed: the TODO }
begin
  has_input := cmd >= 16#40;

  regs := win_units[unit].regs;
  regs^.command := cmd;

  if has_input then
    regs^.param := in_param;

  { go, and wait }
  regs^.go := 5;
  win_$ansi_command := wait_for_controller(unit);

  { the output byte }
  if not has_input then
    out_param := regs^.param;
end;
