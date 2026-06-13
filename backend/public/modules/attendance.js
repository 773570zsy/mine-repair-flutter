// ==================== 考勤/加班模块 ====================

function loadAttendanceCard(){
  api('/inspection/attendance/today').then(function(r){var rec=r||{},sym=rec.attendance_symbol||'';
    var attOpts=['','X','Y','Z','V','G','△','△/X','△/Y','△/Z','△/V'].map(function(s){return '<option value="'+s+'"'+(s===sym?' selected':'')+'>'+(s||'请选择')+'</option>'}).join('');
    var ae=document.getElementById('attCard');
    if(sym){ae.innerHTML='<div class="tag t-done" style="font-size:14px">✓ 已提交: '+sym+'</div>'}
    else{ae.innerHTML='<select id="attSymbol" style="margin-bottom:8px">'+attOpts+'</select><br><button class="btn btn-p btn-sm" onclick="submitAttendance()">提交考勤</button>'}
    var oe=document.getElementById('otCard');
    if(rec.overtime_hours){var oI='✓ 已提交: '+rec.overtime_hours+'h';if(rec.overtime_start)oI+='<br><small style="color:var(--text2)">'+rec.overtime_start+' → '+rec.overtime_end+'</small>';oe.innerHTML='<div class="tag t-done" style="font-size:14px">'+oI+'</div>'}
    else{oe.innerHTML='<div class="row2" style="margin-bottom:8px"><input id="otStart" type="time" value="'+(rec.overtime_start||'')+'" /><input id="otEnd" type="time" value="'+(rec.overtime_end||'')+'" /></div><input id="otLocation" placeholder="加班地点" value="'+(rec.overtime_location||'')+'" style="margin-bottom:8px" /><br><button class="btn btn-p btn-sm" onclick="submitAttendance()">提交加班</button>'}
  })
}
function submitAttendance(){
  var sym=document.getElementById('attSymbol')?.value||'',otS=document.getElementById('otStart')?.value||'',otE=document.getElementById('otEnd')?.value||'',loc=document.getElementById('otLocation')?.value?.trim()||'';
  api('/inspection/attendance/submit',{method:'POST',data:{attendance_symbol:sym,overtime_start:otS,overtime_end:otE,overtime_location:loc}}).then(function(){toast('提交成功');loadAttendanceCard()})
}
