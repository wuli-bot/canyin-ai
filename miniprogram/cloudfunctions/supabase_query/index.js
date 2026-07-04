// cloudfunctions/supabase_query/index.js
// Supabase查询代理云函数

const https = require('https')

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://vovzgflfdwngfuqnxjc.supabase.co'
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZvdnpnZmxmZHduZ2Z1cW54amMiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTc4MTU5ODQ5NiwiZXhwIjoyMDk3MTc0NDk2fQ.p8e3LcWgBqWxQ3jYk7mN2vR4sT8uY6zA9bC1dE5fG3h'

function supabaseRequest(method, path, body) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null
    const url = new URL(SUPABASE_URL)
    const options = {
      hostname: url.hostname, port: 443, path: `/rest/v1${path}`, method,
      headers: {
        'apikey': SUPABASE_KEY,
        'Authorization': `Bearer ${SUPABASE_KEY}`,
        'Content-Type': 'application/json',
        'Prefer': method === 'POST' ? 'return=representation' : undefined
      }
    }
    if (payload) options.headers['Content-Length'] = Buffer.byteLength(payload)
    const req = https.request(options, (res) => {
      let data = ''
      res.on('data', (chunk) => { data += chunk })
      res.on('end', () => {
        try {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(data ? JSON.parse(data) : [])
          } else { reject(new Error(`Supabase错误 ${res.statusCode}: ${data}`)) }
        } catch (e) { reject(new Error('解析响应失败: ' + e.message)) }
      })
    })
    req.on('error', (e) => reject(e))
    req.setTimeout(15000, () => { req.destroy(); reject(new Error('请求超时')) })
    if (payload) req.write(payload)
    req.end()
  })
}

function buildQueryPath(table, filters, order, ascending, limit, offset) {
  let query = `/${table}?select=*`
  if (filters) {
    Object.entries(filters).forEach(([key, value]) => {
      if (key === 'start_date') query += `&date=gte.${value}`
      else if (key === 'end_date') query += `&date=lte.${value}`
      else query += `&${key}=eq.${value}`
    })
  }
  if (order) query += `&order=${order}${ascending === false ? '.desc' : '.asc'}`
  if (limit) query += `&limit=${limit}`
  if (offset) query += `&offset=${offset}`
  return query
}

exports.main = async (event, context) => {
  const { action, table, filters, order, ascending, limit, offset } = event
  if (!action || !table) return { code: -1, message: '缺少必要参数: action, table' }
  try {
    let result
    switch (action) {
      case 'select':
        result = await supabaseRequest('GET', buildQueryPath(table, filters, order, ascending, limit, offset))
        break
      case 'insert':
        result = await supabaseRequest('POST', `/${table}`, event.data || filters)
        break
      case 'update':
        let updatePath = `/${table}`
        if (event.data && event.data.id) updatePath += `?id=eq.${event.data.id}`
        else if (filters) {
          updatePath += '?'
          Object.entries(filters).forEach(([k, v]) => { updatePath += `${k}=eq.${v}&` })
          updatePath = updatePath.slice(0, -1)
        }
        result = await supabaseRequest('PATCH', updatePath, event.data)
        break
      case 'update_order_status': {
        const { order_id, new_status } = event.data || {}
        if (!order_id || !new_status) return { code: -1, message: '缺少 order_id 或 new_status' }
        result = await supabaseRequest('PATCH', `/${table}?id=eq.${order_id}`, { status: new_status })
        break
      }
      case 'count':
        result = await supabaseRequest('GET', buildQueryPath(table, filters, null, null, null, null) + '&select=count')
        break
      default: return { code: -1, message: `不支持的操作: ${action}` }
    }
    return { code: 0, data: result }
  } catch (err) {
    console.error('supabase_query error:', err)
    return { code: -1, message: err.message || '数据库查询失败' }
  }
}
