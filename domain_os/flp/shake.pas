{ SHAKE - move a block between memory and the controller's data register.

  Image addresses:
    sau2  0x00E3E49E  SHAKE
    sau4  0x0F846456  SHAKE
    sau8  0x03C4665C  SHAKE

  - dir 0 reads count bytes into the words, widened with zeros; dir 1
    writes the words' low bytes.
  - Global: a map symbol without `$'.

  Returns:
    status_$ok: the controller is ready in direction dir
    status_$disk_controller_timeout: not ready after 2000 polls
    status_$disk_controller_error: the controller's direction is not dir's

  Status stored: none.
}

function shake(var data: univ flp_$words_t; in count: integer;
               in dir: integer): integer32;
var
  i: integer;                             { no register: not read }
  polls: integer;
  unused_8: integer32;                    { stand-in }
  unused_c: integer32;                    { stand-in }
begin
  with flp_hw_addr^ do
    for i := 0 to count - 1 do begin
%if floppy_atbus %then
      polls := 0;
      repeat
        polls := polls + 1;
      until polls = 25;
%endif
      polls := 2000;
      while not (7 in main_status_bits) do begin
        polls := polls - 1;
        if polls <= 0 then begin
          shake := status_$disk_controller_timeout;
          return;
        end;
      end;
      if 6 in main_status_bits then begin
        if dir = 0 then
          data[i] := data_reg
        else begin
          shake := status_$disk_controller_error;
          return;
        end;
      end
      else if dir = 1 then
        data_reg := data[i]
      else begin
        shake := status_$disk_controller_error;
        return;
      end;
    end;

  shake := status_$ok;
end;
