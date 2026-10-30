{ tty/tty.pas - the TTY module.

  Image addresses:
    sau2  0x00E2DDB4  TTY data (WIRED_DATA, 0x28 bytes)
    sau2  0x00E351B0  TTY data (OS_INIT_DATA, 0x3C bytes)
    sau2  0x00E8242C  TTY data (.DATA, 0x2C bytes)

  One compilation unit, in three code sections and three data sections:
  the map's TTY code segments in WIRED_PROC (0x1750 bytes), OS_INIT_PROC
  (0x118 bytes, TTY_$I_INIT alone) and the default .TEXT (0xBC0 bytes),
  and its TTY data segments in WIRED_DATA (0x28 bytes), OS_INIT_DATA
  (0x3C bytes) and the default .DATA (0x2C bytes).

  Why one module and not three:

  - Internal routines are called across the sections (tty_$i_lock and
    tty_$i_unlock from TTY_$K_RESET), which only their own compilation
    unit can do (ref 5.2, 5.5.4).
  - Each data segment holds its objects in the order of the routines
    that use them, the layout of routines' static variables (ref 5.7.1).
  - The map gives the same module name, TTY, to all six segments.

  So the heading names no sections; the wired routines are headed
  `[section(wired_proc, wired_data)]' and TTY_$I_INIT
  `[section(os_init_proc, os_init_data)]' (ref 5.7.1), on the body's
  heading, not the extern one.  Nested routines inherit it.  The data
  are `static' variables of the routines that use them (see "Data"
  below).

  The routines live in one fragment file each, or a few adjacent ones
  per file (tty/<name>.pas), included below in image order within each
  section, nested routines before their parent; routines not adjacent
  in the image are in a fragment named after the first of them
  (tty/README.md).

  Build: dpc -I domain_os domain_os/tty/tty.pas.  Check:
  tools/pascal_check.sh.
}
module tty;

%include 'base/base.ins.pas';
%include 'ml/ml.ins.pas';
%include 'ec/ec.ins.pas';
%include 'dxm/dxm.ins.pas';
%include 'time/time.ins.pas';
%include 'cal/cal.ins.pas';
%include 'proc1/proc1.ins.pas';
%include 'fim/fim.ins.pas';
%include 'mmu/mmu.ins.pas';
%include 'misc/crash_system.ins.pas';
%include 'sio/sio.ins.pas';
%include 'proc2/proc2.ins.pas';
%include 'tty/tty.ins.pas';

{ The global routines this module defines (ref 7.3.4, Method 2), in map
  order. }
define
  tty_$i_output_buffer_drained;
  tty_$i_flush_input;
  tty_$i_flush_output;
  tty_$i_signal;
  tty_$i_rcv;
  tty_$i_err;
  tty_$i_interrupt;
  tty_$i_hup;
  tty_$k_flush_input;
  tty_$k_flush_output;
  tty_$k_simulate_terminal_input;
  tty_$k_get;
  tty_$i_init;
  tty_$i_dxm_signal;
  tty_$i_enable_crash_func;
  tty_$k_reset;
  tty_$i_set_raw;
  tty_$i_inq_raw;
  tty_$k_set_flag;
  tty_$k_inq_flags;
  tty_$k_set_func_char;
  tty_$k_inq_func_char;
  tty_$k_enable_func;
  tty_$k_inq_func_enabled;
  tty_$k_set_input_flag;
  tty_$k_inq_input_flags;
  tty_$k_set_output_flag;
  tty_$k_inq_output_flags;
  tty_$k_set_echo_flag;
  tty_$k_inq_echo_flags;
  tty_$k_set_input_break_mode;
  tty_$k_inq_input_break_mode;
  tty_$k_set_pgroup;
  tty_$k_inq_pgroup;
  tty_$k_set_session_id;
  tty_$k_inq_session_id;
  tty_$k_set_delay;
  tty_$k_inq_delay;
  tty_$k_drain_output;
  tty_$k_put;

var
  tty_$spin_lock: extern integer32;       { OS_TERM_INIT's data }

{ Module-local routines called before their bodies (ref 5.5.2).

  tty_$i_set_dfl_funcs, in the default section: its body is in
  tty/i_set_dfl_funcs.pas, after the two code sections that call it
  first (tty_$i_set_raw_mode, TTY_$I_INIT).  The `body:' line lets
  tools/pascal_check.sh make this heading `extern' while the fragment is
  not written. }
{ body: tty/i_set_dfl_funcs.pas }
procedure tty_$i_set_dfl_funcs(in out tty: tty_$desc_t; use_dfl: boolean);
  forward; internal;

{ Data.  Each object below is a `static' variable of the routine named,
  declared in that routine with the image's bytes as its initializer.

  WIRED_DATA, 0x28 bytes:

    +0x00  TTY_$I_WORD_ERASE: the word separators, `set of char' (ref
           3.9.3, Figure 3-6): BS, HT, LF, FF, CR and space
    +0x20  TTY_$I_SET_RAW_MODE: the output flags raw mode saves and
           clears, [tty_$of_cr_to_crnl..tty_$of_xtabs]
    +0x24  TTY_$I_SET_RAW_MODE: the input flags,
           [tty_$if_ixany..tty_$if_strip]

  OS_INIT_DATA, 0x3C bytes, all TTY_$I_INIT's (tty/i_init.pas lists
  them).

  .DATA, 0x2C bytes:

    +0x00  tty_$i_set_funcs: the character class of each function slot,
           18 words
    +0x24  TTY_$I_SET_DFL_FUNCS: the slots enabled by default,
           [tty_$func_erase..tty_$func_replay]
    +0x28  TTY_$K_SET_INPUT_BREAK_MODE: the line enders, [tty_$func_eol,
           tty_$func_cr, tty_$func_nl] }

{ ---- WIRED_PROC ---- }
%include 'tty/i_lock.pas';                  { tty_$i_lock         }
%include 'tty/i_unlock.pas';                { tty_$i_unlock       }
%include 'tty/i_advance_ec.pas';            { tty_$i_advance_ec   }
%include 'tty/i_buf_insert.pas';            { tty_$i_buf_insert   }
%include 'tty/i_buf_put.pas';               { tty_$i_buf_put      }
%include 'tty/i_put_chars.pas';             { tty_$i_put_chars,
                                              nested buf_put_delay }
%include 'tty/i_output_buffer_drained.pas'; { TTY_$I_OUTPUT_BUFFER_DRAINED }
%include 'tty/i_xmit_char.pas';             { tty_$i_xmit_char    }
%include 'tty/i_echo_char.pas';             { tty_$i_echo_char    }
%include 'tty/i_newline.pas';               { tty_$i_newline      }
%include 'tty/i_calc_column.pas';           { tty_$i_calc_column  }
%include 'tty/i_delete_char.pas';           { tty_$i_delete_char  }
%include 'tty/i_kill_line.pas';             { tty_$i_kill_line    }
%include 'tty/i_word_erase.pas';            { tty_$i_word_erase   }
%include 'tty/i_flush_input.pas';           { TTY_$I_FLUSH_INPUT }
%include 'tty/i_flush_output.pas';          { TTY_$I_FLUSH_OUTPUT }
%include 'tty/i_signal.pas';                { TTY_$I_SIGNAL       }
%include 'tty/i_break_char.pas';            { tty_$i_break_char   }
%include 'tty/i_rcv.pas';                   { TTY_$I_RCV          }
%include 'tty/i_err.pas';                   { TTY_$I_ERR,
                                              nested tty_$i_store_parity }
%include 'tty/i_interrupt.pas';             { TTY_$I_INTERRUPT }
%include 'tty/i_hup.pas';                   { TTY_$I_HUP }
%include 'tty/i_put_output.pas';            { tty_$i_put_output   }
%include 'tty/i_set_raw_mode.pas';          { tty_$i_set_raw_mode }
%include 'tty/k_flush_input.pas';           { TTY_$K_FLUSH_INPUT }
%include 'tty/k_flush_output.pas';          { TTY_$K_FLUSH_OUTPUT }
%include 'tty/k_simulate_terminal_input.pas'; { TTY_$K_SIMULATE_TERMINAL_INPUT }
%include 'tty/i_wait.pas';                  { tty_$i_wait         }
%include 'tty/k_get.pas';                   { TTY_$K_GET          }

{ ---- OS_INIT_PROC ---- }
%include 'tty/i_init.pas';                  { TTY_$I_INIT         }

{ ---- default section (.TEXT) ---- }
%include 'tty/i_dxm_signal.pas';            { TTY_$I_DXM_SIGNAL   }
%include 'tty/i_set_funcs.pas';             { tty_$i_set_funcs }
%include 'tty/i_set_dfl_funcs.pas';         { tty_$i_set_dfl_funcs }
%include 'tty/i_enable_crash_func.pas';     { TTY_$I_ENABLE_CRASH_FUNC }
%include 'tty/k_reset.pas';                 { TTY_$K_RESET        }
%include 'tty/i_set_raw.pas';               { TTY_$I_SET_RAW }
%include 'tty/i_inq_raw.pas';               { TTY_$I_INQ_RAW }
%include 'tty/k_set_flag.pas';              { TTY_$K_SET_FLAG }
%include 'tty/k_inq_flags.pas';             { TTY_$K_INQ_FLAGS }
%include 'tty/k_set_func_char.pas';         { TTY_$K_SET_FUNC_CHAR }
%include 'tty/k_inq_func_char.pas';         { TTY_$K_INQ_FUNC_CHAR }
%include 'tty/k_enable_func.pas';           { TTY_$K_ENABLE_FUNC }
%include 'tty/k_inq_func_enabled.pas';      { TTY_$K_INQ_FUNC_ENABLED }
%include 'tty/k_set_input_flag.pas';        { TTY_$K_SET_INPUT_FLAG }
%include 'tty/k_inq_input_flags.pas';       { TTY_$K_INQ_INPUT_FLAGS }
%include 'tty/k_set_output_flag.pas';       { TTY_$K_SET_OUTPUT_FLAG }
%include 'tty/k_inq_output_flags.pas';      { TTY_$K_INQ_OUTPUT_FLAGS }
%include 'tty/k_set_echo_flag.pas';         { TTY_$K_SET_ECHO_FLAG }
%include 'tty/k_inq_echo_flags.pas';        { TTY_$K_INQ_ECHO_FLAGS }
%include 'tty/k_set_input_break_mode.pas';  { TTY_$K_SET_INPUT_BREAK_MODE }
%include 'tty/k_inq_input_break_mode.pas';  { TTY_$K_INQ_INPUT_BREAK_MODE }
%include 'tty/k_set_pgroup.pas';            { TTY_$K_SET_PGROUP }
%include 'tty/k_inq_pgroup.pas';            { TTY_$K_INQ_PGROUP }
%include 'tty/k_set_session_id.pas';        { TTY_$K_SET_SESSION_ID }
%include 'tty/k_inq_session_id.pas';        { TTY_$K_INQ_SESSION_ID }
%include 'tty/k_set_delay.pas';             { TTY_$K_SET_DELAY }
%include 'tty/k_inq_delay.pas';             { TTY_$K_INQ_DELAY }
%include 'tty/k_drain_output.pas';          { TTY_$K_DRAIN_OUTPUT }
%include 'tty/k_put.pas';                   { TTY_$K_PUT          }
