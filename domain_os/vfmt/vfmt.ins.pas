{ vfmt/vfmt.ins.pas - VFMT_ (formatted text output), for the Domain Pascal
  tree.

  Holds only what the Pascal files use.  The declarations are Apollo's:
  the customer vfmt.ins.pas of SR10.2
  (sr10.2-install/install/ri.apollo.os.v.10.2/sys/ins/vfmt.ins.pas,
  "VFMT.INS.PAS, /sys/ins, jrw, 11/03/87"), copied as they stand there
  for the names used here.  Include base/base.ins.pas before it.

  The kernel's own headings, VFMT_$MAIN and VFMT_$WRITE (VFMT's
  translation, vfmt/vfmt.pas), are not in the customer file: its change
  history says "03/06/81 jrw added vfmt_$main decl" and "01/04/82 jrw
  removed main and rmain decls".  They are written from the image, with
  Apollo's types and the names of Apollo's vfmt_$encode2 (whose first
  four parameters are VFMT_$MAIN's).
}

type
  { Apollo's, under its `%IF isp_$m68k OR isp_$a88k %THEN' arm (the SR10
    68k one): "Alignment attributes permitted on sr10 or later". }
  vfmt_$generic_signed_arg = [aligned(0)] integer32;
  vfmt_$generic_unsigned_arg = [aligned(0)] linteger;

  vfmt_$string_t = array[1..200] of char;

  { Apollo's `vfmt_$arg_ptr_t = ARRAY [1..20] OF ^vfmt_$generic_unsigned_arg':
    the list of argument addresses VFMT_$MAIN walks.  The kernel's
    callers pass the address of their own argument slots, each holding
    the address of one argument (the default convention): the
    VFMT_$FORMATN and VFMT_$WRITEN thunks (vfmt/m68k/formatn.s,
    writen.s).  VFMT_$MAIN reads the elements 1-based
    (vfmt/main.pas). }
  vfmt_$arg_ptr_t = array[1..20] of ^vfmt_$generic_unsigned_arg;

{ VFMT_$MAIN - format a control string and its arguments into a buffer. }
procedure vfmt_$main(in control_string: univ vfmt_$string_t;
                     out text: univ vfmt_$string_t;
                     in text_capacity: integer;
                     out text_length: integer;
                     in args: vfmt_$arg_ptr_t);
  extern;

{ VFMT_$WRITE - format a control string and write it to the console. }
procedure vfmt_$write(in control_string: univ vfmt_$string_t;
                      in args: vfmt_$arg_ptr_t);
  extern;

{ VFMT_$WRITE2.  The map gives one address to three names, the
  VFMT_$WRITEN data segment (0x10 bytes) with VFMT_$WRITE10,
  VFMT_$WRITE2 and VFMT_$WRITE5: a 16-byte entry in a data segment
  (hand assembly), so only its callers show a heading.  Apollo's
  customer vfmt.ins.pas declares the three with 1 + 2, 1 + 5 and 1 + 10
  parameters, every one by address (no options).  The LOG calls push
  three addresses, which is vfmt_$write2's list; vfmt_$write10's would
  be eleven.  So the name used is vfmt_$write2, with Apollo's heading. }
procedure vfmt_$write2(in control_string: univ vfmt_$string_t;
                       in a1, a2: univ vfmt_$generic_signed_arg);
  extern;

{ VFMT_$ENCODE2 and VFMT_$ENCODE5.  The map gives one address to six
  names, the VFMT_$FORMATN data segment (0x10 bytes) with
  VFMT_$FORMAT10, _ENCODE10, _FORMAT5, _ENCODE5, _ENCODE2 and _FORMAT2:
  the 16-byte descriptor whose code jumps to the hand-written thunk
  VFMT_$FORMATN, which calls VFMT_$MAIN with its caller's four slots and
  the address of the argument slots after them (vfmt/vfmt.pas).
  Apollo's customer vfmt.ins.pas declares vfmt_$encode2 and _5 with 4 +
  2 and 4 + 5 parameters, every one by address (no options), whose
  headings are used.  GET_BUILD_TIME's calls push six addresses or nine
  (the unused ones the address of a longword 0 cell): vfmt_$encode2's
  and vfmt_$encode5's lists (misc/get_build_time.pas). }
procedure vfmt_$encode2(in control_string: univ vfmt_$string_t;
                        out text: univ vfmt_$string_t;
                        in text_capacity: integer;
                        out text_length: integer;
                        in a1, a2: univ vfmt_$generic_signed_arg);
  extern;

procedure vfmt_$encode5(in control_string: univ vfmt_$string_t;
                        out text: univ vfmt_$string_t;
                        in text_capacity: integer;
                        out text_length: integer;
                        in a1, a2, a3, a4, a5: univ vfmt_$generic_signed_arg);
  extern;

{ VFMT_$WRITE5, the entry of VFMT_$WRITE2 above (the map gives the
  descriptor all three names).  PEB_$LOAD_WCS's nested check pushes six
  addresses: a control string and five arguments, Apollo's vfmt_$write5
  (customer vfmt.ins.pas, line 78), every one by address. }
procedure vfmt_$write5(in control_string: univ vfmt_$string_t;
                       in a1, a2, a3, a4, a5: univ vfmt_$generic_signed_arg);
  extern;
