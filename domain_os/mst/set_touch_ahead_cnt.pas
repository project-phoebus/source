{ MST_$SET_TOUCH_AHEAD_CNT - set the touch-ahead count of a range,
  unprivileged.

  Image addresses:
    sau2  0x00E446FC  MST_$SET_TOUCH_AHEAD_CNT
    sau4  0x0F84CB0A  MST_$SET_TOUCH_AHEAD_CNT
    sau6  0x7804BE28  MST_$SET_TOUCH_AHEAD_CNT
    sau7  0x3C454C1C  MST_$SET_TOUCH_AHEAD_CNT
    sau8  0x03C4CC94  MST_$SET_TOUCH_AHEAD_CNT
    sau9  0x3C44BE1C  MST_$SET_TOUCH_AHEAD_CNT

  - One call of MST_$PRIV_SET_TOUCH_AHEAD_CNT, not privileged, with the
    same five arguments.

  Status stored:
    MST_$PRIV_SET_TOUCH_AHEAD_CNT's status: in either case
}

procedure mst_$set_touch_ahead_cnt(in va: integer32; in length: integer32;
                                   in count: integer;
                                   out old_count: pinteger;
                                   out status: status_$t);
begin
  mst_$priv_set_touch_ahead_cnt(false, va, length, count, old_count,
                                status);
end;
