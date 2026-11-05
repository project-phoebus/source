%if vme_vectored_ints %then
{ VME_$INT - the VME bus's interrupt routine: call the handler of the
  user interrupt whose vector it was entered by.

  Image addresses:
    sau6  0x7800B600  VME_$INT

  - The vector gives the user interrupt (vme_$user_vector_base on); its
    VME_$USER_VEC entry's handler is called with the entry's argument,
    and its result is not looked at.
  - handler_arg is declared first: the image's frame holds it at the
    top.

  Status stored: none.
}

procedure vme_$int(vector: integer);
  options(val_param);
var
  handler_arg: univ_ptr;
  handler: vme_$handler_t;
begin
  handler := vme_$user_vec[vector - vme_$user_vector_base].handler;
  handler_arg := vme_$user_vec[vector - vme_$user_vector_base].handler_arg;
  discard(handler^(handler_arg));
end;
%else
{ VME_$INT - the VME bus's interrupt routine: find the interrupting level
  and call its handler.

  Image addresses:
    sau5  0x00E0AADE  VME_$INT

  - The first level from 7 down whose int_status bit is clear is
    interrupting; its vector is read and its handler called.  Level 2
    is the disk's or the cartridge tape's, by the controller's status.
  - Level 5 is the Multibus's: the Multibus level is disabled around its
    MBUS_$INT_VEC handler (enabled again when it returns true); level 15
    is logged.
  - Levels 0 and 7, an unrecognized level 2, or none interrupting crash
    the system.
  - LOG_$ADD logs the Multibus adapter's address and the 2 bytes after
    it.

  Status stored: none.
}

procedure vme_$int;
var
  level: integer;
  vector: integer32;
  mlevel: integer32;
begin
  level := vme_$max_level;
  while level >= 0 do
    if level in vme_ctl.int_status then
      level := level - 1
    else begin
      vector := vme_ctl.iack[level];
      case level of
        1: begin
          discard(vme_$int_vec[level].handler^(
                    vme_$int_vec[level].handler_arg));
          return;
        end;
        2: begin
          if 11 in win.int_status then
            level := 2
          else if 9 in win.int_status then
            level := 7
          else
            crash_system(status_$unrecognized_disktape_interrupt);
          discard(vme_$int_vec[level].handler^(
                    vme_$int_vec[level].handler_arg));
          return;
        end;
        5: begin
          mlevel := vector & 16#F;
          pbu_ctl.int_enable := pbu_ctl.int_enable - [mlevel];
          if mlevel = 15 then begin
            log_$add(6, addr(pbu_ctl), 6);
            pbu_ctl.word_00 := pbu_ctl.word_00 & ~16#4000;
          end
          else if mbus_$int_vec[mlevel].handler^(
                    mbus_$int_vec[mlevel].handler_arg) then
            pbu_ctl.int_enable := pbu_ctl.int_enable + [mlevel];
          return;
        end;
        3, 4, 6: begin
          discard(vme_$int_vec[level].handler^(univ_ptr(vector)));
          return;
        end;
        otherwise begin
          exit;
        end;
      end;
    end;
  crash_system(status_$vme_undefined_interrupt);
end;
%endif
