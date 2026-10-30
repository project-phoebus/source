{ VME_$INIT - install the VME bus's interrupt routines and its levels'
  handlers at boot.

  Image addresses:
    sau5  0x00E30970  VME_$INIT

  - VME_$INT and VME_$ERR_INT go to their vectors; level 4 gets
    GPU_$INTERRUPT and level 6 VME_$USER_INT.
  - Each controller table entry of type 0 (the Winchester disk), 5 (the
    cartridge tape) or 2 (the ring) gives its do_io routine to level 2,
    7 or 1, with the entry as its argument (the last of each type wins).

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure vme_$init;
var
  dcte: dcte_ptr_t;
begin
  io_$trap(vme_vector, addr(vme_$int));
  io_$trap(vme_err_vector, addr(vme_$err_int));

  vme_$int_vec[4].handler := addr(gpu_$interrupt);
  vme_$int_vec[4].handler_arg := nil;
  vme_$int_vec[6].handler := addr(vme_$user_int);
  vme_$int_vec[6].handler_arg := nil;

  dcte := io_$dcte_list;
  while dcte <> nil do begin
    case dcte^.ctype of
      io_ctype_win: begin
        vme_$int_vec[2].handler := dcte^.disk_do_io;
        vme_$int_vec[2].handler_arg := dcte;
      end;
      io_ctype_ctape: begin
        vme_$int_vec[7].handler := dcte^.disk_do_io;
        vme_$int_vec[7].handler_arg := dcte;
      end;
      io_ctype_ring: begin
        vme_$int_vec[1].handler := dcte^.disk_do_io;
        vme_$int_vec[1].handler_arg := dcte;
      end;
    end;
    dcte := dcte^.nextp;
  end;
end;
