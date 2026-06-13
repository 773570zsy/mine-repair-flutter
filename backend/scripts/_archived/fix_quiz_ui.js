const fs = require('fs');
let h = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');

const oldStart = h.indexOf('function startQuiz(qs)');
const oldEnd = h.indexOf('\nfunction showQuiz', oldStart);
if (oldEnd < 0) {
  // Search for next function after showLeaderboard
  const tmp = h.indexOf('function showLeaderboard');
  const tmpEnd = h.indexOf('\nfunction', tmp + 50);
  if (tmpEnd > tmp) h = h.substring(0, tmpEnd + 1) + h.substring(tmpEnd + 1);
}
// Actually let me find the right boundaries
let fnEnd = h.indexOf('\n\nfunction', oldStart + 100);
if (fnEnd < oldStart) fnEnd = h.indexOf('\n// ==', oldStart + 100);

// Add CSS for quiz
const styleIdx = h.indexOf('</style>');
const quizCSS = `
.quiz-modal{max-width:560px;padding:0;overflow:hidden;background:var(--surface);border-radius:14px}
.quiz-progress-bar{width:100%;height:4px;background:var(--surface2)}
.quiz-progress-fill{height:100%;background:linear-gradient(to right,var(--gold),var(--copper));transition:width .3s ease}
.quiz-body{padding:24px}
.quiz-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:16px}
.quiz-question{font-size:16px;font-weight:600;color:var(--text);line-height:1.6;margin-bottom:20px}
.quiz-options{display:flex;flex-direction:column;gap:10px}
.quiz-opt{padding:14px 16px;background:var(--surface2);border:2px solid var(--border);border-radius:10px;cursor:pointer;display:flex;align-items:center;gap:12px;transition:all .2s;font-size:14px;color:var(--text)}
.quiz-opt:hover{border-color:var(--gold);background:rgba(200,160,74,.06)}
.quiz-selected{border-color:var(--gold)!important;background:rgba(200,160,74,.12)!important;box-shadow:0 0 0 1px var(--gold)}
.q-opt-letter{width:28px;height:28px;border-radius:50%;background:var(--border);display:flex;align-items:center;justify-content:center;font-weight:700;font-size:13px;flex-shrink:0}
.quiz-selected .q-opt-letter{background:var(--gold);color:#1a1d23}
.quiz-footer{text-align:right;margin-top:20px}
.quiz-btn{padding:12px 32px;font-size:15px;border-radius:8px}
.quiz-result-top{text-align:center;padding:30px 20px}
`;

h = h.substring(0, styleIdx) + quizCSS + h.substring(styleIdx);

// Now replace the quiz functions
const fnStart = h.indexOf('function startQuiz(qs)');
let fnEnd2 = h.indexOf('\nfunction showQuiz', fnStart);
if (fnEnd2 < 0) fnEnd2 = h.indexOf('\n\n//', fnStart + 800);

