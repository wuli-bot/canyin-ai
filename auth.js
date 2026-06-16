// Supabase配置
const SUPABASE_URL = "https://brnpknbqxdrqxkylqbty.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_V1P_qESwEP4c1T18pu6iRg_prLPNaik";
const SUPABASE_ENABLED = true;

// Token验证函数 - 零成本绑定版
async function validateToken(token) {
  if (!SUPABASE_ENABLED) {
    return { valid: false, error: "服务未启用" };
  }
  
  if (!token || typeof token !== 'string') {
    return { valid: false, error: "通行码格式错误" };
  }
  
  try {
    const response = await fetch(`${SUPABASE_URL}/rest/v1/access_tokens?token=eq.${encodeURIComponent(token.trim())}&select=*`, {
      headers: {
        'apikey': SUPABASE_ANON_KEY,
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        'Content-Type': 'application/json'
      }
    });
    
    if (!response.ok) {
      throw new Error(`服务异常，请稍后重试`);
    }
    
    const data = await response.json();
    
    if (!data || data.length === 0) {
      return { valid: false, error: "通行码不存在" };
    }
    
    const tokenData = data[0];
    const now = new Date();
    const expiresAt = new Date(tokenData.expire_at);
    
    // 检查是否过期
    if (expiresAt < now) {
      return { valid: false, error: "通行码已过期" };
    }
    
    // 检查使用次数是否用完（未绑定时）
    const maxUses = tokenData.max_uses || 1;
    const usedCount = tokenData.used_count || 0;
    if (!tokenData.bound_phone && usedCount >= maxUses) {
      return { valid: false, error: "此通行码已被使用" };
    }
    
    // 检查是否已绑定手机号
    const boundPhone = tokenData.bound_phone;
    if (boundPhone) {
      // 已绑定：检查当前浏览器是否匹配
      const storedPhone = localStorage.getItem('canyin_bound_phone');
      if (storedPhone && storedPhone.trim() === boundPhone.trim()) {
        // 匹配，允许访问
        return {
          valid: true,
          needBind: false,
          accountName: tokenData.account_name,
          expiresAt: tokenData.expire_at
        };
      } else {
        // 不匹配，拒绝访问
        return { valid: false, error: "此通行码已绑定其他手机号" };
      }
    }
    
    // 未绑定：返回needBind=true，让前端显示绑定弹窗
    return {
      valid: true,
      needBind: true,
      accountName: tokenData.account_name,
      expiresAt: tokenData.expire_at
    };
  } catch (error) {
    console.error('[auth] validateToken error:', error);
    return { valid: false, error: "网络异常，请检查网络后重试" };
  }
}

// 绑定手机号到Token
async function bindPhoneToToken(token, phone) {
  if (!SUPABASE_ENABLED) {
    return { success: false, error: "服务未启用" };
  }
  
  // 校验手机号格式
  const cleanPhone = phone.trim();
  if (!cleanPhone || !/^1[3-9]\d{9}$/.test(cleanPhone)) {
    return { success: false, error: "请输入正确的11位手机号" };
  }
  
  try {
    // 更新数据库：设置bound_phone和used_count
    const response = await fetch(`${SUPABASE_URL}/rest/v1/access_tokens?token=eq.${encodeURIComponent(token.trim())}`, {
      method: 'PATCH',
      headers: {
        'apikey': SUPABASE_ANON_KEY,
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal'
      },
      body: JSON.stringify({
        bound_phone: cleanPhone,
        used_count: 1
      })
    });
    
    if (!response.ok) {
      throw new Error('绑定失败，请稍后重试');
    }
    
    // 保存到localStorage
    localStorage.setItem('canyin_bound_phone', cleanPhone);
    localStorage.setItem('access_token', token.trim());
    
    return { success: true };
  } catch (error) {
    console.error('[auth] bindPhone error:', error);
    return { success: false, error: error.message || "绑定失败" };
  }
}

// 获取当前绑定的手机号
function getBoundPhone() {
  return localStorage.getItem('canyin_bound_phone');
}

// 显示绑定弹窗
function showBindModal(token, accountName) {
  const modal = document.getElementById('bindModal');
  if (modal) {
    modal.style.display = 'flex';
    // 设置账户名称
    const accountLabel = document.getElementById('bindAccountName');
    if (accountLabel) {
      accountLabel.textContent = accountName || '';
    }
    // 保存token到全局变量供绑定函数使用
    window.currentBindToken = token;
  }
}

// 处理绑定按钮点击
async function handleBind() {
  const phoneInput = document.getElementById('phoneInput');
  const errorDiv = document.getElementById('bindError');
  const btn = document.getElementById('bindBtn');
  
  if (!phoneInput || !errorDiv || !btn) return;
  
  const phone = phoneInput.value.trim();
  
  // 前端校验
  if (!phone) {
    errorDiv.textContent = '请输入手机号';
    errorDiv.style.display = 'block';
    return;
  }
  
  if (!/^1[3-9]\d{9}$/.test(phone)) {
    errorDiv.textContent = '请输入正确的11位手机号';
    errorDiv.style.display = 'block';
    return;
  }
  
  // 禁用按钮，防止重复点击
  btn.disabled = true;
  btn.textContent = '绑定中...';
  errorDiv.style.display = 'none';
  
  const token = window.currentBindToken;
  if (!token) {
    errorDiv.textContent = '通行码信息丢失，请刷新页面';
    errorDiv.style.display = 'block';
    btn.disabled = false;
    btn.textContent = '确认绑定';
    return;
  }
  
  const result = await bindPhoneToToken(token, phone);
  
  if (result.success) {
    // 绑定成功，跳转dashboard
    localStorage.setItem('account_name', document.getElementById('bindAccountName')?.textContent || '');
    window.location.href = 'dashboard.html';
  } else {
    // 绑定失败，显示错误
    errorDiv.textContent = result.error;
    errorDiv.style.display = 'block';
    btn.disabled = false;
    btn.textContent = '确认绑定';
  }
}

// 页面加载时自动验证
document.addEventListener('DOMContentLoaded', async () => {
  const urlParams = new URLSearchParams(window.location.search);
  const token = urlParams.get('token');
  
  if (!token) {
    // 不是通行码页面，跳过
    return;
  }
  
  try {
    const result = await validateToken(token);
    
    if (result.valid && !result.needBind) {
      // 已绑定且验证成功，跳转到dashboard
      localStorage.setItem('access_token', token);
      localStorage.setItem('account_name', result.accountName);
      window.location.href = 'dashboard.html';
    } else if (result.valid && result.needBind) {
      // 未绑定，显示绑定弹窗
      showBindModal(token, result.accountName);
    } else {
      // 验证失败，显示错误
      showError(result.error);
    }
  } catch (error) {
    console.error('[auth] DOMContentLoaded error:', error);
    showError('网络异常，请检查网络后重试');
  }
});

function showError(message) {
  const errorDiv = document.getElementById('error-message');
  if (errorDiv) {
    errorDiv.textContent = message;
    errorDiv.style.display = 'block';
  }
}
