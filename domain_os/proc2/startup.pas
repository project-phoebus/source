{ PROC2_$STARTUP - the first routine of a new process.

  Image addresses:
    sau2  0x00E73454  PROC2_$STARTUP

  - The level-1 process PROC2_$CREATE or PROC2_$FORK binds: its address
    space is set, its supervisor ACL state cleared, PROC2_$SET_VALID
    called, and user mode entered through FIM_$PROC2_STARTUP.

  Status stored: none.
}

[section(proc2_create_pro, proc2_create_dat)]
procedure proc2_$startup(in context: proc2_$startup_args_t);
begin
  proc1_$set_asid(context.asid);
  acl_$clear_super;
  proc2_$set_valid;
  fim_$proc2_startup(context);
end;
