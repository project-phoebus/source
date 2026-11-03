{ FIM_$GET_USER_PC - the longword at the top of the user stack.

  Image addresses:
    sau2  0x00E0AAA6  FIM_$GET_USER_PC
    sau4  0x0F80B1EE  FIM_$GET_USER_PC

  - For a process stopped in the kernel, the result is its user-mode PC;
    nothing is checked.

  Status stored: none.
}

function fim_$get_user_pc: integer32;
var
  usp: integer32;
begin
  usp := proc1_$get_usp;

  fim_$get_user_pc := fim_$long_ptr_t(usp)^;
end;
