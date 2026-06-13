const fs = require('fs');
let h = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');

const init = '// ==================== 初始化 ====================';

const quizFuncs = `
function showQuiz() {
  api('/quiz/today').then(function(d) {
    if (!d) return;
    if (d.done) {
      alert('今日已完成测试！得分：' + d.result.score + '/' + d.result.total);
      showLeaderboard();
    } else {
      startQuiz(d.questions);
    }
  });
}

function startQuiz(qs) {
  var i = 0, answers = [], el = document.createElement('div');
  el.className = 'modal-mask';

  function showQ() {
    if (i >= qs.length) { submitQuiz(answers, el); return; }
    var q = qs[i], opts = '';
    try {
      JSON.parse(q.options).forEach(function(o, j) {
        opts += '<label style=\"display:block;padding:10px;margin:6px 0;background:var(--surface2);border:1px solid var(--border);border-radius:6px;cursor:pointer\"><input type=\"radio\" name=\"q\" value=\"' + String.fromCharCode(65 + j) + '\" /> ' + o + '</label>';
      });
    } catch (e) {}
    el.innerHTML = '<div class=\"modal\" style=\"max-width:500px\"><h3>每日一测 (' + (i + 1) + '/' + qs.length + ')</h3><div class=\"form-group\"><label>' + q.question + '</label><small style=\"color:var(--text2)\">' + q.category + '</small></div>' + opts + '<div style=\"margin-top:12px;text-align:right\"><button class=\"btn btn-p btn-sm\" onclick=\"nextQ()\">' + (i < qs.length - 1 ? '下一题' : '提交') + '</button></div></div>';
    el.onclick = function(e) { if (e.target === el) el.remove(); };
    document.body.appendChild(el);
  }

  window.nextQ = function() {
    var r = el.querySelector('input[name=q]:checked');
    answers.push({ question_id: qs[i].id, user_answer: r ? r.value : '' });
    i++;
    showQ();
  };
  showQ();
}

function submitQuiz(as, el) {
  api('/quiz/submit', { method: 'POST', data: { answers: as } }).then(function(r) {
    el.remove();
    alert('得分：' + r.score + '/' + r.total);
    showLeaderboard();
  });
}

function showLeaderboard() {
  api('/quiz/leaderboard').then(function(d) {
    if (!d) return;
    var rows = '';
    (d.leaderboard || []).forEach(function(r, i) {
      var medal = i === 0 ? '🥇' : i === 1 ? '🥈' : i === 2 ? '🥉' : '';
      rows += '<tr><td>' + medal + ' ' + (i + 1) + '</td><td>' + r.name + '</td><td>' + r.total_score + '分</td><td>' + r.days + '天</td><td>👍' + (r.likes || 0) + '</td></tr>';
    });
    showModal('🏆 本月排行榜', '<table><tr><th>排名</th><th>姓名</th><th>总分</th><th>天数</th><th>点赞</th></tr>' + rows + '</table>');
  });
}
`;

h = h.replace(init, quizFuncs + '\n' + init);
fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', h, 'utf8');
console.log('Quiz functions added correctly');
