{ audit_$alloc - hand out memory for the audit list's hash nodes.

  Image addresses:
    sau2  0x00E7120C  audit_$alloc (module-local)

  - A size of 0 resets the pool to the start of the AUDIT_LIST section
    and returns 0.  Otherwise the result is the pool's address, which is
    then advanced by the size.
  - A pool that reaches its limit takes physical pages (WP_$CALLOC) at
    the limit; if none is to be had the routine returns.
  - The hash table's other two routines are nested in audit_$load_list
    (audit/load_list.pas).

  Status stored:
    none: the pool had room
    wp_$calloc's status: a page was needed
}

{ TODO(pascal) 4 frame bytes of audit_$alloc no object explains

  The SAU2 frame holds the reserved slot of an `internal' routine, ppn
  and the result variable's slot, and leaves 4 bytes between the
  reserved slot and ppn, held by the stand-in unused_8.  A local
  declared before ppn and never used, or the result variable above ppn
  (the image has sites both ways) with 4 bytes open below. }

function audit_$alloc(size: integer; var status: status_$t): linteger;
  internal;
var
  unused_8: integer32;                    { stand-in }
  ppn: integer32;
begin
  if size = 0 then begin
    audit_$pool_next := linteger(addr(audit_$list_pool));
    if audit_$pool_limit = 0 then
      audit_$pool_limit := audit_$pool_next;
    audit_$alloc := 0;
  end

  else begin
    audit_$alloc := audit_$pool_next;
    audit_$pool_next := audit_$pool_next + size;
    while audit_$pool_next >= audit_$pool_limit do begin
      wp_$calloc(ppn, status);
      if status.all <> status_$ok then
        exit;
      mmu_$install(ppn, univ_ptr(audit_$pool_limit), 0, 16#16);
      audit_$pool_limit := audit_$pool_limit + 16#400;
    end;
  end;
end;
