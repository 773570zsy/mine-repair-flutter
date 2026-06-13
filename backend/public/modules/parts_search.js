// 配件搜索增强模块
// 为管理员配件管理和驾驶员配件领用添加搜索功能
// 支持：文字模糊搜索 + 拼音首字母搜索 + 历史快速复用
(function() {
  'use strict';

  // ===== 拼音首字母映射（常用汉字，含矿山/机械/车辆术语） =====
  var PY = {};
  (function(){
    var map = {
      'A':'阿啊哎安暗按昂袄','B':'把百败班板办半帮包保报抱暴爆北备背被本泵比笔必边编变便标表别冰兵丙饼并波玻剥播薄补不部布步',
      'C':'擦材采彩菜参餐藏操槽草测层叉插查差柴产长常厂场超车彻尘沉陈衬成承程池齿充冲出初除础储处触传串窗创吹垂春纯磁此次从粗促催脆存寸措错',
      'D':'达打大代带待单担弹淡当挡导到道得灯等低底地第点电垫吊调掉顶定定动斗都读堵度端短断堆对吨盾多',
      'E':'额恶恩而耳二','F':'发阀法翻凡反返范方防房放飞非废分粉风封否夫服浮福辅腐父付负附复副富',
      'G':'改盖干感刚钢高告格个各给根跟更工功供公固故关观管惯灌光广归规硅柜贵滚过',
      'H':'还海含焊航好号合和核黑很恒横红后厚呼忽护互花华滑化还环换黄簧灰回会混活火或货',
      'J':'机积基激及级极急集几计记技季继加夹家驾假价架尖间检减简见件建降交胶角脚叫较接节结截解介界金紧进近经晶精井景净静镜九久酒旧就局矩举巨具距聚卷决绝均',
      'K':'卡开看抗考靠科壳可克客空控口扣库跨块快矿亏扩','L':'拉来兰蓝缆劳老雷类冷离里理力历立利例连联练链良好量了料列裂临灵领另流六龙漏路铝率绿轮论罗螺落滤',
      'M':'马码埋买满慢毛矛铆煤每美门密面灭民名明命模摩磨末母木目','N':'内纳耐难脑能泥年碾念宁凝牛扭农弄暖诺',
      'O':'欧偶','P':'排盘判配喷膨批皮片偏漂频品平评瓶破','Q':'七期齐其起气汽器千前强墙切亲清情请庆球区曲驱取去全缺确群',
      'R':'燃让热人忍认任日容融柔入软润若弱','S':'三散扫色森沙刹筛山上烧少设社射伸深神审渗升生声省剩失施湿十石时识实使始士示世事势试视适收手首受输书疏输熟属数刷双水顺说丝司死四似松送速塑算随碎损缩所索锁',
      'T':'台太态弹碳探套特提题体天条调铁停通同统头透突图推退托拖脱','W':'外完晚万网往危微为围维尾未位温文稳问我污无五物误雾',
      'X':'西吸希析洗系细下先显线限相箱详响想向项消小校效协斜写泄新信星行形型性休修需许序续选学雪血循',
      'Y':'压牙烟延严研颜验扬阳氧样要冶野业叶液一医依仪移已以异易意因阴引印应硬用优由油游有又右淤于余与雨语预元员原圆缘远月运',
      'Z':'杂载在早造责增扎闸窄粘展占张障招照罩折者针真诊振整正证支知脂直值止纸指制质治中终重轴主助注驻柱专转装状追准资子自字总走阻组最左作坐座做'
    };
    for (var k in map) {
      if (!map.hasOwnProperty(k)) continue;
      var chars = map[k];
      for (var i = 0; i < chars.length; i++) {
        PY[chars[i]] = k.toLowerCase();
      }
    }
  })();

  function getPinyinInitials(str) {
    var result = '';
    for (var i = 0; i < str.length; i++) {
      var ch = str[i];
      result += PY[ch] || ch.toLowerCase();
    }
    return result;
  }

  // 搜索匹配：支持文字包含 + 拼音首字母
  function matchQuery(text, query) {
    if (!query) return true;
    var q = query.toLowerCase();
    var t = text.toLowerCase();
    if (t.indexOf(q) !== -1) return true;
    // 拼音首字母匹配
    var initials = getPinyinInitials(text);
    if (initials.indexOf(q) !== -1) return true;
    return false;
  }

  function escapeHtml(str) {
    return String(str).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
  }

  // ===== 管理员端：配件管理弹窗增强 =====
  function enhancePartsManagement() {
    var modals = document.querySelectorAll('.modal-mask');
    for (var i = 0; i < modals.length; i++) {
      var modal = modals[i];
      if (modal._partsSearchEnhanced) continue;

      var h3 = modal.querySelector('h3');
      if (!h3 || h3.textContent.indexOf('配件管理') === -1) continue;

      modal._partsSearchEnhanced = true;

      // 找到库存卡片中的table
      var tables = modal.querySelectorAll('table');
      var invTable = null, invCard = null;
      for (var j = 0; j < tables.length; j++) {
        var rows = tables[j].querySelectorAll('tr');
        if (rows.length > 0) {
          var th = rows[0].querySelectorAll('th');
          if (th.length >= 2 && th[0].textContent.trim() === '名称') {
            invTable = tables[j];
            invCard = invTable.closest('.card');
            break;
          }
        }
      }
      if (!invTable || !invCard) continue;

      // 保存原始行数据
      var allRows = [];
      var bodyRows = invTable.querySelectorAll('tbody tr, tr:not(:first-child)');
      // 重新获取：取所有非表头行
      var trs = invTable.querySelectorAll('tr');
      var headerRow = trs[0];
      for (var k = 1; k < trs.length; k++) {
        allRows.push({ el: trs[k], html: trs[k].outerHTML });
      }

      // 缓存原始数据
      invCard._partsAllRows = allRows;
      invCard._partsHeaderRow = headerRow;
      invCard._partsTable = invTable;

      // 注入搜索框
      var searchHtml = '<div class="form-group" style="margin-bottom:8px"><input id="partsSearchAdmin" placeholder="搜索配件（支持拼音首字母，如jylx=机油滤芯）" style="font-size:13px" /></div>';
      var cardTitle = invCard.querySelector('.card-title');
      if (cardTitle) {
        cardTitle.insertAdjacentHTML('afterend', searchHtml);
      } else {
        invTable.insertAdjacentHTML('beforebegin', searchHtml);
      }

      // 绑定搜索事件
      var searchInput = invCard.querySelector('#partsSearchAdmin');
      if (searchInput) {
        searchInput.addEventListener('input', function() {
          filterInventoryTable(invCard);
        });
      }

      // 注入删除按钮列
      injectDeleteButtons(invCard);
    }
  }

  function injectDeleteButtons(card) {
    var table = card._partsTable;
    var headerRow = card._partsHeaderRow;
    if (!table || !headerRow) return;

    // 加表头"操作"列
    if (!headerRow.querySelector('.parts-del-th')) {
      headerRow.insertAdjacentHTML('beforeend', '<th class="parts-del-th" style="width:50px">操作</th>');
    }

    // 遍历当前DOM中的行（非表头），加删除按钮
    var liveRows = table.querySelectorAll('tr');
    for (var i = 1; i < liveRows.length; i++) {
      var row = liveRows[i];
      if (row.querySelector('.parts-del-btn')) continue;
      // 跳过"未找到"提示行
      var tds = row.querySelectorAll('td');
      if (tds.length === 1 && tds[0].getAttribute('colspan')) continue;

      var tds = row.querySelectorAll('td');
      if (tds.length === 1 && tds[0].getAttribute('colspan')) continue;

      var partName = tds.length > 0 ? (tds[0].textContent || '').trim() : '';
      var partCode = tds.length > 1 ? (tds[1].textContent || '').trim() : '';

      // 用IIFE捕获当前值，避免闭包陷阱
      (function(pName, pCode) {
        var newTd = document.createElement('td');
        var delBtn = document.createElement('button');
        delBtn.className = 'btn btn-sm btn-d parts-del-btn';
        delBtn.textContent = '删';
        delBtn.style.cssText = 'padding:2px 8px;font-size:11px';
        delBtn.onclick = function(e) {
          e.stopPropagation();
          window._deletePartByName(pName, pCode);
        };
        newTd.appendChild(delBtn);
        row.appendChild(newTd);
      })(partName, partCode);
    }
  }

  // 全局删除函数
  window._deletePartByName = async function(name, code) {
    if (!confirm('确认删除配件 "' + name + '"？\n（如有领用记录则无法删除）')) return;
    try {
      // 先从当前DOM找到完整配件列表获取id
      var token = localStorage.getItem('mp_token');
      // 通过API查找
      var r = await fetch('/api/inspection/parts/search?q=' + encodeURIComponent(name), {
        headers: { 'Authorization': 'Bearer ' + (token || '') }
      });
      var d = await r.json();
      if (d.code !== 200 || !d.data || !d.data.length) {
        alert('未找到该配件');
        return;
      }
      // 找到匹配的配件
      var part = d.data.find(function(p) { return p.part_name === name && (p.part_code || '') === code; });
      if (!part) part = d.data[0];

      var r2 = await fetch('/api/inspection/parts/' + part.id, {
        method: 'DELETE',
        headers: { 'Authorization': 'Bearer ' + (token || '') }
      });
      var d2 = await r2.json();
      if (d2.code === 200) {
        alert('已删除');
        // 关闭弹窗并刷新
        var masks = document.querySelectorAll('.modal-mask');
        for (var i = 0; i < masks.length; i++) {
          if (masks[i].textContent.indexOf('配件管理') !== -1) {
            masks[i].remove();
            break;
          }
        }
        if (typeof showPartsManagement === 'function') showPartsManagement();
      } else {
        alert(d2.msg || '删除失败');
      }
    } catch(e) {
      alert('操作失败: ' + e.message);
    }
  };

  function filterInventoryTable(card) {
    var query = (card.querySelector('#partsSearchAdmin') || {}).value || '';
    var allRows = card._partsAllRows;
    var table = card._partsTable;
    if (!allRows || !table) return;

    // 移除现有的数据行
    var trs = table.querySelectorAll('tr');
    for (var i = 1; i < trs.length; i++) {
      trs[i].remove();
    }

    // 过滤并重新添加
    var visibleCount = 0;
    for (var j = 0; j < allRows.length; j++) {
      var row = allRows[j];
      var text = (row.el.textContent || '').trim();
      if (matchQuery(text, query)) {
        // 用 outerHTML 重建行
        var tbody = table.querySelector('tbody') || table;
        tbody.insertAdjacentHTML('beforeend', row.html);
        visibleCount++;
      }
    }

    // 显示无结果提示
    if (visibleCount === 0) {
      var tbody = table.querySelector('tbody') || table;
      var colspan = card._partsHeaderRow ? card._partsHeaderRow.querySelectorAll('th').length : 5;
      tbody.insertAdjacentHTML('beforeend', '<tr><td colspan="' + colspan + '" style="text-align:center;color:var(--text2);padding:16px">未找到匹配配件</td></tr>');
    }

    // 重新注入删除按钮
    injectDeleteButtons(card);
  }

  // ===== 驾驶员端：配件领用增强 =====
  function enhancePartsRequisition() {
    var modals = document.querySelectorAll('.modal-mask .modal');
    for (var i = 0; i < modals.length; i++) {
      var modalContent = modals[i];
      if (modalContent._reqSearchEnhanced) continue;

      // 判断是领用弹窗：有"配件"的label且内部有select#reqPartId
      var select = modalContent.querySelector('#reqPartId');
      if (!select) continue;

      modalContent._reqSearchEnhanced = true;

      // 解析所有select中的option获取配件数据
      var parts = [];
      var options = select.querySelectorAll('option');
      for (var j = 0; j < options.length; j++) {
        var opt = options[j];
        var text = opt.textContent || '';
        var match = text.match(/库存[:：](\d+)/);
        var stock = match ? parseInt(match[1]) : 0;
        parts.push({
          id: opt.value,
          label: text,
          name: text.replace(/\s*（库存.*$/, ''),
          stock: stock
        });
      }

      // 存储到弹窗
      modalContent._reqParts = parts;
      modalContent._reqSelect = select;

      // 替换select为搜索输入框+下拉列表
      var formGroup = select.closest('.form-group');
      if (!formGroup) return;

      var searchHtml = '<input id="reqPartSearch" placeholder="搜索配件（支持拼音首字母，如bx=保险丝）" autocomplete="off" style="font-size:13px" />' +
        '<div id="reqPartDropdown" style="max-height:180px;overflow:auto;border:1px solid var(--border);border-radius:6px;margin-top:4px;background:var(--bg);display:none"></div>' +
        '<div id="reqPartSelected" style="margin-top:4px;font-size:12px;color:var(--gold)"></div>';
      select.style.display = 'none';
      select.insertAdjacentHTML('afterend', searchHtml);

      // 如果有历史记录，添加"最近领用"快捷区
      var recent = getRecentParts();
      if (recent.length > 0) {
        var recentHtml = '<div style="margin-bottom:8px"><span style="font-size:11px;color:var(--text2)">最近领用：</span>' +
          recent.slice(0, 5).map(function(r) {
            return '<span style="display:inline-block;padding:2px 8px;margin:2px;background:var(--surface2);border-radius:12px;font-size:11px;cursor:pointer;border:1px solid var(--border)" onclick="window._selectRecentPart(\'' + escapeHtml(r.name) + '\',\'' + r.id + '\')">' + escapeHtml(r.name) + '</span>';
          }).join('') + '</div>';
        formGroup.querySelector('label').insertAdjacentHTML('afterend', recentHtml);
      }

      // 搜索输入事件
      var searchInput = modalContent.querySelector('#reqPartSearch');
      var dropdown = modalContent.querySelector('#reqPartDropdown');
      if (searchInput && dropdown) {
        searchInput.addEventListener('input', function() {
          filterPartsDropdown(modalContent);
        });
        searchInput.addEventListener('focus', function() {
          filterPartsDropdown(modalContent);
        });
        // 点击外部关闭下拉
        document.addEventListener('click', function(e) {
          if (!modalContent.contains(e.target)) {
            dropdown.style.display = 'none';
          }
        });
      }
    }
  }

  function filterPartsDropdown(modalContent) {
    var query = (modalContent.querySelector('#reqPartSearch') || {}).value || '';
    var dropdown = modalContent.querySelector('#reqPartDropdown');
    var parts = modalContent._reqParts;
    if (!dropdown || !parts) return;

    if (!query) {
      // 显示全部
      dropdown.innerHTML = parts.map(function(p) {
        return '<div style="padding:8px 12px;cursor:pointer;border-bottom:1px solid var(--border);font-size:13px" data-part-id="' + p.id + '" data-part-name="' + escapeHtml(p.name) + '" onmousedown="window._selectPart(\'' + escapeHtml(p.name) + '\',\'' + p.id + '\')" onmouseover="this.style.background=\'var(--surface2)\'" onmouseout="this.style.background=\'\'">' + escapeHtml(p.label) + '</div>';
      }).join('');
      dropdown.style.display = parts.length > 0 ? '' : 'none';
    } else {
      var filtered = parts.filter(function(p) { return matchQuery(p.name, query); });
      dropdown.innerHTML = filtered.length > 0 ? filtered.map(function(p) {
        return '<div style="padding:8px 12px;cursor:pointer;border-bottom:1px solid var(--border);font-size:13px" data-part-id="' + p.id + '" data-part-name="' + escapeHtml(p.name) + '" onmousedown="window._selectPart(\'' + escapeHtml(p.name) + '\',\'' + p.id + '\')" onmouseover="this.style.background=\'var(--surface2)\'" onmouseout="this.style.background=\'\'">' + escapeHtml(p.label) + '</div>';
      }).join('') : '<div style="padding:12px;color:var(--text2);font-size:12px;text-align:center">未找到，可先到配件管理添加</div>';
      dropdown.style.display = '';
    }
  }

  // 全局函数：选中配件
  window._selectPart = function(name, id) {
    // 找到当前活跃的领用弹窗
    var modals = document.querySelectorAll('.modal-mask .modal');
    for (var i = 0; i < modals.length; i++) {
      var m = modals[i];
      var select = m.querySelector('#reqPartId');
      var dropdown = m.querySelector('#reqPartDropdown');
      var searchInput = m.querySelector('#reqPartSearch');
      var selected = m.querySelector('#reqPartSelected');
      if (select && dropdown) {
        select.value = id;
        dropdown.style.display = 'none';
        if (searchInput) searchInput.value = name;
        if (selected) selected.textContent = '已选: ' + name;
        // 记录到历史
        addRecentPart(name, id);
        return;
      }
    }
  };

  window._selectRecentPart = function(name, id) {
    window._selectPart(name, id);
  };

  // ===== 历史记录(localStorage) =====
  function getRecentParts() {
    try {
      return JSON.parse(localStorage.getItem('_recent_parts') || '[]');
    } catch(e) { return []; }
  }

  function addRecentPart(name, id) {
    try {
      var list = getRecentParts();
      // 去重，移到最前
      list = list.filter(function(r) { return r.id !== id; });
      list.unshift({ name: name, id: id });
      if (list.length > 20) list = list.slice(0, 20);
      localStorage.setItem('_recent_parts', JSON.stringify(list));
    } catch(e) {}
  }

  // ===== MutationObserver: 监听弹窗 =====
  function startObserving() {
    var observer = new MutationObserver(function(mutations) {
      for (var i = 0; i < mutations.length; i++) {
        var mutation = mutations[i];
        if (mutation.addedNodes && mutation.addedNodes.length) {
          for (var j = 0; j < mutation.addedNodes.length; j++) {
            var node = mutation.addedNodes[j];
            if (node.nodeType === 1) {
              // 小延迟等DOM渲染完
              setTimeout(function() {
                enhancePartsManagement();
                enhancePartsRequisition();
              }, 100);
              return;
            }
          }
        }
      }
    });

    var target = document.body;
    if (target) {
      observer.observe(target, { childList: true, subtree: true });
    } else {
      setTimeout(startObserving, 200);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', startObserving);
  } else {
    startObserving();
  }
})();
