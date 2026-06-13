// ============================================================
// 📸 照片查看模块 - 全屏查看 + 下载保存 + 历史追溯
// 点击缩略图 → 直接全屏大图，支持左右滑动/下载
// ============================================================
(function() {
  'use strict';

  // ----- 下载图片到本地 -----
  function downloadImage(url) {
    // 从URL提取文件名，失败则用时间戳
    var filename = 'photo_' + Date.now() + '.jpg';
    var parts = url.split('/');
    var last = parts[parts.length - 1];
    if (last && last.length > 3) filename = last;
    // 去掉查询参数
    if (filename.indexOf('?') > 0) filename = filename.split('?')[0];

    // 方法：fetch → blob → 创建下载链接
    fetch(url)
      .then(function(r) { return r.blob(); })
      .then(function(blob) {
        var blobUrl = URL.createObjectURL(blob);
        var a = document.createElement('a');
        a.href = blobUrl;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(blobUrl);
      })
      .catch(function() {
        // 降级：直接打开（移动端可能触发保存）
        var a = document.createElement('a');
        a.href = url;
        a.download = filename;
        a.target = '_blank';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
      });
  }

  // ----- 大图查看器（点击直接全屏 + 下载按钮）-----
  window.showFaultPhotos = function(urls, startIndex) {
    if (!urls || !urls.length) return;
    startIndex = startIndex || 0;
    if (startIndex >= urls.length) startIndex = 0;

    // 全屏遮罩
    var ov = document.createElement('div');
    ov.className = 'full-photo-viewer';
    ov.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.94);z-index:99999;display:flex;flex-direction:column;align-items:center;justify-content:center;touch-action:manipulation';

    // ----- 顶部工具栏 -----
    var bar = document.createElement('div');
    bar.style.cssText = 'position:absolute;top:0;left:0;right:0;padding:10px 12px;display:flex;justify-content:space-between;align-items:center;z-index:10;background:linear-gradient(180deg,rgba(0,0,0,.7) 0%,transparent 100%)';

    var leftGroup = document.createElement('div');
    leftGroup.style.cssText = 'display:flex;align-items:center;gap:8px';

    var counter = document.createElement('span');
    counter.style.cssText = 'color:#fff;font-size:15px;font-weight:500;min-width:50px';

    var downloadBtn = document.createElement('button');
    downloadBtn.innerHTML = '⬇ 保存';
    downloadBtn.title = '保存到本地/相册';
    downloadBtn.style.cssText = 'background:rgba(200,160,74,.25);color:var(--gold-light,#e0c878);border:1px solid rgba(200,160,74,.4);padding:6px 14px;border-radius:16px;font-size:13px;cursor:pointer;font-weight:500';
    downloadBtn.onclick = function(e) { e.stopPropagation(); downloadImage(urls[currentIdx]); };

    var closeBtn = document.createElement('button');
    closeBtn.textContent = '✕';
    closeBtn.style.cssText = 'background:rgba(255,255,255,.1);color:#fff;border:none;width:36px;height:36px;border-radius:50%;font-size:18px;cursor:pointer;display:flex;align-items:center;justify-content:center';
    closeBtn.onclick = function() { ov.remove(); };

    leftGroup.appendChild(counter);
    leftGroup.appendChild(downloadBtn);
    bar.appendChild(leftGroup);
    bar.appendChild(closeBtn);

    // ----- 图片容器 -----
    var imgWrap = document.createElement('div');
    imgWrap.style.cssText = 'width:100%;height:100%;display:flex;align-items:center;justify-content:center;overflow:hidden';

    var img = document.createElement('img');
    img.style.cssText = 'max-width:98vw;max-height:85vh;object-fit:contain;transition:opacity .15s;user-select:none;-webkit-user-select:none';

    // ----- 左右箭头 -----
    var prevBtn = document.createElement('button');
    prevBtn.innerHTML = '‹';
    prevBtn.style.cssText = 'position:absolute;left:6px;top:50%;transform:translateY(-50%);background:rgba(255,255,255,.08);color:#fff;border:none;width:40px;height:40px;border-radius:50%;font-size:26px;cursor:pointer;display:none;z-index:10;line-height:40px;text-align:center';
    prevBtn.onclick = function(e) { e.stopPropagation(); navigate(-1); };

    var nextBtn = document.createElement('button');
    nextBtn.innerHTML = '›';
    nextBtn.style.cssText = 'position:absolute;right:6px;top:50%;transform:translateY(-50%);background:rgba(255,255,255,.08);color:#fff;border:none;width:40px;height:40px;border-radius:50%;font-size:26px;cursor:pointer;display:none;z-index:10;line-height:40px;text-align:center';
    nextBtn.onclick = function(e) { e.stopPropagation(); navigate(1); };

    // ----- 底部提示（多张时）-----
    var hint = document.createElement('div');
    hint.style.cssText = 'position:absolute;bottom:20px;left:0;right:0;text-align:center;color:rgba(255,255,255,.4);font-size:11px;pointer-events:none';
    hint.textContent = '← 左右滑动切换 · 点击图片关闭 →';

    var currentIdx = startIndex;

    function updateImage(idx) {
      currentIdx = idx;
      img.style.opacity = '0';
      setTimeout(function() {
        img.src = urls[idx];
        counter.textContent = (idx + 1) + ' / ' + urls.length;
        prevBtn.style.display = urls.length > 1 ? 'block' : 'none';
        nextBtn.style.display = urls.length > 1 ? 'block' : 'none';
        hint.style.display = urls.length > 1 ? 'block' : 'none';
      }, 80);
      setTimeout(function() { img.style.opacity = '1'; }, 120);
    }

    function navigate(dir) {
      var next = currentIdx + dir;
      if (next >= 0 && next < urls.length) updateImage(next);
    }

    // ----- 触摸滑动 -----
    var touchStartX = 0, touchStartY = 0;
    ov.addEventListener('touchstart', function(e) {
      if (e.touches.length === 1) { touchStartX = e.touches[0].clientX; touchStartY = e.touches[0].clientY; }
    }, { passive: true });
    ov.addEventListener('touchend', function(e) {
      var dx = (e.changedTouches[0]?.clientX || 0) - touchStartX;
      var dy = (e.changedTouches[0]?.clientY || 0) - touchStartY;
      if (Math.abs(dx) > 50 && Math.abs(dx) > Math.abs(dy)) {
        navigate(dx > 0 ? -1 : 1);
      }
    });

    // ----- 键盘 -----
    var keyHandler = function(e) {
      if (e.key === 'ArrowRight') navigate(1);
      else if (e.key === 'ArrowLeft') navigate(-1);
      else if (e.key === 'Escape') ov.remove();
    };
    document.addEventListener('keydown', keyHandler);
    ov._cleanup = function() { document.removeEventListener('keydown', keyHandler); };

    // ----- 点击图片/空白区域关闭，两侧翻页 -----
    img.onclick = function(e) {
      e.stopPropagation();
      var w = ov.clientWidth;
      if (e.clientX < w * 0.2 && urls.length > 1) { navigate(-1); return; }
      if (e.clientX > w * 0.8 && urls.length > 1) { navigate(1); return; }
      ov.remove();
    };
    ov.addEventListener('click', function(e) {
      if (e.target === ov || e.target === imgWrap) {
        ov.remove();
      }
    });

    // 关闭清理
    var origRemove = ov.remove;
    ov.remove = function() {
      if (ov._cleanup) ov._cleanup();
      origRemove.call(ov);
    };

    ov.appendChild(bar);
    ov.appendChild(imgWrap);
    ov.appendChild(prevBtn);
    ov.appendChild(nextBtn);
    ov.appendChild(hint);
    imgWrap.appendChild(img);
    document.body.appendChild(ov);

    updateImage(startIndex);
  };

  // ----- MutationObserver：自动给弹窗中的照片绑定全屏查看 -----
  var observer = new MutationObserver(function(mutations) {
    mutations.forEach(function(m) {
      m.addedNodes.forEach(function(node) {
        if (node.nodeType !== 1) return;
        if (!node.querySelector) return;

        // 执行内联 script 标签
        var scripts = node.querySelectorAll('script');
        scripts.forEach(function(s) {
          try { var fn = new Function(s.textContent); fn(); } catch(e) {}
          s.remove();
        });

        // 给所有上传照片缩略图绑定：点击直接全屏（跳过全屏查看器内的图片）
        node.querySelectorAll('img[src*="/uploads/"]').forEach(function(img) {
          if (img.closest('.full-photo-viewer')) return; // 跳过查看器内的大图
          if (!img._boundClick) {
            img._boundClick = true;
            img.style.cursor = 'pointer';
            img.onclick = function(e) {
              e.stopPropagation();
              var allImgs = [];
              var modal = img.closest('.modal,.modal-mask') || img.closest('[class*="photo"]') || img.parentElement;
              if (modal) {
                modal.querySelectorAll('img[src*="/uploads/"]').forEach(function(m) {
                  if (allImgs.indexOf(m.src) < 0) allImgs.push(m.src);
                });
              }
              if (!allImgs.length) allImgs = [img.src];
              var idx = allImgs.indexOf(img.src);
              window.showFaultPhotos(allImgs, idx >= 0 ? idx : 0);
            };
          }
        });
      });
    });
  });
  observer.observe(document.body, { childList: true, subtree: true });
  console.log('[photo_viewer] Ready — 全屏查看 + 下载保存');
})();
