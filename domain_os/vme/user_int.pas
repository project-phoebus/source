{ VME_$USER_INT - the handler of VME level 6: call the user interrupt's
  handler.

  Image addresses:
    sau5  0x00E0AC44  VME_$USER_INT

  - The low four bits of the vector are the user interrupt's number; its
    VME_$USER_VEC handler is called with its argument.  The result is
    true whatever the handler returned.

  Status stored: none.
}

function vme_$user_int(vector: univ_ptr): boolean;
  options(val_param);
var
  n: integer32;
begin
  n := integer32(vector) & 16#F;
  discard(vme_$user_vec[n].handler^(vme_$user_vec[n].handler_arg));
  vme_$user_int := true;
end;
