// ==================== 每日一测模块 ====================

function showQuiz(){api('/quiz/today').then(function(d){if(!d)return;if(d.done){showQuizReview(d.result)}else{startQuiz(d.questions)}})}
function startQuiz(qs){
  var i=0,answers=[],selectedOpts=[]; // selectedOpts 记录每题选中的选项索引
  var el=document.createElement('div');el.className='modal-mask';
  var catIcons={'安全操作':'🔧','安全红线':'🚫','公司制度':'📋','十大禁令':'⛔','道路交通':'🚛','高原知识':'🏔','发动机理论':'⚙','电气系统':'⚡','液压系统':'💧','变速箱':'🔗','底盘':'🛞','轮胎':'⚫','故障判断':'🔍','日常保养':'🛢','工程机械':'🏗','矿山安全':'⛏','安全基础':'📖','四受控':'🔄','八大危险作业':'⚠'};
  function showQ(){
    if(i>=qs.length){submitQuiz(answers,el);return}
    var q=qs[i],opts='',labels=['A','B','C','D'];
    try{JSON.parse(q.options).forEach(function(o,j){
      var selClass=selectedOpts[i]===j?' quiz-selected':'';
      opts+='<div class="quiz-opt'+selClass+'" id="opt'+j+'" onclick="window._selOpt('+j+')"><span class="q-opt-letter">'+labels[j]+'</span> '+o+'</div>'
    })}catch(e){}
    var barW=((i+1)/qs.length*100).toFixed(0);
    var prevBtn=i>0?'<button class="btn btn-o btn-sm" onclick="window._prevQ()">◀ 上一题</button>':'<span></span>';
    var nextLabel=i<qs.length-1?'下一题 ▶':'✓ 提交';
    el.innerHTML='<div class="modal quiz-modal" style="max-width:560px;padding:0;overflow:hidden;border-radius:14px"><div class="quiz-progress-bar"><div class="quiz-progress-fill" style="width:'+barW+'%"></div></div><div class="quiz-body"><div class="quiz-header"><span class="tag t-progress" style="font-size:11px">'+(catIcons[q.category]||'📝')+' '+q.category+'</span><span style="color:var(--text2);font-size:12px">'+(i+1)+'/'+qs.length+'</span></div><div class="quiz-question">'+q.question+'</div><div class="quiz-options">'+opts+'</div><div class="quiz-footer" style="display:flex;justify-content:space-between;align-items:center">'+prevBtn+'<button class="btn btn-p quiz-btn" onclick="window._nextQ()">'+nextLabel+'</button></div></div></div>';
    el.onclick=function(e){if(e.target===el)el.remove()};document.body.appendChild(el);
  }
  window._selOpt=function(j){
    selectedOpts[i]=j;
    document.querySelectorAll('.quiz-opt').forEach(function(o){o.classList.remove('quiz-selected')});
    var opt=document.getElementById('opt'+j);if(opt)opt.classList.add('quiz-selected');
  };
  window._nextQ=function(){
    answers[i]={question_id:qs[i].id,user_answer:selectedOpts[i]>=0?String.fromCharCode(65+selectedOpts[i]):''};
    i++;showQ();
  };
  window._prevQ=function(){
    // 保存当前题的选择
    answers[i]={question_id:qs[i].id,user_answer:selectedOpts[i]>=0?String.fromCharCode(65+selectedOpts[i]):''};
    if(i>0){i--;showQ()}
  };
  showQ();
}
function submitQuiz(as,el){api('/quiz/submit',{method:'POST',data:{answers:as}}).then(function(r){
  el.remove();
  var pct=Math.round(r.score/r.total*100),emoji=pct===100?'🌟':pct>=80?'🎉':pct>=60?'👍':'💪',bg=pct===100?'linear-gradient(135deg,#c8a04a,#b87333)':pct>=80?'linear-gradient(135deg,#4a8f5a,#3d7349)':pct>=60?'linear-gradient(135deg,#1677ff,#0958d9)':'linear-gradient(135deg,#c0392b,#96281b)';
  var re=document.createElement('div');re.className='modal-mask';
  re.innerHTML='<div class="modal" style="max-width:400px;text-align:center;padding:0;overflow:hidden;border-radius:14px"><div style="background:'+bg+';padding:30px 20px"><div style="font-size:48px">'+emoji+'</div><div style="font-size:42px;font-weight:900;color:#fff;margin:8px 0">'+r.score+'<span style="font-size:20px">/'+r.total+'</span></div><div style="color:rgba(255,255,255,.8);font-size:14px">正确率 '+pct+'%</div></div><div style="padding:20px"><button class="btn btn-p" onclick="this.closest(\'.modal-mask\').remove();showLeaderboard()">🏆 查看排行榜</button><br><button class="btn btn-o btn-sm" style="margin-top:8px" onclick="this.closest(\'.modal-mask\').remove()">关闭</button></div></div>';
  re.onclick=function(e){if(e.target===re)re.remove()};document.body.appendChild(re)
})}
// 回顾已答题目
function showQuizReview(result){
  var pct=Math.round(result.score/result.total*100),emoji=pct===100?'🌟':pct>=80?'🎉':pct>=60?'👍':'💪',bg=pct===100?'linear-gradient(135deg,#c8a04a,#b87333)':pct>=80?'linear-gradient(135deg,#4a8f5a,#3d7349)':pct>=60?'linear-gradient(135deg,#1677ff,#0958d9)':'linear-gradient(135deg,#c0392b,#96281b)';
  var items='',labels=['A','B','C','D'];
  try{
    var pastAnswers=JSON.parse(result.answers||'[]');
    pastAnswers.forEach(function(a,j){
      var userLabel=a.user_answer||'未答';
      var correctLabel=a.correct_answer;
      var isCorrect=a.correct;
      items+='<div style="padding:12px;margin-bottom:8px;background:'+(isCorrect?'rgba(90,158,95,.06)':'rgba(224,85,85,.06)')+';border-radius:8px;border-left:3px solid '+(isCorrect?'var(--success)':'var(--danger)')+'">'+
        '<div style="font-weight:600;margin-bottom:6px">'+(j+1)+'. '+a.question+'</div>'+
        '<div>你的答案：<b style="color:'+(isCorrect?'var(--success)':'var(--danger)')+'">'+(a.user_answer||'未答')+(userLabel!=='未答'?' . '+labels[userLabel.charCodeAt(0)-65]:'')+'</b></div>'+
        (!isCorrect?'<div>正确答案：<b style="color:var(--success)">'+correctLabel+' . '+labels[correctLabel.charCodeAt(0)-65]+'</b></div>':'')+
        (a.explanation?'<div style="margin-top:4px;color:var(--text2);font-size:12px">💡 '+a.explanation+'</div>':'')+
      '</div>';
    });
  }catch(e){items='<div class="empty">暂无答题记录</div>'}
  var re=document.createElement('div');re.className='modal-mask';
  re.innerHTML='<div class="modal" style="max-width:520px;padding:0;overflow:hidden;border-radius:14px"><div style="background:'+bg+';padding:24px 20px;text-align:center"><div style="font-size:40px">'+emoji+'</div><div style="font-size:36px;font-weight:900;color:#fff;margin:4px 0">'+result.score+'<span style="font-size:18px">/'+result.total+'</span></div><div style="color:rgba(255,255,255,.8);font-size:13px">'+result.quiz_date+' · 正确率 '+pct+'% · 今日已完成</div></div><div style="max-height:50vh;overflow-y:auto;padding:16px 20px">'+items+'</div><div style="text-align:center;padding:0 20px 16px;display:flex;gap:10px;justify-content:center"><button class="btn btn-p btn-sm" onclick="this.closest(\'.modal-mask\').remove();showLeaderboard()">🏆 排行榜</button><button class="btn btn-o btn-sm" onclick="this.closest(\'.modal-mask\').remove()">关闭</button></div></div>';
  re.onclick=function(e){if(e.target===re)re.remove()};document.body.appendChild(re)
}
function showLeaderboard(){api('/quiz/leaderboard').then(function(d){if(!d)return;var rows='';(d.leaderboard||[]).forEach(function(r,i){var medal=i===0?'🥇':i===1?'🥈':i===2?'🥉':'';var likedClass=r.liked_by_me?'liked':'';rows+='<tr><td>'+medal+' '+(i+1)+'</td><td>'+r.name+'</td><td>'+r.total_score+'分</td><td>'+r.days+'天</td><td><button class="btn btn-sm like-btn '+likedClass+'" onclick="toggleQuizLike('+r.user_id+',this)" title="'+(r.liked_by_me?'已点赞':'点赞')+'">👍 '+(r.likes||0)+'</button></td></tr>'});showModal('🏆 本月排行榜','<table><tr><th>排名</th><th>姓名</th><th>总分</th><th>天数</th><th>点赞</th></tr>'+rows+'</table>')})}
function toggleQuizLike(targetUserId,btn){var month=new Date().toISOString().slice(0,7);api('/quiz/like',{method:'POST',data:{target_user_id:targetUserId,month:month}}).then(function(r){if(r){var cnt=parseInt(btn.textContent.match(/\d+/)?.[0]||'0')||0;btn.textContent='👍 '+(r.liked?cnt+1:cnt-1);if(r.liked){btn.classList.add('liked');btn.title='已点赞'}else{btn.classList.remove('liked');btn.title='点赞'}}})}
