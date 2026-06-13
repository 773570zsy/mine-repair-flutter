// ============================================================
// 📸 照片上传模块 - 完全独立，不修改 app.js
// 功能：拍照按钮注入 + 预览 + API拦截自动注入照片URL
// ============================================================
(function() {
  'use strict';

  // ----- 隐藏的文件选择器 -----
  var photoInput = document.createElement('input');
  photoInput.type = 'file';
  photoInput.accept = 'image/*';
  photoInput.multiple = true;
  photoInput.style.display = 'none';
  document.body.appendChild(photoInput);

  // ----- 全局照片存储（按表单类型分类）-----
  // 保持向后兼容：沿用 app.js 已引用的变量名
  window._rptPhotoUrls = window._rptPhotoUrls || [];   // 报修故障照片
  window._inspPhotoUrls = window._inspPhotoUrls || [];  // 早检照片
  window._inspPhotoUrls2 = window._inspPhotoUrls2 || [];// 晚检照片
  window._hzPhotoUrls = window._hzPhotoUrls || [];      // 隐患照片
  window._quoteDmgUrls = window._quoteDmgUrls || [];    // 损坏配件照片
  window._quoteNewUrls = window._quoteNewUrls || [];    // 新配件照片

  // 快速引用映射
  var photoStore = {
    repair: window._rptPhotoUrls,
    morning: window._inspPhotoUrls,
    evening: window._inspPhotoUrls2,
    hazard: window._hzPhotoUrls,
    quote_damage: window._quoteDmgUrls,
    quote_new: window._quoteNewUrls
  };

  // ----- 上传文件到服务器 -----
  async function uploadFiles(files) {
    var urls = [];
    for (var i = 0; i < files.length; i++) {
      var fd = new FormData();
      fd.append('file', files[i]);
      try {
        var r = await fetch('/api/upload/single', {
          method: 'POST',
          headers: { 'Authorization': 'Bearer ' + TOKEN },
          body: fd
        });
        var d = await r.json();
        if (d.code === 200) {
          urls.push(d.data.url);
        } else {
          alert('上传失败: ' + (d.msg || '未知错误'));
        }
      } catch(e) {
        alert('上传失败: 网络错误，请检查后端是否运行');
        console.error('Photo upload error:', e);
      }
    }
    if (urls.length > 0 && typeof toast === 'function') {
      toast('✓ 已上传 ' + urls.length + ' 张照片');
    }
    return urls;
  }

  // ----- 全局函数：选择照片 -----
  window.pickPhotos = function(callback) {
    photoInput.click();
    photoInput.onchange = async function() {
      if (!photoInput.files.length) return;
      var urls = await uploadFiles(photoInput.files);
      if (callback) callback(urls);
      photoInput.value = '';
    };
  };

  // ----- 缩略图预览 -----
  function showPreview(urls, container) {
    container.innerHTML = '';
    urls.forEach(function(url) {
      var img = document.createElement('img');
      img.src = url;
      img.style.cssText = 'width:60px;height:60px;object-fit:cover;border-radius:6px;margin:3px;border:1px solid var(--border);cursor:pointer';
      img.onclick = function() {
        // 点击放大查看
        var ov = document.createElement('div');
        ov.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.9);z-index:9999;display:flex;align-items:center;justify-content:center;cursor:pointer';
        var big = document.createElement('img');
        big.src = url;
        big.style.cssText = 'max-width:95vw;max-height:95vh;object-fit:contain';
        ov.appendChild(big);
        ov.onclick = function() { ov.remove(); };
        document.body.appendChild(ov);
      };
      container.appendChild(img);
    });
  }

  // ----- 在表单中注入拍照按钮+预览区 -----
  function injectPhotoButton(targetEl, storeKey, label) {
    if (!targetEl || !targetEl.parentNode) return;
    // 防止重复添加
    if (targetEl.parentNode.querySelector('.photo-upload-area')) return;

    var area = document.createElement('div');
    area.className = 'photo-upload-area';
    area.style.marginTop = '8px';

    var btn = document.createElement('button');
    btn.className = 'btn btn-o btn-sm';
    btn.textContent = label || '📷 拍照/上传';
    btn.type = 'button';

    var preview = document.createElement('div');
    preview.className = 'photo-preview';
    preview.style.cssText = 'display:flex;gap:4px;flex-wrap:wrap;margin-top:6px';

    // 初始化预览已有的照片
    var arr = photoStore[storeKey];
    if (arr && arr.length) {
      showPreview(arr, preview);
    }

    btn.onclick = function(e) {
      e.preventDefault();
      e.stopPropagation();
      window.pickPhotos(function(urls) {
        if (!photoStore[storeKey]) photoStore[storeKey] = [];
        Array.prototype.push.apply(photoStore[storeKey], urls);
        showPreview(photoStore[storeKey], preview);
      });
    };

    area.appendChild(btn);
    area.appendChild(preview);
    targetEl.parentNode.insertBefore(area, targetEl.nextSibling);
  }

  // ----- MutationObserver：检测弹窗表单并注入拍照按钮 -----
  var observer = new MutationObserver(function(mutations) {
    mutations.forEach(function(m) {
      m.addedNodes.forEach(function(node) {
        if (node.nodeType !== 1) return;
        // querySelector 可用在元素节点上
        if (!node.querySelector) return;

        // 报修表单（#rptDesc）
        var rptDesc = node.querySelector('#rptDesc');
        if (rptDesc) {
          injectPhotoButton(rptDesc, 'repair', '📷 故障照片');
        }

        // 早检表单（#inspNotes）
        var inspNotes = node.querySelector('#inspNotes');
        if (inspNotes) {
          injectPhotoButton(inspNotes, 'morning', '📷 检查照片');
        }

        // 晚检表单（#inspParking）
        var inspParking = node.querySelector('#inspParking');
        if (inspParking) {
          injectPhotoButton(inspParking, 'evening', '📷 检查照片');
        }

        // 隐患上报（#hzDesc）
        var hzDesc = node.querySelector('#hzDesc');
        if (hzDesc) {
          injectPhotoButton(hzDesc, 'hazard', '📷 隐患照片');
        }

        // 报价表单（#quoteDetail）- 损坏配件 + 新配件
        var quoteDetail = node.querySelector('#quoteDetail');
        if (quoteDetail && !quoteDetail.parentNode.querySelector('.quote-photo-section')) {
          var qp = quoteDetail.parentNode;
          var section = document.createElement('div');
          section.className = 'quote-photo-section';

          // 损坏配件
          var dmgLabel = document.createElement('label');
          dmgLabel.textContent = '损坏配件照片';
          dmgLabel.style.cssText = 'display:block;margin-top:10px;font-size:13px;color:var(--text2)';
          var dmgBtn = document.createElement('button');
          dmgBtn.className = 'btn btn-o btn-sm';
          dmgBtn.textContent = '📷 上传损坏配件';
          dmgBtn.type = 'button';
          var dmgPreview = document.createElement('div');
          dmgPreview.style.cssText = 'display:flex;gap:4px;flex-wrap:wrap;margin-bottom:6px';
          dmgBtn.onclick = function(e) {
            e.preventDefault();
            window.pickPhotos(function(urls) {
              Array.prototype.push.apply(window._quoteDmgUrls, urls);
              showPreview(window._quoteDmgUrls, dmgPreview);
            });
          };
          // 新配件
          var newLabel = document.createElement('label');
          newLabel.textContent = '新配件照片';
          newLabel.style.cssText = 'display:block;font-size:13px;color:var(--text2)';
          var newBtn = document.createElement('button');
          newBtn.className = 'btn btn-o btn-sm';
          newBtn.textContent = '📷 上传新配件';
          newBtn.type = 'button';
          var newPreview = document.createElement('div');
          newPreview.style.cssText = 'display:flex;gap:4px;flex-wrap:wrap;margin-bottom:6px';
          newBtn.onclick = function(e) {
            e.preventDefault();
            window.pickPhotos(function(urls) {
              Array.prototype.push.apply(window._quoteNewUrls, urls);
              showPreview(window._quoteNewUrls, newPreview);
            });
          };

          section.appendChild(dmgLabel);
          section.appendChild(dmgBtn);
          section.appendChild(dmgPreview);
          section.appendChild(newLabel);
          section.appendChild(newBtn);
          section.appendChild(newPreview);
          qp.appendChild(section);
        }
      });
    });
  });
  observer.observe(document.body, { childList: true, subtree: true });
  console.log('[photos] Observer ready - watching for forms');

  // ============================================================
  // API 拦截：自动将照片URL注入表单提交数据
  // app.js 中修理报修已引用 _rptPhotoUrls，无需拦截
  // 但点检和报价需要拦截注入
  // ============================================================
  setTimeout(function() {
    if (typeof api === 'function' && !api.__photoPatched) {
      var _origApi = api;
      window.api = async function(url, opts) {
        opts = opts || {};

        // 如果原请求没有 data（GET请求等），直接透传，不修改
        if (!opts.data) {
          return await _origApi(url, opts);
        }

        // 克隆 data 以注入照片URL
        var data = JSON.parse(JSON.stringify(opts.data));

        // 早检：注入 photos 字段
        if (url === '/inspection/morning-check' && window._inspPhotoUrls && window._inspPhotoUrls.length) {
          data.photos = window._inspPhotoUrls.slice();
        }

        // 晚检：注入 photos 字段
        if (url === '/inspection/evening-check' && window._inspPhotoUrls2 && window._inspPhotoUrls2.length) {
          data.photos = window._inspPhotoUrls2.slice();
        }

        // 修理厂报价：注入 damage_photos 和 new_photos
        if (url.indexOf('/repair/submit-quote/') === 0) {
          if (window._quoteDmgUrls && window._quoteDmgUrls.length) {
            data.damage_photos = window._quoteDmgUrls.slice();
          }
          if (window._quoteNewUrls && window._quoteNewUrls.length) {
            data.new_photos = window._quoteNewUrls.slice();
          }
        }

        // 隐患上报：注入 photos_before
        if (url === '/hazards/report' && window._hzPhotoUrls && window._hzPhotoUrls.length) {
          data.photos_before = window._hzPhotoUrls.slice();
        }

        // 隐患整改完成：注入 photos_after
        if (url.indexOf('/hazards/rectify/') === 0 && window._hzPhotoUrls && window._hzPhotoUrls.length) {
          data.photos_after = window._hzPhotoUrls.slice();
        }

        var result = await _origApi(url, Object.assign({}, opts, { data: data }));

        // 成功后清空对应的照片存储
        if (result) {
          if (url === '/inspection/morning-check') { window._inspPhotoUrls = []; }
          if (url === '/inspection/evening-check') { window._inspPhotoUrls2 = []; }
          if (url.indexOf('/repair/submit-quote/') === 0) {
            window._quoteDmgUrls = [];
            window._quoteNewUrls = [];
          }
          if (url === '/hazards/report') { window._hzPhotoUrls = []; }
          if (url.indexOf('/hazards/rectify/') === 0) { window._hzPhotoUrls = []; }
        }

        return result;
      };
      window.api.__photoPatched = true;
      console.log('[photos] API wrapper installed');
    }
  }, 200);
})();