const newFns = `
function startQuiz(qs) {
  var i = 0, answers = [], el = document.createElement('div'), selected = -1;
  el.className = 'modal-mask';

  function showQ() {
    if (i >= qs.length) { submitQuiz(answers, el); return; }
    var q = qs[i], opts = '', labels = ['A','B','C','D'];
    var catIcon = ({'安全操作':'🔧','安全红线':'🚫','公司制度':'📋','十大禁令':'⛔','道路交通':'🚛','驾驶员管理':'👤','高原知识':'🏔','发动机理论':'⚙','电气系统':'⚡','液压系统':'💧','变速箱':'🔗','底盘':'🛞','轮胎':'⚫','故障判断':'🔍','日常保养':'🛢','工程机械':'🏗','矿山安全':'⛏','安全基础':'📖','四受控':'🔄','八大危险作业':'⚠'})[q.category] || '📝';
    try {
      JSON.parse(q.options).forEach(function(o, j) {
        opts += '<div class=\"quiz-opt\" id=\"opt'+j+'\" onclick=\"window.selOpt('+j+')\"><span class=\"q-opt-letter\">'+labels[j]+'</span> '+o+'</div>';
      });
    } catch (e) {}
    var barWidth = ((i+1)/qs.length*100).toFixed(0);
    el.innerHTML = '<div class=\"modal quiz-modal\">'+
      '<div class=\"quiz-progress-bar\"><div class=\"quiz-progress-fill\" style=\"width:'+barWidth+'%\"></div></div>'+
      '<div class=\"quiz-body\"><div class=\"quiz-header\"><span class=\"tag t-progress\" style=\"font-size:11px\">'+catIcon+' '+q.category+'</span><span style=\"color:var(--text2);font-size:12px\">'+(i+1)+'/'+qs.length+'</span></div>'+
      '<div class=\"quiz-question\">'+q.question+'</div>'+
      '<div class=\"quiz-options\">'+opts+'</div>'+
      '<div class=\"quiz-footer\"><button class=\"btn btn-p quiz-btn\" onclick=\"window.nextQ()\">'+(i<qs.length-1?'下一题 ▶':'✓ 提交')+'</button></div></div></div>';
    el.onclick = function(e) { if (e.target === el) el.remove(); };
    document.body.appendChild(el);
    selected = -1;
  }

  window.selOpt = function(j) {
    selected = j;
    document.querySelectorAll('.quiz-opt').forEach(function(o) { o.classList.remove('quiz-selected'); });
    var opt = document.getElementById('opt'+j);
    if (opt) opt.classList.add('quiz-selected');
  };

  window.nextQ = function() {
    var val = selected >= 0 ? String.fromCharCode(65+selected) : '';
    answers.push({ question_id: qs[i].id, user_answer: val });
    i++;
    showQ();
  };
  showQ();
}

function submitQuiz(as, el) {
  api('/quiz/submit', { method: 'POST', data: { answers: as } }).then(function(r) {
    el.remove();
    var pct = Math.round(r.score/r.total*100);
    var emoji = pct===100?'🌟':pct>=80?'🎉':pct>=60?'👍':'💪';
    var bg = pct===100?'linear-gradient(135deg,#c8a04a,#b87333)':pct>=80?'linear-gradient(135deg,#4a8f5a,#3d7349)':pct>=60?'linear-gradient(135deg,#1677ff,#0958d9)':'linear-gradient(135deg,#c0392b,#96281b)';
    var resultEl = document.createElement('div'); resultEl.className = 'modal-mask';
    resultEl.innerHTML = '<div class=\"modal\" style=\"max-width:400px;text-align:center;padding:0;overflow:hidden;border-radius:14px;background:var(--surface)\"><div style=\"background:'+bg+';padding:30px 20px\"><div style=\"font-size:48px\">'+emoji+'</div><div style=\"font-size:42px;font-weight:900;color:#fff;margin:8px 0\">'+r.score+'<span style=\"font-size:20px\">/'+r.total+'</span></div><div style=\"color:rgba(255,255,255,.8);font-size:14px\">正确率 '+pct+'%</div></div><div style=\"padding:20px\"><button class=\"btn btn-p\" onclick=\"this.closest(\\'.modal-mask\\').remove();showLeaderboard()\">🏆 查看排行榜</button><br><button class=\"btn btn-o btn-sm\" style=\"margin-top:8px\" onclick=\"this.closest(\\'.modal-mask\\').remove()\">关闭</button></div></div>';
    resultEl.onclick = function(e) { if (e.target === resultEl) resultEl.remove(); };
    document.body.appendChild(resultEl);
  });
}

function showLeaderboard() {
  api('/quiz/leaderboard').then(function(d) {
    if (!d) return;
    var rows = '';
    (d.leaderboard || []).forEach(function(r, i) {
      var medal = i === 0 ? '🥇' : i === 1 ? '🥈' : i === 2 ? '🥉' : '';
      rows += '<tr><td>'+medal+' '+(i+1)+'</td><td>'+r.name+'</td><td>'+r.total_score+'分</td><td>'+r.days+'天</td><td>👍'+(r.likes||0)+'</td></tr>';
    });
    showModal('🏆 本月排行榜', '<table><tr><th>排名</th><th>姓名</th><th>总分</th><th>天数</th><th>点赞</th></tr>'+rows+'</table>');
  });
}
`;

if (fnStart > 0 && fnEnd2 > fnStart) {
  h = h.substring(0, fnStart) + newFns + h.substring(fnEnd2);
}

fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', h, 'utf8');
console.log('Quiz UI updated');
