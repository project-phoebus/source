{ KBD_$GET_DESC - the keyboard descriptor of a terminal line.

  Image addresses:
    sau2  0x00E1AA26  KBD_$GET_DESC
    sau3  0x00E1A08E  KBD_$GET_DESC
    sau6  0x7801C8F6  KBD_$GET_DESC
    sau7  0x3C41EC12  KBD_$GET_DESC

  - Line 0, the console, has its discipline set to 1 when it is
    another.
  - On the error exits the result is not assigned.
  - A fragment of the OS_TERM module, not of KBD (term/os_term.pas
    includes it).

  Status stored:
    status_$ok: the descriptor is returned
    status_$invalid_line_number: the line is above 3
    status_$requested_line_or_operation_not_implemented: the line is at
      or beyond TERM_$MAX_DTTE, or has no keyboard descriptor
}

{ TODO(pascal) 4 unaddressed frame bytes (stand-in unused_c)

  The frame holds local_status, the result variable and 4 bytes that
  nothing addresses: the 4 bytes over of the TTY_$K_ routines, which take
  the line by address and push it on by value (tty/k_flush_input.pas; here it
  is passed on by address).  The stand-in unused_c holds their place.
  The source cannot set the result variable's place: the declarations
  below are the locals in frame order, the result's slot between them
  (as in TTY_$I_GET_DESC). }

[section(wired_proc, wired_data)]
function kbd_$get_desc(in line: pinteger; out status: status_$t):
  kbd_$desc_ptr_t;
var
  local_status: status_$t;                { the result variable follows }
  unused_c: integer32;                    { the stand-in (TODO) }
begin
  if line > 3 then begin
    status.all := status_$invalid_line_number;
    return;
  end;

  { its `then' part merged with the third `if''s }
  if line >= term_$max_dtte then begin
    status.all := status_$requested_line_or_operation_not_implemented;
    return;
  end;

  status.all := status_$ok;

  { the line must have a keyboard descriptor }
  if dtte[line].alt_handler = nil then begin
    status.all := status_$requested_line_or_operation_not_implemented;
    return;
  end;

  { the console's discipline }
  if (line = 0) and then
     (dtte[line].discipline <> term_$disc_disable_alt) then
    term_$set_discipline(line, term_$disc_disable_alt, local_status);

  kbd_$get_desc := kbd_$desc_ptr_t(dtte[line].alt_handler);
end;
