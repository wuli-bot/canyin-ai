// Supabase配置
const SUPABASE_URL = "https://brnpknbqxdrqxkylqbty.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_V1P_qESwEP4c1T18pu6iRg_prLPNaik";
const SUPABASE_ENABLED = true;

// Token验证函数
async function validateToken(token) {
  if (!SUPABASE_ENABLED) {
    return { valid: false, error: "Supabase not enabled" };
  }
  
  try {
    const response = await fetch(`${SUPABASE_URL}/rest/v1/access_tokens?token=eq.${encodeURIComponent(token)}&select=*`, {
      headers: {
        'apikey': SUPABASE_ANON_KEY,
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        'Content-Type': 'application/json'
      }
    });
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const data = await response.json();
    
    if (!data || data.length === 0) {
      return { valid: false, error: "Token not found" };
    }
    
    const tokenData = data[0];
    const now = new Date();
    const expiresAt = new Date(tokenData.expire_at);
    
    if (expiresAt < now) {
      return { valid: false, error: "Token expired" };
    }
    
    return {
      valid: true,
      accountName: tokenData.account_name,
      expiresAt: tokenData.expire_at
    };
  } catch (error) {
    return { valid: false, error: error.message };
  }
}

// 页面加载时自动验证
document.addEventListener('DOMContentLoaded', async () => {
  const urlParams = new URLSearchParams(window.location.search);
  const token = urlParams.get('token');
  
  if (!token) {
    showError("缺少通行码参数");
    return;
  }
  
  try {
    const result = await validateToken(token);
    
    if (result.valid) {
      // 验证成功，跳转到dashboard
      localStorage.setItem('access_token', token);
      localStorage.setItem('account_name', result.accountName);
      window.location.href = 'dashboard.html';
    } else {
      showError(`通行码验证失败：${result.error}`);
    }
  } catch (error) {
    showError(`验证过程出错：${error.message}`);
  }
});

function showError(message) {
  const errorDiv = document.getElementById('error-message');
  if (errorDiv) {
    errorDiv.textContent = message;
    errorDiv.style.display = 'block';
  }
}
