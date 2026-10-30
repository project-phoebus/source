{ UID_$INIT - put this node's ID into the UID generator.

  Image addresses:
    sau2  0x00E30950  UID_$INIT

  - The generator's node field, the low 20 bits of its low longword,
    becomes NODE_$ME, the counter bits above it kept.

  Status stored: none.
}

[section(os_init_proc, os_init_data)]
procedure uid_$init;
begin
  uid_$generator_state.low.node := node_$me;
end;
