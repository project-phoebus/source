{ FIM_$INSTALL - install a user-mode fault handler for the current
  address space.

  Image addresses:
    sau2  0x00E0A9C2  FIM_$INSTALL

  - The result is the old handler; when there was none, the address
    space's quit inhibit is lifted.

  Status stored: none.
}

function fim_$install(in handler: integer32): integer32;
var
  old: integer32;
begin
  old := fim_$user_fim_addr[proc1_$as_id];
  fim_$install := old;
  fim_$user_fim_addr[proc1_$as_id] := handler;

  if old = 0 then
    fim_$quit_inh[proc1_$as_id] := false;
end;
