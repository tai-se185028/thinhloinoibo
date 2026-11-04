import { execFileSync } from 'node:child_process'
import { stdin, stdout } from 'node:process'
import { createClient } from '@supabase/supabase-js'

const projectRef = process.argv[2]
const username = process.argv[3]?.trim().toLowerCase()
if (!projectRef || !/^[a-z0-9_]{3,30}$/.test(username ?? '')) {
  throw new Error('Usage: node scripts/bootstrap_employee.mjs <project-ref> <username>')
}

const password = await new Promise((resolve) => {
  stdout.write('Password: ')
  stdin.setEncoding('utf8')
  if (stdin.isTTY) stdin.setRawMode(true)
  stdin.resume()
  let value = ''
  const onData = (chunk) => {
    for (const character of chunk) {
      if (character === '\r' || character === '\n') {
        stdin.off('data', onData)
        if (stdin.isTTY) stdin.setRawMode(false)
        stdin.pause()
        stdout.write('\n')
        resolve(value)
        return
      }
      if (character === '\u0003') process.exit(130)
      if (character === '\u007f' || character === '\b') value = value.slice(0, -1)
      else value += character
    }
  }
  stdin.on('data', onData)
})
if (password.length < 8) throw new Error('Password must contain at least 8 characters.')

const rawKeys = execFileSync(
  process.platform === 'win32' ? 'cmd.exe' : 'npx',
  process.platform === 'win32'
    ? ['/d', '/s', '/c', 'npx', 'supabase', 'projects', 'api-keys', `--remote=${projectRef}`, '--reveal', '--output', 'json']
    : ['supabase', 'projects', 'api-keys', `--remote=${projectRef}`, '--reveal', '--output', 'json'],
  { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] },
)
const parsed = JSON.parse(rawKeys)
const keys = Array.isArray(parsed) ? parsed : parsed.api_keys ?? parsed.keys ?? []
const secret = keys.find((key) =>
  ['secret', 'service_role'].includes(String(key.type ?? key.name).toLowerCase()),
)?.api_key ?? keys.find((key) => String(key.api_key ?? '').startsWith('sb_secret_'))?.api_key
if (!secret) throw new Error('No project secret key was available to the current CLI account.')
const publishable = keys.find((key) =>
  ['publishable', 'anon'].includes(String(key.type ?? key.name).toLowerCase()),
)?.api_key ?? keys.find((key) => String(key.api_key ?? '').startsWith('sb_publishable_'))?.api_key
if (!publishable) throw new Error('No project publishable key was available.')

const client = createClient(`https://${projectRef}.supabase.co`, secret, {
  auth: { autoRefreshToken: false, persistSession: false },
})
const email = `${username}@packflow.internal`
const { data: usersResult, error: listError } = await client.auth.admin.listUsers({ perPage: 1000 })
if (listError) throw listError
let user = usersResult.users.find((item) => item.email === email)
if (user) {
  const { data, error } = await client.auth.admin.updateUserById(user.id, {
    password,
    email_confirm: true,
  })
  if (error) throw error
  user = data.user
} else {
  const { data, error } = await client.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { username },
  })
  if (error) throw error
  user = data.user
}

const { error: profileError } = await client.from('profiles').upsert({
  id: user.id,
  username,
  full_name: 'Thịnh Lợi Bao Bì',
  role: 'admin',
  is_active: true,
  updated_at: new Date().toISOString(),
})
if (profileError) throw profileError
const publicClient = createClient(`https://${projectRef}.supabase.co`, publishable, {
  auth: { autoRefreshToken: false, persistSession: false },
})
const { data: loginData, error: loginError } = await publicClient.functions.invoke('login-with-username', {
  body: { username, password },
})
if (loginError || !loginData?.refresh_token) {
  const response = loginError?.context
  const detail = response instanceof Response
    ? `${response.status} ${await response.text()}`
    : String(loginError?.message ?? 'missing session')
  throw new Error(`Account was created, but username sign-in verification failed: ${detail}`)
}
stdout.write(`Employee account ready: ${username}\n`)
