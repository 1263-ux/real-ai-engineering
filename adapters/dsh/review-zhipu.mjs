// review-zhipu.mjs — 独立检查（智谱白嫖档）
// 用法:
//   node review-zhipu.mjs <packet文件> [model]
//   echo "<packet内容>" | node review-zhipu.mjs - [model]
// 模型: glm-4.1-thinking（深审） / glm-4.5-air（快查，默认）
// 密钥: 环境变量 ZHIPU_API_KEY（不入库）
import fs from 'node:fs'
import https from 'node:https'

const key = process.env.ZHIPU_API_KEY
if (!key) { console.error('[review-zhipu] 缺 ZHIPU_API_KEY 环境变量'); process.exit(1) }

const packetArg = process.argv[2]
const model = process.argv[3] || 'glm-4.5-air'
let packet = ''
try {
  packet = packetArg && packetArg !== '-'
    ? fs.readFileSync(packetArg, 'utf8')
    : fs.readFileSync(0, 'utf8')
} catch (e) { console.error('[review-zhipu] 读取 packet 失败:', e.message); process.exit(1) }
if (!packet.trim()) { console.error('[review-zhipu] packet 为空'); process.exit(1) }

const system = '你是独立代码审查专家（fresh context，不认识实现者）。按 EXPERT_PACKET 要求输出 VERDICT：明确结论（通过/不通过/需修改）+ 关键发现（按严重度排序，指出具体行/文件/依据）+ 是否需要升级稀缺专家。不要客套。'
const body = JSON.stringify({
  model,
  messages: [
    { role: 'system', content: system },
    { role: 'user', content: packet },
  ],
  temperature: 0.3,
})

const req = https.request({
  host: 'open.bigmodel.cn', path: '/api/paas/v4/chat/completions', method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ' + key,
    'Content-Length': Buffer.byteLength(body),
  },
  timeout: 120000,
}, res => {
  let d = ''
  res.on('data', c => d += c)
  res.on('end', () => {
    if (res.statusCode !== 200) { console.error('[review-zhipu] HTTP ' + res.statusCode + ': ' + d.slice(0, 300)); process.exit(1) }
    try {
      const j = JSON.parse(d)
      const msg = j.choices?.[0]?.message
      console.log('== VERDICT（智谱 ' + model + '）==')
      console.log(msg?.content || '(无输出内容)')
      if (j.usage) console.log('== usage ==', JSON.stringify(j.usage))
    } catch (e) { console.error('[review-zhipu] 解析失败:', e.message); process.exit(1) }
  })
})
req.on('error', e => { console.error('[review-zhipu] ERR:', e.message); process.exit(1) })
req.on('timeout', () => { console.error('[review-zhipu] TIMEOUT'); req.destroy(); process.exit(1) })
req.write(body)
req.end()
