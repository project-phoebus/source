{ PROC1_$CREATE_P - create a level-1 process.

  Image addresses:
    sau2  0x00E15148  PROC1_$CREATE_P
    sau4  0x0F8159BC  PROC1_$CREATE_P
    sau6  0x780158C4  PROC1_$CREATE_P
    sau7  0x3C416E1C  PROC1_$CREATE_P

  - The process type decides the working-set parameter (5 for types 3,
    4, 5 and 10, 6 for type 8, else 0).  The stack is both the initial
    stack pointer and the base; a failed bind frees it.
  - Only the status's low word is tested after the allocation and the
    bind; on either failure the result is not assigned.

  Status stored:
    proc1_$resume's status: the process was created
    proc1_$alloc_stack's status: no stack
    proc1_$bind's status: no PCB
}

{ TODO(pascal) PROC1_$CREATE_P's longword argument read as two words

  The body reads the second argument's two words from their slots, the
  stack size and then the type, and every caller pushes a constant
  longword, as two merged word constants are pushed.  So the original
  heading is most likely two word parameters, `stack_size: pinteger;
  proc_type: integer' (`val_param').  It is not used here: its four
  Pascal callers (misc/start_mem_lites.pas, pkt/init.pas,
  audit/start_logging.pas, route/service.pas) pass one longword literal
  and would change with it.  To settle: the two-word heading and its
  four callers. }

function proc1_$create_p(proc: univ_ptr; proc_type: integer32;
                         out status: status_$t): pinteger;
var
  stack: linteger;
  ws_param: integer;
  t: integer;
  pid: pinteger;
begin
  t := proc1_$create_args_t(proc_type).proc_type;
  stack := proc1_$alloc_stack(proc1_$create_args_t(proc_type).stack_size,
                              status);
  if status.code <> 0 then
    return;

  case t of
    3, 4, 5, 10: ws_param := 5;
    8: ws_param := 6;
    otherwise ws_param := 0;
  end;

  pid := proc1_$bind(proc, univ_ptr(stack), stack, ws_param,
                     status);
  if status.code <> 0 then begin
    proc1_$free_stack(stack);
    return;
  end;

  proc1_$type[pid] := t;
  proc1_$create_p := pid;
  proc1_$resume(pid, status);
end;
