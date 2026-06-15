// auth.js - 餐饮AI店长 · 通用Token门禁
const CANYIN_AUTH = {
  SUPABASE_URL: 'https://xxxxx.supabase.co',
  SUPABASE_ANON_KEY: 'YOUR_ANON_KEY_HERE',
  TOKEN_EXPIRE_DAYS: 7,
  ENABLED: true,
};

let _supabaseClient = null;

function getSupabase() {
  if (!_supabaseClient && window.supabase) {
    _supabaseClient = window.supabase.createClient(
      CANYIN_AUTH.SUPABASE_URL,
      CANYIN_AUTH.SUPABASE_ANON_KEY
    );
  }
  return _supabaseClient;
}

function getToken() {
  return localStorage.getItem('canyin_token');
}

function setToken(token) {
  localStorage.setItem('canyin_token', token);
  localStorage.setItem('canyin_token_time', Date.now().toString());
}

function clearToken() {
  localStorage.removeItem('canyin_token');
  localStorage.removeItem('canyin_token_time');
}

function isTokenExpired() {
  const saved = localStorage.getItem('canyin_token_time');
  if (!saved) return true;
  const days = (Date.now() - parseInt(saved)) / (1000 * 60 * 60 * 24);
  return days > CANYIN_AUTH.TOKEN_EXPIRE_DAYS;
}

async function validateToken(token) {
  if (!token) return false;
  const supabase = getSupabase();
  if (!supabase) {
    console.warn('[auth] Supabase未就绪');
    return !CANYIN_AUTH.ENABLED;
  }

  const { data, error } = await supabase
    .from('profiles')
    .select('subscription_tier, subscription_expires_at')
    .eq('access_token', token)
    .single();

  if (error || !data) return false;

  if (data.subscription_tier !== 'free' && data.subscription_expires_at) {
    if (new Date(data.subscription_expires_at) < new Date()) return false;
  }
  return true;
}

async function requireAuth() {
  if (!CANYIN_AUTH.ENABLED) return true;

  const token = getToken();
  if (!token) { redirectToLogin(); return false; }
  if (isTokenExpired()) { clearToken(); redirectToLogin(); return false; }

  const valid = await validateToken(token);
  if (!valid) { clearToken(); redirectToLogin(); return false; }
  return true;
}

function redirectToLogin() {
  if (window.location.pathname.includes('access.html')) return;
  window.location.href = 'access.html';
}

function logout() {
  clearToken();
  window.location.href = 'access.html';
}
