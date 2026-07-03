/**
 * 通用语音输入组件 v2
 * 聊天框：切换键盘/语音模式，语音模式"按住说话松开发送"
 * 表单输入：输入框旁注入麦克风按钮
 */
(function() {
  'use strict';

  var SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!SR) {
    console.log('[voice-input] 浏览器不支持语音识别，需Chrome或Safari');
    return;
  }

  var curRec = null;

  // ========== 样式 ==========
  var style = document.createElement('style');
  style.textContent = `
    /* 切换按钮 */
    .vi-toggle {
      width: 36px; height: 36px; border-radius: 50%;
      border: none; background: rgba(128,128,128,0.15);
      color: #888; cursor: pointer; flex-shrink: 0;
      display: flex; align-items: center; justify-content: center;
      transition: all 0.2s; font-size: 18px;
    }
    .vi-toggle:active { transform: scale(0.9); }
    .vi-toggle.active { background: rgba(79,140,255,0.2); color: #4f8cff; }

    /* 按住说话按钮 */
    .vi-hold-btn {
      flex: 1; height: 40px; border-radius: 20px;
      border: none; background: rgba(128,128,128,0.15);
      color: #666; font-size: 15px; cursor: pointer;
      transition: all 0.15s; user-select: none;
      -webkit-user-select: none; touch-action: none;
      display: flex; align-items: center; justify-content: center;
    }
    .vi-hold-btn.recording {
      background: #f44336; color: #fff;
      animation: vi-pulse 1s ease-in-out infinite;
    }
    .vi-hold-btn.cancelled {
      background: #666; color: #999;
    }
    @keyframes vi-pulse {
      0%,100% { box-shadow: 0 0 0 0 rgba(244,67,54,0.4); }
      50% { box-shadow: 0 0 0 10px rgba(244,67,54,0); }
    }

    /* 表单输入的麦克风 */
    .vi-mic {
      position: absolute; right: 8px; top: 50%;
      transform: translateY(-50%);
      width: 28px; height: 28px; border-radius: 50%;
      border: none; background: rgba(79,140,255,0.15);
      color: #4f8cff; cursor: pointer;
      display: flex; align-items: center; justify-content: center;
      flex-shrink: 0; z-index: 5; transition: all 0.2s;
    }
    .vi-mic:active { transform: translateY(-50%) scale(0.9); }
    .vi-mic.recording { background: #f44336; color: #fff; animation: vi-pulse 1s infinite; }
    .vi-mic svg, .vi-toggle svg, .vi-hold-btn svg { width: 18px; height: 18px; fill: currentColor; }

    .vi-toast {
      position: fixed; top: 50%; left: 50%;
      transform: translate(-50%,-50%);
      background: rgba(0,0,0,0.8); color: #fff;
      padding: 12px 24px; border-radius: 8px;
      font-size: 14px; z-index: 99999;
      pointer-events: none; opacity: 0;
      transition: opacity 0.3s;
    }
    .vi-toast.show { opacity: 1; }
  `;
  document.head.appendChild(style);

  // SVG图标
  var ICON_MIC = '<svg viewBox="0 0 24 24"><path d="M12 14c1.66 0 3-1.34 3-3V5c0-1.66-1.34-3-3-3S9 3.34 9 5v6c0 1.66 1.34 3 3 3zm5-3c0 2.76-2.24 5-5 5s-5-2.24-5-5H5c0 3.53 2.61 6.43 6 6.92V21h2v-3.08c3.39-.49 6-3.39 6-6.92h-2z"/></svg>';
  var ICON_KB = '<svg viewBox="0 0 24 24"><path d="M20 5H4c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm-9 3h2v2h-2V8zm0 3h2v2h-2v-2zM8 8h2v2H8V8zm0 3h2v2H8v-2zm-1 2H5v-2h2v2zm0-3H5V8h2v2zm9 7H8v-2h8v2zm0-4h-2v-2h2v2zm0-3h-2V8h2v2zm3 3h-2v-2h2v2zm0-3h-2V8h2v2z"/></svg>';

  // Toast
  function toast(msg) {
    var t = document.createElement('div');
    t.className = 'vi-toast';
    t.textContent = msg;
    document.body.appendChild(t);
    setTimeout(function() { t.classList.add('show'); }, 10);
    setTimeout(function() { t.classList.remove('show'); }, 2000);
    setTimeout(function() { t.remove(); }, 2400);
  }

  // 停止当前录音
  function stopCur() {
    if (curRec) { try { curRec.stop(); } catch(e){} curRec = null; }
    document.querySelectorAll('.vi-hold-btn.recording, .vi-mic.recording').forEach(function(b) {
      b.classList.remove('recording');
      if (b.classList.contains('vi-hold-btn')) b.textContent = '按住说话';
    });
  }

  // 创建识别器
  function createRec(onResult, onEnd) {
    var r = new SR();
    r.lang = 'zh-CN';
    r.continuous = true;
    r.interimResults = true;
    var finalT = '';
    r.onresult = function(e) {
      var interim = '';
      for (var i = e.resultIndex; i < e.results.length; i++) {
        if (e.results[i].isFinal) finalT += e.results[i][0].transcript;
        else interim += e.results[i][0].transcript;
      }
      onResult(finalT + interim, finalT, interim);
    };
    r.onerror = function(e) {
      if (e.error === 'not-allowed') toast('请允许浏览器使用麦克风');
      onEnd();
    };
    r.onend = function() { onEnd(); };
    return r;
  }

  // ========== 模式1：聊天框（切换键盘/按住说话）==========
  function setupChatBar(textarea, sendBtn) {
    var wrap = textarea.parentElement;
    var parentStyle = getComputedStyle(wrap);
    if (parentStyle.position === 'static') wrap.style.position = 'relative';

    // 创建切换按钮
    var toggle = document.createElement('button');
    toggle.className = 'vi-toggle';
    toggle.type = 'button';
    toggle.innerHTML = ICON_MIC;
    toggle.title = '切换语音输入';

    // 创建按住说话按钮
    var holdBtn = document.createElement('button');
    holdBtn.className = 'vi-hold-btn';
    holdBtn.type = 'button';
    holdBtn.textContent = '按住说话';
    holdBtn.style.display = 'none';

    // 插入到wrap最前面
    wrap.insertBefore(toggle, wrap.firstChild);
    wrap.appendChild(holdBtn);

    var isVoiceMode = false;

    // 切换模式
    toggle.addEventListener('click', function(e) {
      e.preventDefault();
      e.stopPropagation();
      isVoiceMode = !isVoiceMode;
      if (isVoiceMode) {
        toggle.innerHTML = ICON_KB;
        toggle.title = '切换键盘输入';
        toggle.classList.add('active');
        textarea.style.display = 'none';
        if (sendBtn) sendBtn.style.display = 'none';
        holdBtn.style.display = 'flex';
      } else {
        toggle.innerHTML = ICON_MIC;
        toggle.title = '切换语音输入';
        toggle.classList.remove('active');
        textarea.style.display = '';
        if (sendBtn) sendBtn.style.display = '';
        holdBtn.style.display = 'none';
        textarea.focus();
      }
    });

    // 按住说话逻辑
    var recText = '';
    var isRecording = false;
    var startY = 0;
    var isCancelled = false;

    function startHold(e) {
      e.preventDefault();
      e.stopPropagation();
      stopCur();

      recText = '';
      isCancelled = false;
      startY = e.touches ? e.touches[0].clientY : e.clientY;

      holdBtn.classList.add('recording');
      holdBtn.textContent = '松开发送 · 上滑取消';
      isRecording = true;

      curRec = createRec(
        function(text) { recText = text; },
        function() {
          holdBtn.classList.remove('recording');
          if (holdBtn.textContent.indexOf('松开') >= 0) {
            holdBtn.textContent = '按住说话';
          }
          isRecording = false;

          if (!isCancelled && recText.trim()) {
            // 填入textarea并发送
            textarea.value = recText.trim();
            textarea.dispatchEvent(new Event('input', { bubbles: true }));
            // 自动发送
            if (sendBtn) {
              sendBtn.click();
            } else {
              // 尝试调用页面的发送函数
              var enterEvent = new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true });
              textarea.dispatchEvent(enterEvent);
            }
          } else if (isCancelled) {
            toast('已取消');
          } else if (!recText.trim()) {
            toast('没有听到声音');
          }
          curRec = null;
        }
      );

      try { curRec.start(); } catch(err) {
        setTimeout(function() { try { curRec.start(); } catch(e){} }, 200);
      }
    }

    function moveHold(e) {
      if (!isRecording) return;
      var y = e.touches ? e.touches[0].clientY : e.clientY;
      var diff = startY - y;
      if (diff > 40) {
        // 上滑取消
        if (!isCancelled) {
          isCancelled = true;
          holdBtn.classList.remove('recording');
          holdBtn.classList.add('cancelled');
          holdBtn.textContent = '松开手指取消';
        }
      } else {
        if (isCancelled) {
          isCancelled = false;
          holdBtn.classList.remove('cancelled');
          holdBtn.classList.add('recording');
          holdBtn.textContent = '松开发送 · 上滑取消';
        }
      }
    }

    function endHold(e) {
      if (!isRecording) return;
      e.preventDefault();
      e.stopPropagation();
      isRecording = false;
      if (isCancelled) {
        if (curRec) { try { curRec.stop(); } catch(e){} curRec = null; }
        holdBtn.classList.remove('recording', 'cancelled');
        holdBtn.textContent = '按住说话';
      } else {
        if (curRec) { try { curRec.stop(); } catch(e){} }
        // onend回调会处理发送
        holdBtn.classList.remove('recording');
        holdBtn.textContent = '按住说话';
      }
    }

    // Touch事件
    holdBtn.addEventListener('touchstart', startHold, { passive: false });
    holdBtn.addEventListener('touchmove', moveHold, { passive: false });
    holdBtn.addEventListener('touchend', endHold, { passive: false });
    holdBtn.addEventListener('touchcancel', endHold, { passive: false });

    // Mouse事件
    holdBtn.addEventListener('mousedown', startHold);
    holdBtn.addEventListener('mousemove', moveHold);
    holdBtn.addEventListener('mouseup', endHold);
    holdBtn.addEventListener('mouseleave', function(e) {
      if (isRecording) endHold(e);
    });
  }

  // ========== 模式2：表单输入（麦克风按钮）==========
  function setupFormInput(input) {
    if (input.dataset.viDone) return;
    input.dataset.viDone = '1';

    var parent = input.parentElement;
    if (getComputedStyle(parent).position === 'static') parent.style.position = 'relative';

    input.style.paddingRight = '36px';

    var btn = document.createElement('button');
    btn.className = 'vi-mic';
    btn.type = 'button';
    btn.innerHTML = ICON_MIC;
    btn.title = '语音输入';

    var isRec = false;
    var recText = '';
    var baseText = '';

    btn.addEventListener('click', function(e) {
      e.preventDefault();
      e.stopPropagation();

      if (isRec || curRec) {
        stopCur();
        if (isRec) { isRec = false; return; }
      }

      baseText = input.value || '';
      recText = '';
      isRec = true;
      btn.classList.add('recording');

      curRec = createRec(
        function(text) {
          input.value = baseText + text;
          input.dispatchEvent(new Event('input', { bubbles: true }));
        },
        function() {
          isRec = false;
          btn.classList.remove('recording');
          curRec = null;
        }
      );

      try { curRec.start(); } catch(err) {
        setTimeout(function() { try { curRec.start(); } catch(e){} }, 200);
      }
    });

    parent.appendChild(btn);
  }

  // ========== 检测并初始化 ==========
  function init() {
    // 1. 检测聊天框（有textarea + send按钮的组合）
    var textareas = document.querySelectorAll('textarea');

    textareas.forEach(function(ta) {
      if (ta.dataset.viSkip) return;

      // 查找兄弟元素中的发送按钮
      var sibling = ta.nextElementSibling;
      var sendBtn = null;
      while (sibling) {
        if (sibling.tagName === 'BUTTON' &&
            (sibling.className.indexOf('send') >= 0 ||
             sibling.className.indexOf('send-btn') >= 0 ||
             (sibling.onclick && sibling.onclick.toString().indexOf('send') >= 0) ||
             sibling.textContent.trim() === '↑' ||
             sibling.textContent.trim() === '发送')) {
          sendBtn = sibling;
          break;
        }
        sibling = sibling.nextElementSibling;
      }

      // 如果有发送按钮，用聊天模式
      if (sendBtn) {
        ta.dataset.viChat = '1';
        setupChatBar(ta, sendBtn);
      } else {
        // 检查是否在聊天上下文中（父元素class含chat）
        var p = ta.parentElement;
        var isChat = false;
        while (p && p !== document.body) {
          if (p.className && (p.className.indexOf('chat') >= 0 || p.className.indexOf('message') >= 0)) {
            isChat = true;
            break;
          }
          p = p.parentElement;
        }
        if (isChat) {
          ta.dataset.viChat = '1';
          setupChatBar(ta, null);
        } else {
          setupFormInput(ta);
        }
      }
    });

    // 2. 检测文本输入框
    var inputs = document.querySelectorAll('input[type="text"], input[type="search"], input:not([type])');
    inputs.forEach(function(inp) {
      if (inp.dataset.viDone || inp.dataset.viSkip) return;
      setupFormInput(inp);
    });

    console.log('[voice-input] 初始化完成，聊天框: ' +
      document.querySelectorAll('[data-vi-chat]').length + ', 表单输入: ' +
      document.querySelectorAll('[data-vi-done]').length);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() { setTimeout(init, 200); });
  } else {
    setTimeout(init, 200);
  }

  // 监听动态添加的元素
  var mo = new MutationObserver(function(muts) {
    var scan = false;
    muts.forEach(function(m) {
      for (var i = 0; i < m.addedNodes.length; i++) {
        var n = m.addedNodes[i];
        if (n.nodeType === 1 && (n.tagName === 'TEXTAREA' || n.tagName === 'INPUT' ||
            (n.querySelector && n.querySelector('textarea, input')))) {
          scan = true; break;
        }
      }
    });
    if (scan) {
      clearTimeout(window._viT);
      window._viT = setTimeout(init, 300);
    }
  });
  mo.observe(document.body, { childList: true, subtree: true });

  console.log('[voice-input] 语音输入组件v2已加载');
})();
