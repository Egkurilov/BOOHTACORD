export function requests(page, channelId) {
  let current = null
  let lastActivity = 0
  const active = new Map(), watched = new Map()
  function kind(request) {
    if (request.method() !== 'GET') return null
    const path = new URL(request.url()).pathname
    return path === '/api/v1/channels' ? 'topology' : path === '/api/v1/channels/'+channelId+'/messages' ? 'history' : null
  }
  function finish(request) {
    const value = watched.get(request)
    if (value) { active.set(value, active.get(value)-1); watched.delete(request); lastActivity = Date.now() }
  }
  page.on('request', request => {
    const value = kind(request)
    if (!value || !current) return
    watched.set(request, value); active.set(value, (active.get(value) ?? 0)+1)
    lastActivity = Date.now()
    current[value]++
    current.max_parallel = Math.max(current.max_parallel, active.get(value))
  })
  page.on('requestfinished', finish); page.on('requestfailed', finish)
  return { start() { current = { topology: 0, history: 0, max_parallel: 0 }; lastActivity = Date.now() },
    quiet: () => watched.size === 0 && Date.now()-lastActivity >= 500,
    stop() { const result = current; current = null; return result } }
}
