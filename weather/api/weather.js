const BASE = 'https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/'
const PATHS = {
  ncst: 'getUltraSrtNcst',
  fcst: 'getUltraSrtFcst',
  vilage: 'getVilageFcst',
}

const pad = (n) => String(n).padStart(2, '0')
const ymd = (d) => `${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}`

function baseTime(kind) {
  const now = Date.now() + 9 * 3600 * 1000
  if (kind === 'ncst') {
    const d = new Date(now - 40 * 60000)
    return { date: ymd(d), time: pad(d.getUTCHours()) + '00' }
  }
  if (kind === 'fcst') {
    const d = new Date(now - 45 * 60000)
    return { date: ymd(d), time: pad(d.getUTCHours()) + '30' }
  }
  const d = new Date(now - 10 * 60000)
  const slot = [23, 20, 17, 14, 11, 8, 5, 2].find((s) => s <= d.getUTCHours())
  if (slot === undefined) return { date: ymd(new Date(d.getTime() - 24 * 3600000)), time: '2300' }
  return { date: ymd(d), time: pad(slot) + '00' }
}

function normalizeKey(raw) {
  const k = raw.trim()
  if (/%[0-9A-Fa-f]{2}/.test(k)) {
    try {
      return decodeURIComponent(k)
    } catch {
      return k
    }
  }
  return k
}

function send(res, status, body) {
  res.status(status).setHeader('Content-Type', 'application/json; charset=utf-8')
  res.send(JSON.stringify(body))
}

module.exports = async (req, res) => {
  const rawKey = process.env.KMA_API_KEY
  if (!rawKey) {
    return send(res, 500, { error: '서버에 KMA_API_KEY 환경변수가 등록되지 않았어요. Vercel에서 등록한 뒤 Redeploy 하세요.' })
  }

  const { kind, nx, ny } = req.query
  if (!PATHS[kind]) return send(res, 400, { error: 'kind 는 ncst, fcst, vilage 중 하나여야 해요.' })
  const x = Number(nx)
  const y = Number(ny)
  if (!Number.isInteger(x) || !Number.isInteger(y) || x < 1 || x > 149 || y < 1 || y > 253) {
    return send(res, 400, { error: '격자 좌표(nx 1~149, ny 1~253)가 올바르지 않아요.' })
  }

  const base = baseTime(kind)
  const params = new URLSearchParams({
    pageNo: '1',
    numOfRows: '1000',
    dataType: 'JSON',
    base_date: base.date,
    base_time: base.time,
    nx: String(x),
    ny: String(y),
  })
  const url = `${BASE}${PATHS[kind]}?serviceKey=${encodeURIComponent(normalizeKey(rawKey))}&${params}`

  let text
  let status
  try {
    const upstream = await fetch(url, { signal: AbortSignal.timeout(8000) })
    status = upstream.status
    text = await upstream.text()
  } catch (e) {
    return send(res, 504, { error: '기상청 서버에 연결하지 못했어요: ' + e.name })
  }

  let data
  try {
    data = JSON.parse(text)
  } catch {
    return send(res, 502, { error: `기상청이 JSON이 아닌 응답을 보냈어요 (HTTP ${status}).`, detail: text.slice(0, 300) })
  }

  res.setHeader('Cache-Control', 's-maxage=300, stale-while-revalidate=60')
  return send(res, 200, { base, data })
}
