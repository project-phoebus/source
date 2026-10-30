# The TTY subsystem in Domain Pascal

The TTY line discipline.

## Layout

In Pascal a module is one compilation unit.  Module-local routines are
called with short calls, and nested routines must sit inside their
parent, so the per-routine files cannot be compiled on their own.
Instead:

- **The module file**, `tty.pas`, holds the module heading, the includes,
  the `define` list, and an `%include` of each fragment in image order
  within each code section.  The map has three TTY code segments and
  three data segments, in different load sections, but they are **one
  module**: routines with no global symbol are called across the sections
  (`tty_$i_lock` from TTY_$K_RESET), and each data segment holds its
  objects in the order of the routines that use them.  So the routines
  carry section attributes (ref 5.7.1) and the data are `static`
  variables of those routines.  `tty.pas` gives the evidence in full.

  | section                      | code   | data   | routines headed            |
  |------------------------------|--------|--------|----------------------------|
  | WIRED_PROC / WIRED_DATA      | 0x1750 | 0x28   | `[section(wired_proc, wired_data)]` |
  | OS_INIT_PROC / OS_INIT_DATA  | 0x118  | 0x3C   | `[section(os_init_proc, os_init_data)]` |
  | default (.TEXT / .DATA)      | 0xBC0  | 0x2C   | no attribute               |

- **Fragment files** (`<name>.pas`) hold routine bodies only, with no
  heading or declarations of their own.
- **Insert files** (`*.ins.pas`) hold constants, types and routine
  headings.  `tty.ins.pas` covers this subsystem.  `base/base.ins.pas`,
  `ml/ml.ins.pas` and the others hold what TTY uses from other subsystems.
  They grow as routines need them.

## Routines and their fragments

Most routines have a fragment of their own, named after the routine.
Some fragments hold a few adjacent routines; where related routines are
not adjacent in the image, the ones that are elsewhere go in a fragment
named after the first of them.  A nested routine goes inside its
parent's fragment.

| routine(s)                                  | fragment                       |
|---------------------------------------------|--------------------------------|
| TTY_$I_OUTPUT_BUFFER_DRAINED                | `i_output_buffer_drained.pas`  |
| TTY_$I_FLUSH_INPUT                          | `i_flush_input.pas`            |
| TTY_$I_FLUSH_OUTPUT                         | `i_flush_output.pas`           |
| TTY_$I_SIGNAL                               | `i_signal.pas`                 |
| TTY_$I_INTERRUPT                            | `i_interrupt.pas`              |
| TTY_$I_HUP                                  | `i_hup.pas`                    |
| TTY_$I_DXM_SIGNAL (default section)         | `i_dxm_signal.pas`             |
| TTY_$I_ERR, nested tty_$i_store_parity      | `i_err.pas`                    |
| TTY_$I_ENABLE_CRASH_FUNC (default section)  | `i_enable_crash_func.pas`      |
| TTY_$I_SET_RAW                              | `i_set_raw.pas`                |
| TTY_$I_INQ_RAW                              | `i_inq_raw.pas`                |
| TTY_$K_SET_FLAG                             | `k_set_flag.pas`               |
| TTY_$K_INQ_FLAGS                            | `k_inq_flags.pas`              |
| TTY_$K_SET_INPUT_FLAG                       | `k_set_input_flag.pas`         |
| TTY_$K_INQ_INPUT_FLAGS                      | `k_inq_input_flags.pas`        |
| TTY_$K_SET_OUTPUT_FLAG                      | `k_set_output_flag.pas`        |
| TTY_$K_INQ_OUTPUT_FLAGS                     | `k_inq_output_flags.pas`       |
| TTY_$K_SET_ECHO_FLAG                        | `k_set_echo_flag.pas`          |
| TTY_$K_INQ_ECHO_FLAGS                       | `k_inq_echo_flags.pas`         |
| TTY_$K_SET_FUNC_CHAR                        | `k_set_func_char.pas`          |
| TTY_$K_INQ_FUNC_CHAR                        | `k_inq_func_char.pas`          |
| TTY_$K_ENABLE_FUNC                          | `k_enable_func.pas`            |
| TTY_$K_INQ_FUNC_ENABLED                     | `k_inq_func_enabled.pas`       |
| TTY_$K_SET_INPUT_BREAK_MODE                 | `k_set_input_break_mode.pas`   |
| TTY_$K_INQ_INPUT_BREAK_MODE                 | `k_inq_input_break_mode.pas`   |
| TTY_$K_SET_PGROUP                           | `k_set_pgroup.pas`             |
| TTY_$K_INQ_PGROUP                           | `k_inq_pgroup.pas`             |
| TTY_$K_SET_SESSION_ID                       | `k_set_session_id.pas`         |
| TTY_$K_INQ_SESSION_ID                       | `k_inq_session_id.pas`         |
| TTY_$K_SET_DELAY                            | `k_set_delay.pas`              |
| TTY_$K_INQ_DELAY                            | `k_inq_delay.pas`              |
| TTY_$K_DRAIN_OUTPUT                         | `k_drain_output.pas`           |
| TTY_$K_FLUSH_INPUT                          | `k_flush_input.pas`            |
| TTY_$K_FLUSH_OUTPUT                         | `k_flush_output.pas`           |
| TTY_$K_SIMULATE_TERMINAL_INPUT              | `k_simulate_terminal_input.pas` |
| tty_$i_put_chars, nested buf_put_delay      | `i_put_chars.pas`              |
| tty_$i_set_funcs                            | `i_set_funcs.pas`              |
| tty_$i_set_dfl_funcs                        | `i_set_dfl_funcs.pas`          |
| TTY_$I_GET_DESC                             | `i_get_desc.pas`: in the OS_TERM module, not a TTY one; `term/os_term.pas` includes it |
| (data)                                      | `static` variables of the routines that use them (`tty.pas`, "Data"); TTY_$SPIN_LOCK is OS_TERM_INIT's data, `extern` here |
| every other routine                         | `<its name, without tty_$>.pas` |

## Checking

`tools/pascal_check.sh` (run from `domain_os/`) runs `dpc --check-only`
over the module, skipping fragments that do not exist yet.  The module
compiles, and `make` links it into the kernel.

## Open items

The `TODO(pascal)` comments are in the fragments.

## Named dispatch codes

TTY_$I_GET_DESC's discipline 2 is TERM's named constant term_$disc_
enable_alt (term/README.md); the code is unchanged.
