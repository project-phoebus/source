{ FILE_$FW_PAGES - force-write a list of an object's pages.

  Image addresses:
    sau2  0x00E5E71E  FILE_$FW_PAGES

  - The list goes to AST_$PURIFY in batches of up to 32, each sorted
    into descending (unsigned) order, with the flags 16#12 if the object
    is in the lock table, 16#8012 if not; a status code not 0 ends it.

  Status stored:
    status_$ok: an empty list
    ast_$purify's status: the last batch
}

procedure file_$fw_pages(in file_uid: uid_$t;
                         in page_list: file_$page_list_t;
                         in page_count: pinteger;
                         out status_ret: status_$t);
var
  batch: array[1..32] of linteger;
  flags: integer;
  i: pinteger;
  result: boolean;
  start: pinteger;
  n: pinteger;
  next: pinteger;
  k: pinteger;
  j: pinteger;                            { the inner loop's cursors }
  temp: linteger;
begin
  if page_count = 0 then begin
    status_ret.all := status_$ok;
    return;
  end;

  start := 1;
  if file_$delete_int(file_uid, 0, result, status_ret) then
    flags := 16#12
  else
    flags := -16#7FEE;                    { 16#8012 }

  repeat
    if page_count - start + 1 > 32 then
      n := 32
    else
      n := page_count - start + 1;

    next := n + start;
    for k := start to next - 1 do
      batch[k - start + 1] := page_list[k];

    start := next;

    for i := 1 to n - 1 do
      for j := i + 1 to n do
        if batch[j] > batch[i] then begin
          temp := batch[i];
          batch[i] := batch[j];
          batch[j] := temp;
        end;

    ast_$purify(file_uid, flags, 0, batch, n, status_ret);

    if status_ret.code <> 0 then
      exit;
  until start > page_count;
end;
