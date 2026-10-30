{ svc/svc.ins.pas - SVC_ (the system-call trap dispatchers), for the
  Domain Pascal tree.

  Only what the Pascal files use.  Include base/base.ins.pas before it.

  The dispatchers SVC_$TRAP0 .. SVC_$TRAP8 (map symbols in the map's
  SVC_CATCHER data segment, hand assembly, svc/m68k/) are entered by the
  CPU's TRAP #n vectors, not called: OS_$INIT's vector table holds their
  addresses (os/init.pas, OS_INIT_DATA +0x124 .., RELOC cells), so these
  parameterless headings serve only `addr'.  There is no SVC_$TRAP6:
  vector 38 is FIM_$UNDEF_TRAP's.
}

procedure svc_$trap0; extern;
procedure svc_$trap1; extern;
procedure svc_$trap2; extern;
procedure svc_$trap3; extern;
procedure svc_$trap4; extern;
procedure svc_$trap5; extern;
procedure svc_$trap7; extern;
procedure svc_$trap8; extern;
