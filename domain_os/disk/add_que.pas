{ DISK_$ADD_QUE - add a chain of requests to a driver's elevator queue.

  Image addresses:
    sau2  0x00E3C716  DISK_$ADD_QUE
    sau2  0x00E3C5DA  disk_$add_que_merge_ascending (nested)
    sau2  0x00E3C690  disk_$add_que_merge_descending (nested)

  - A driver that keeps its own queue crashes the system.  Unless the
    caller says it is sorted, the chain is exchange-sorted by absolute
    disk address (unsigned).
  - Under the driver's ML lock the chain is cut into cylinder runs; then,
    under the queue's spin lock, the runs are merged into the queue's two
    lists around the head (the nested merges), heading up or down.

  Status stored: none.
}

procedure disk_$add_que(flags: integer; in dev: disk_$device_entry_t;
                        var queue: disk_$que_t; req_list: disk_$io_req_ptr_t);
label
  10;
var
  group_end: disk_$io_req_ptr_t;
  run: disk_$io_req_ptr_t;
  req: disk_$io_req_ptr_t;
  prev1: disk_$io_req_ptr_t;
  prev0: disk_$io_req_ptr_t;
  t: disk_$io_req_ptr_t;
  group_start: disk_$io_req_ptr_t;
  sorted: boolean;
  token: pinteger;
  chunk: integer;
  ahead: pinteger;
  count: pinteger;
  cur_cyl: pinteger;
  below: pinteger;
  pos: pinteger;
  pos2: pinteger;
  i: pinteger;
  j: pinteger;

  { disk_$add_que_merge_ascending - merge runs n, n + 1, ... into an
    ascending list.

    - Each run is spliced in before the first run of the list whose
      cylinder is not below it (unsigned); an empty list takes the whole
      remaining chain.  With mark the last request spliced is marked.

    Status stored: none.
  }

  procedure disk_$add_que_merge_ascending(var list: disk_$io_req_ptr_t;
                                          n: pinteger; mark: boolean);
  var
    prev: disk_$io_req_ptr_t;
    cur: disk_$io_req_ptr_t;
    run: disk_$io_req_ptr_t;
    cyl: pinteger;
    i: pinteger;
  begin
    { the empty list }
    if list^.next = nil then begin
      group_end^.next := list;
      list := disk_$que_array[n];
      if mark then
        group_end^.owner_op.mark := true;
    end
    else begin
      prev := nil;
      cur := list;
      i := n;
      run := disk_$que_array[i];
      repeat
        cyl := run^.daddr.cyl;
        if cyl > cur^.daddr.cyl then begin
          prev := cur^.reserved_18;
          cur := prev^.next;
        end
        else begin
          if prev = nil then
            list := run
          else
            prev^.next := run;
          prev := run^.reserved_18;
          if cyl = cur^.daddr.cyl then
            run^.reserved_18 := cur^.reserved_18;
          prev^.next := cur;
          i := i + 1;
          run := disk_$que_array[i];
          if run = nil then
            exit;
        end;
      until false;

      if mark then
        prev^.owner_op.mark := true;
    end;
  end;

  { disk_$add_que_merge_descending - merge runs n, n - 1, ... into a
    descending list.

    - The ascending merge with the runs taken downward and the cylinders
      compared signed (the sentinel's 16#FFFF reads as -1).

    Status stored: none.
  }

  procedure disk_$add_que_merge_descending(var list: disk_$io_req_ptr_t;
                                           n: pinteger; mark: boolean);
  var
    prev: disk_$io_req_ptr_t;
    cur: disk_$io_req_ptr_t;
    run: disk_$io_req_ptr_t;
    cyl: integer;
    i: pinteger;
  begin
    prev := nil;
    cur := list;
    i := n;
    run := disk_$que_array[i];
    repeat
      cyl := run^.daddr.cyl;
      if cyl < cur^.daddr.cyl then begin
        prev := cur^.reserved_18;
        cur := prev^.next;
      end
      else begin
        if prev = nil then
          list := run
        else
          prev^.next := run;
        prev := run^.reserved_18;
        if cyl = cur^.daddr.cyl then
          run^.reserved_18 := cur^.reserved_18;
        prev^.next := cur;
        i := i - 1;
        run := disk_$que_array[i];
        if run = nil then
          exit;
      end;
    until false;

    if mark then
      prev^.owner_op.mark := true;
  end;

begin
  if (dev.unit_count & 16#200) <> 0 then
    crash_system(status_$disk_queued_drivers_not_supported);

  sorted := (flags & 1) <> 0;
  chunk := req_list^.flags;

  { the exchange sort }
10:
  if not sorted then begin
    prev1 := nil;
    run := req_list;
    while run <> nil do begin
      prev0 := run;
      req := run^.next;
      while req <> nil do begin
        if req^.header.abs_daddr < run^.header.abs_daddr then begin
          t := run^.next;
          if prev1 <> nil then
            prev1^.next := req;
          run^.next := req^.next;
          if req = t then
            req^.next := run
          else begin
            prev0^.next := run;
            req^.next := t;
          end;
          if run = req_list then
            req_list := req;
          group_start := run;
          run := req;
          req := group_start;
        end;
        prev0 := req;
        req := req^.next;
      end;
      prev1 := run;
      run := run^.next;
    end;
  end;

  ml_$lock(dev.flags);

  ahead := 0;
  cur_cyl := queue.position.cyl;
  count := 0;
  disk_$que_array[0] := nil;
  run := req_list;

  { the cylinder runs }
  while run <> nil do begin
    group_start := run;
    count := count + 1;
    disk_$que_array[count] := run;
    if (ahead = 0) and then (cur_cyl <= run^.daddr.cyl) then
      ahead := count;
    run^.flags := 1;
    group_end := run;
    req := run^.next;
    while req <> nil do begin
      if sorted and then
         (group_end^.header.abs_daddr > req^.header.abs_daddr) then begin
        sorted := false;
        ml_$unlock(dev.flags);
        goto 10;
      end;
      if req^.daddr.cyl <> run^.daddr.cyl then begin
        if group_start^.flags <> 1 then
          disk_$io_req_ptr_t(group_start^.next)^.reserved_18 := group_end;
        exit;
      end;
      if chunk + group_end^.header.abs_daddr = req^.header.abs_daddr then
        group_start^.flags := group_start^.flags + 1
      else begin
        if group_start^.flags <> 1 then
          disk_$io_req_ptr_t(group_start^.next)^.reserved_18 := group_end;
        group_start := req;
        req^.flags := 1;
      end;
      group_end := req;
      req := req^.next;
    end;
    run^.reserved_18 := group_end;
    run := req;
  end;

  { the last group }
  if group_start^.flags <> 1 then
    disk_$io_req_ptr_t(group_start^.next)^.reserved_18 := group_end;

  if ahead = 0 then
    below := count
  else if cur_cyl = disk_$que_array[ahead]^.daddr.cyl then
    below := ahead
  else
    below := ahead - 1;
  disk_$que_array[count + 1] := nil;

  token := ml_$spin_lock(queue.current);

  if 15 in queue.position.dir then begin
    { heading up }
    pos := queue.position.cyl;
    if pos <> cur_cyl then begin
      ahead := 0;
      for i := 1 to count do
        if pos <= disk_$que_array[i]^.daddr.cyl then begin
          ahead := i;
          exit;
        end;
    end;
    if ahead <> 0 then
      count := ahead - 1;
    if count <> 0 then
      disk_$add_que_merge_descending(queue.list_b, count, true);
    if ahead <> 0 then
      disk_$add_que_merge_ascending(queue.list_a, ahead, count = 0);
  end
  else begin
    { heading down }
    pos2 := queue.position.cyl;
    if pos2 <> cur_cyl then begin
      below := 0;
      for j := count downto 1 do
        if pos2 >= disk_$que_array[j]^.daddr.cyl then begin
          below := j;
          exit;
        end;
    end;
    if below = 0 then
      count := 1
    else if count = below then
      count := 0
    else
      count := below + 1;
    if count <> 0 then
      disk_$add_que_merge_ascending(queue.list_b, count, true);
    if below <> 0 then
      disk_$add_que_merge_descending(queue.list_a, below, count = 0);
  end;

  ml_$spin_unlock(queue.current, token);
end;
