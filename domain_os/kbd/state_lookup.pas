{ kbd_$state_lookup - find the state machine's entry for a state and a key.

  Image addresses:
    sau2  0x00E1C9FC  kbd_$state_lookup (module-local)
    sau6  0x7801E8F0  kbd_$state_lookup (module-local)
    sau7  0x3C420BDC  kbd_$state_lookup (module-local)

  - The state's entries are kbd_$state_range[state].first .. limit - 1;
    when none matches, entry limit is the state's default.
  - The states 5..14 index past kbd_$state_table's ten entries (the
    TODO(pascal) in kbd/kbd.pas).

  Status stored: none.
}

function kbd_$state_lookup(state: integer; key: char):
  kbd_$state_entry_ptr_t; internal;
var
  i: integer;
begin
  { the state's entries }
  for i := kbd_$state_range[state].first to
           kbd_$state_range[state].limit - 1 do
    if kbd_$state_table[i].key = key then begin
      kbd_$state_lookup := addr(kbd_$state_table[i]);
      return;
    end;

  { none matches: the state's default }
  kbd_$state_lookup :=
    addr(kbd_$state_table[kbd_$state_range[state].limit]);
end;
