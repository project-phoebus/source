{ ml/ml.ins.pas - ML (machine-level locks) routines, for the Domain Pascal
  tree.

  The routines are hand-written assembly (ml/m68k/); these are the
  headings Pascal callers compile against, each read from how compiled
  callers pass the arguments.
}

const
  { The resource locks, by number, that ML_$LOCK and ML_$UNLOCK take and
    give back, and that PROC1_$SET_LOCK and PROC1_$CLR_LOCK set and clear
    for a process.  A process takes them in increasing order (a higher
    number is a higher priority) and gives them back in reverse; a
    process holding one is not suspended.  Server processes hold one for
    their scheduling priority. }
  ml_$mt_lock = 1;
  ml_$xpd_lock = 2;
  ml_$term_lock = 3;
  ml_$proc2_lock = 4;
  ml_$file_lock_lock = 5;
  ml_$ec2_lock = 6;
  ml_$smd_respond_lock = 7;
  ml_$smd_request_lock = 8;
  ml_$acl_lock = 10;
  ml_$proc1_create_lock = 11;
  ml_$mst_asid_lock = 12;
  ml_$server_lock = 13;
  ml_$area_lock = 14;
  ml_$disk_lock = 15;
  ml_$vtoc_lock = 16;
  ml_$bat_lock = 17;
  ml_$ast_lock = 18;
  ml_$ping_server_lock = 19;
  ml_$pmap_lock = 20;
  ml_$net_io_lock = 24;
  ml_$mem_lites_lock = 26;

{ ML_$LOCK, ML_$UNLOCK (hand assembly, ml/m68k/lock.s): the lock number
  by value in a word slot, after the alignment pad (`val_param'). }
procedure ml_$lock(lock_id: integer); options(extern, val_param);
procedure ml_$unlock(lock_id: integer); options(extern, val_param);

{ ML_$SPIN_LOCK (hand assembly, ml/m68k/spin_lock.s): the lock, a
  longword, by address; the token comes back in D0.  ML_$SPIN_UNLOCK
  (ml/m68k/spin_unlock.s): the lock by address, and the token by value
  in a word slot after the pad.

  The token is the status register's word, saved before the IPL is
  raised to 7: pinteger, unsigned, so a longword use widens it with
  zeros. }
function ml_$spin_lock(var lock: integer32): pinteger; extern;
procedure ml_$spin_unlock(var lock: integer32; token: integer);
  options(extern, val_param);

type
  { An exclusion lock, 18 bytes: ML_$EXCLUSION_INIT stores a longword
    0, its own address twice, a longword 0 and the word -1. }
  ml_$exclusion_t = record
    f1: integer32;                        { 0x00 }
    f2: univ_ptr;                         { 0x04 }
    f3: univ_ptr;                         { 0x08 }
    f4: integer32;                        { 0x0C }
    f5: integer;                          { 0x10 }
  end;

{ ML_$EXCLUSION_INIT (hand assembly, ml/m68k/exclusion.s): the lock by
  address off the stack, every field written: `out'. }
procedure ml_$exclusion_init(out excl: ml_$exclusion_t); extern;

{ ML_$EXCLUSION_START and ML_$EXCLUSION_STOP (hand assembly,
  ml/m68k/exclusion.s): the lock by address off the stack, its fields at
  0x0C and 0x10 updated in place: `var'. }
procedure ml_$exclusion_start(var excl: ml_$exclusion_t); extern;
procedure ml_$exclusion_stop(var excl: ml_$exclusion_t); extern;

{ ML_$EXCLUSION_CHECK (hand assembly, ml/m68k/exclusion.s): the lock by
  address off the stack; the result is true when the lock is held. }
function ml_$exclusion_check(var excl: ml_$exclusion_t): boolean; extern;

{ ML_$COND_EXCLUSION_START and ML_$COND_EXCLUSION_STOP (hand assembly,
  ml/m68k/exclusion.s): the lock by address off the stack.  The start
  takes the lock only if it is free, without waiting; its result is
  true when the lock was already held (not taken).  The stop releases a
  lock so taken, waking no one. }
function ml_$cond_exclusion_start(var excl: ml_$exclusion_t): boolean;
  extern;
procedure ml_$cond_exclusion_stop(var excl: ml_$exclusion_t); extern;
