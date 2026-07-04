// cloudfunctions/coze_proxy/index.js
// Coze API 代理云函数 - 保护API Key不在前端暴露

const https = require('https')

const COZE_API_TOKEN = process.env.COZE_API_TOKEN || 'sat_LvCuUkueRmeZlNEJFdSBf1qXCu61fPi32jkbpTWKpktSUkTVY6oH16QKqYLQNIfY'

function callCoze(botId, query, conversationId) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      bot_id: botId,
      user_id: 'miniprogram_wm001',
      stream: false,
      auto_save_history: true,
      additional_messages: [{ role: 'user', content: query, content_type: 'text' }]
    })
    const path = conversationId ? `/v1/chat?conversation_id=${conversationId}` : '/v1/chat'
    const options = {
      hostname: 'api.coze.cn', port: 443, path, method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${COZE_API_TOKEN}`,
        'Content-Length': Buffer.byteLength(payload)
      }
    }
    const req = https.request(options, (res) => {
      let data = ''
      res.on('data', (chunk) => { data += chunk })
      res.on('end', () => {
        try {
          const json = JSON.parse(data)
          if (json.code === 0 && json.data) {
            resolve({ chatId: json.data.id, conversationId: json.data.conversation_id })
          } else { reject(new Error(json.msg || 'Coze API调用失败')) }
        } catch (e) { reject(new Error('解析Coze响应失败: ' + e.message)) }
      })
    })
    req.on('error', (e) => reject(e))
    req.setTimeout(30000, () => { req.destroy(); reject(new Error('请求超时')) })
    req.write(payload)
    req.end()
  })
}

function pollChatResult(chatId, conversationId) {
  return new Promise((resolve, reject) => {
    let attempts = 0
    const maxAttempts = 30
    const poll = () => {
      attempts++
      if (attempts > maxAttempts) { reject(new Error('等待AI回复超时')); return }
      const options = {
        hostname: 'api.coze.cn', port: 443,
        path: `/v1/chat/retrieve?chat_id=${chatId}&conversation_id=${conversationId}`,
        method: 'GET',
        headers: { 'Authorization': `Bearer ${COZE_API_TOKEN}` }
      }
      const req = https.request(options, (res) => {
        let data = ''
        res.on('data', (chunk) => { data += chunk })
        res.on('end', () => {
          try {
            const json = JSON.parse(data)
            if (json.code === 0 && json.data) {
              if (json.data.status === 'completed') {
                fetchMessages(chatId, conversationId).then(resolve).catch(reject)
              } else if (json.data.status === 'failed') { reject(new Error('AI处理失败')) }
              else { setTimeout(poll, 1000) }
            } else { reject(new Error(json.msg || '查询状态失败')) }
          } catch (e) { reject(new Error('解析状态响应失败')) }
        })
      })
      req.on('error', (e) => reject(e))
      req.setTimeout(10000, () => { req.destroy(); reject(new Error('查询超时')) })
      req.end()
    }
    setTimeout(poll, 1000)
  })
}

function fetchMessages(chatId, conversationId) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'api.coze.cn', port: 443,
      path: `/v1/chat/message/list?chat_id=${chatId}&conversation_id=${conversationId}`,
      method: 'GET',
      headers: { 'Authorization': `Bearer ${COZE_API_TOKEN}` }
    }
    const req = https.request(options, (res) => {
      let data = ''
      res.on('data', (chunk) => { data += chunk })
      res.on('end', () => {
        try {
          const json = JSON.parse(data)
          if (json.code === 0 && json.data) {
            const assistantMsg = json.data.find(m => m.role === 'assistant' && m.type === 'answer')
            resolve({ answer: assistantMsg ? assistantMsg.content : '收到', conversationId })
          } else { reject(new Error(json.msg || '获取消息失败')) }
        } catch (e) { reject(new Error('解析消息失败')) }
      })
    })
    req.on('error', (e) => reject(e))
    req.setTimeout(10000, () => { req.destroy(); reject(new Error('获取消息超时')) })
    req.end()
  })
}

exports.main = async (event, context) => {
  const { bot_id, query, conversation_id } = event
  if (!bot_id || !query) { return { code: -1, message: '缺少必要参数: bot_id, query' } }
  try {
    const { chatId, conversationId } = await callCoze(bot_id, query, conversation_id)
    const result = await pollChatResult(chatId, conversationId)
    return { code: 0, answer: result.answer, conversation_id: result.conversationId }
  } catch (err) {
    console.error('coze_proxy error:', err)
    return { code: -1, message: err.message || '服务异常' }
  }
}
