{ FIM_$FREE_ASID - release FIM state of an address space.

  Image addresses:
    sau2  0x00E0AA6C  FIM_$FREE_ASID

  Status stored: none.
}

{ TODO(pascal) 4 frame bytes that nothing addresses

  The SAU2 image's frame has 4 bytes with no operand, no result, in a
  global routine.  Stand-in `unused_4'; FIM_$INIT_ASID has 16
  (init_asid.pas). }

procedure fim_$free_asid(in asid: integer);
var
  unused_4: integer32;                    { see the TODO }
begin
  fim_$clear_trace_fault(asid);

  fim_$user_fim_addr[asid] := 0;

  fim_$quit_inh[asid] := true;
end;
