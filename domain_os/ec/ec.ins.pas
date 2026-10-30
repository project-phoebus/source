{ ec/ec.ins.pas - level-1 eventcounts (EC_$) and the level-2 ones (EC2_$),
  for the Domain Pascal tree.

  Most EC_$ routines are hand-written assembly (ec/m68k/*.s).  The EC2
  statuses, the level-2 eventcount, its list types and the user
  routines' headings are Apollo's (customer ec2.ins.pas and base.ins.pas
  of SR10.2).
}

const
  { Apollo's customer ec2.ins.pas, its name and value ("bad eventcount
    passed in"; stcode.db.10.2: "bad eventcount"). }
  ec2_$bad_eventcount = 16#00180004;

type
  { A level-1 eventcount, 12 bytes: the value at 0x00, the waiter list's
    head at 0x04 and tail at 0x08.  The waiters have no Pascal type yet,
    so the list pointers are univ_ptr. }
  ec_$eventcount_t = record
    value: integer32;                     { 0x00 }
    waiter_list_head: univ_ptr;           { 0x04 }
    waiter_list_tail: univ_ptr;           { 0x08 }
  end;

  ec_$eventcount_ptr_t = ^ec_$eventcount_t;

  { The two lists EC_$WAITN takes, as `in' `univ' arrays (ref 5.3.3), in
    the idiom of tty_$chars_t (tty/tty.ins.pas): a one-element formal
    that the routine indexes beyond its bound, from element 1, for as
    many elements as its count says.  Apollo's customer ec2.ins.pas
    declares EC2_$WAIT's lists in the same idiom: `IN ec_plist: UNIV
    ec2_$ptr_list_t', with `ec2_$ptr_list_t = ARRAY[1..2] OF
    ec2_$ptr_t'. }
  ec_$waitn_ecs_t = array[1..1] of ec_$eventcount_ptr_t;
  ec_$waitn_vals_t = array[1..1] of integer32;

{ EC_$ADVANCE_WITHOUT_DISPATCH (hand assembly,
  ec/m68k/advance_without_dispatch.s): advances an eventcount without
  dispatching; the eventcount by address. }
procedure ec_$advance_without_dispatch(var ec: ec_$eventcount_t); extern;

{ EC_$ADVANCE (hand assembly, ec/m68k/advance.s): advances an eventcount
  at raised priority, then dispatches; the eventcount by address. }
procedure ec_$advance(var ec: ec_$eventcount_t); extern;

{ ADVANCE (map symbol, hand assembly in PROC1_ASM, ec/m68k/advance_int.s):
  EC_$ADVANCE's body without the priority bracket and the dispatch; the
  eventcount by address. }
procedure advance(var ec: ec_$eventcount_t); extern;

{ EC_$INIT - initialize a level-1 eventcount. }
procedure ec_$init(out ec: ec_$eventcount_t); extern;

{ EC_$WAITN (hand assembly in the PROC1 data run, ec/m68k/wait.s: no
  frame, the arguments read off the stack): waits until one of a list of
  eventcounts reaches its value.  The two lists by address, the count a
  word by value (`val_param').  The result is the 1-based number of the
  eventcount satisfied, a word in D0. }
function ec_$waitn(in ecs: univ ec_$waitn_ecs_t;
                   in vals: univ ec_$waitn_vals_t;
                   num_ecs: integer): integer;
  options(extern, val_param);

{ EC_$WAIT (hand assembly in the PROC1 data run, ec/m68k/wait.s: no
  frame, the arguments read off the stack): waits until one of up to
  three eventcounts reaches its value.  Six longwords by value
  (`val_param'): three eventcount pointers, the second and third nil
  when unused, and three values.  The result is a word, the 0-based
  number of the satisfied eventcount. }
function ec_$wait(ec1: ec_$eventcount_ptr_t; ec2: ec_$eventcount_ptr_t;
                  ec3: ec_$eventcount_ptr_t; val1: integer32;
                  val2: integer32; val3: integer32): integer;
  options(extern, val_param);

type
  { A level-2 eventcount and its pointer, as Apollo's customer
    base.ins.pas declares them for SR10 68k (`ec2_$eventcount_t =
    [volatile] RECORD value: [aligned(1)] integer32; awaiters: pinteger;
    END; ec2_$ptr_t = ^ec2_$eventcount_t;'). }
  ec2_$eventcount_t = [volatile] record
    value: [aligned(1)] integer32;        { 0x00 }
    awaiters: pinteger;                   { 0x04 }
  end;
  ec2_$ptr_t = ^ec2_$eventcount_t;

{ EC2_$REGISTER_EC1 - give a level-1 eventcount an EC2 number. }
function ec2_$register_ec1(ec1: ec_$eventcount_ptr_t;
                           out status: status_$t): ec2_$ptr_t;
  options(extern, val_param);

const
  { Apollo's customer ec2.ins.pas (SR10.2): the other statuses of the
    level-2 eventcounts, their names and values (stcode.db.10.2:
    "internal table exhausted", "internal error", "asynchronous fault
    occurred while waiting", "unable to allocate level 1 eventcount",
    "level 1 eventcount not allocated"). }
  ec2_$no_wait_entries = 16#00180001;
  ec2_$internal_error = 16#00180002;
  ec2_$wait_quit = 16#00180003;
  ec2_$no_more_ecs = 16#00180005;
  ec2_$ec1_not_allocated = 16#00180006;

  { Apollo's customer ec2.ins.pas: `ec2_$always_ready_ec = 1', with the
    comment "as ec2_$ptr to ec2_$wait is an always ready EC2". }
  ec2_$always_ready_ec = 1;

type
  { Apollo's customer ec2.ins.pas: EC2_$WAIT's two lists, in the idiom
    of ec_$waitn_ecs_t above: two-element formals the routine indexes
    from 1 up to its count. }
  ec2_$ptr_list_t = array[1..2] of ec2_$ptr_t;
  ec2_$val_list_t = array[1..2] of integer32;

var
  { EC2_$WAIT_ECS (map symbol, the one symbol of the map's EC2_ASM data
    segment, 0x300 bytes, hand-written data in WIRED_DATA;
    ec/m68k/ec2_wait_ecs.s): one level-1 eventcount per process, 64 of
    12 bytes, indexed from 1. }
  ec2_$wait_ecs: extern array[1..64] of ec_$eventcount_t;

{ EC_$READ - read a level-1 eventcount's value. }
function ec_$read(in ec: ec_$eventcount_t): integer32; extern;

{ EC_$ADVANCE_ALL (hand assembly in PROC1_ASM, ec/m68k/advance_all.s):
  wakes every waiter of an eventcount; the eventcount by address. }
procedure ec_$advance_all(var ec: ec_$eventcount_t); extern;

{ The EC2 module's routines (ec/ec2.pas; its code segments in
  OS_INIT_PROC and .TEXT), in map order; EC2_$REGISTER_EC1's heading is
  above. }

{ EC2_$INIT_S - initialize the EC2 module at boot. }
procedure ec2_$init_s; extern;

{ EC2_$WAIT - wait until one of a list of level-2 eventcounts reaches its
  value. }
function ec2_$wait(in ec_plist: univ ec2_$ptr_list_t;
                   in ec_vlist: univ ec2_$val_list_t;
                   necs: integer;
                   out sts: status_$t): pinteger; extern;

{ EC2_$WAKEUP - wake the waiters of a level-2 eventcount whose values have
  been reached. }
procedure ec2_$wakeup(in ec: ec2_$eventcount_t; out status: status_$t);
  extern;

{ EC2_$ALLOCATE_EC1 - hand out a PBU eventcount. }
function ec2_$allocate_ec1(out status: status_$t): ec2_$ptr_t; extern;

{ EC2_$GET_EC1_ADDR - the address of the level-1 eventcount behind an EC2
  number. }
function ec2_$get_ec1_addr(in ec: ec2_$ptr_t; out status: status_$t):
  integer32; options(extern, a0_return);

{ EC2_$RELEASE_EC1 - give back a PBU eventcount. }
procedure ec2_$release_ec1(in ec: ec2_$ptr_t; out status: status_$t);
  extern;

{ EC2_$GET_VAL - the value of an eventcount named by an EC2 number. }
function ec2_$get_val(in ec: ec2_$ptr_t; out status: status_$t): integer32;
  extern;

{ The EC2U module's routines (ec/ec2u.pas, .TEXT), in map order, Apollo's
  headings (customer ec2.ins.pas) and names. }

{ EC2_$INIT - initialize a level-2 eventcount. }
procedure ec2_$init(out ec: ec2_$eventcount_t); extern;

{ EC2_$READ - read a level-2 eventcount. }
function ec2_$read(in ec: ec2_$eventcount_t): integer32; extern;

{ EC2_$ADVANCE - advance a level-2 eventcount. }
procedure ec2_$advance(in out ecnt: ec2_$eventcount_t; out sts: status_$t);
  extern;

var
  { EC_$NIL_EC (map symbol, in the binder's ABSOLUTE section at address
    0; ec/m68k/nil_ec.s): the eventcount that callers of EC_$WAIT pass
    for an unused entry, as a symbol's address, not the constant nil. }
  ec_$nil_ec: extern ec_$eventcount_t;
