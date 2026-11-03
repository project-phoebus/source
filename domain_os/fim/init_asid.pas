{ FIM_$INIT_ASID - set up FIM state for a new address space.

  Image addresses:
    sau2  0x00E0AA24  FIM_$INIT_ASID
    sau4  0x0F80B16C  FIM_$INIT_ASID

  Status stored: none.
}

{ TODO(pascal) 16 frame bytes that nothing addresses

  The SAU2 image's frame has 16 bytes with no operand, no result, in a
  global routine (no reserved slot).  FIM_$FREE_ASID, of the same shape,
  has 4 (fim/free_asid.pas).  Stand-in `unused_10'. }

procedure fim_$init_asid(in asid: integer);
var
  unused_10: array[1..4] of integer32;    { see the TODO }
begin
  fim_$clear_trace_fault(asid);

  fim_$quit_value[asid] := fim_$quit_ec[asid].value;

  fim_$quit_inh[asid] := true;
end;
