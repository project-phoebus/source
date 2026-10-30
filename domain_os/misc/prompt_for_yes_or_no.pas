{ prompt_for_yes_or_no - ask on the console until the answer is yes or
  no.

  Image addresses:
    sau2  0x00E33778  prompt_for_yes_or_no (module-local)

  - Up to six characters from terminal line 1; a first character Y or y
    is true, N or n false, anything else prints "Please answer" and
    reads again.  TERM_$READ's status and count are not looked at.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
function prompt_for_yes_or_no: boolean; internal;
var
  status: status_$t;
  buffer: array[1..8] of char;
begin
  repeat
    discard(term_$read(1, buffer, 6, status));
    case buffer[1] of
      'Y', 'y': begin
        prompt_for_yes_or_no := true;
        return;
      end;
      'N', 'n': begin
        prompt_for_yes_or_no := false;
        return;
      end;
      otherwise begin
        os_$print_init_error('Please answer "yes" or "no": %$');
      end;
    end;
  until false;
end;
