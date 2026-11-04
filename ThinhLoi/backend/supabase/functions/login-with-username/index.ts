import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const genericMessage = 'Tên đăng nhập hoặc mật khẩu không đúng.'
const json = (body: Record<string, unknown>, status = 200) => new Response(
  JSON.stringify(body),
  { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
)

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ message: 'Method not allowed.' }, 405)

  try {
    const { username: rawUsername, password } = await request.json()
    const username = String(rawUsername ?? '').trim().toLowerCase()
    if (!/^[a-z0-9_]{3,30}$/.test(username) || typeof password !== 'string' || password.length < 8) {
      return json({ message: genericMessage }, 401)
    }

    const url = Deno.env.get('SUPABASE_URL')!
    const secretKey = Deno.env.get('SUPABASE_SECRET_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const publishableKey = Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ?? Deno.env.get('SUPABASE_ANON_KEY')!
    const admin = createClient(url, secretKey, { auth: { persistSession: false } })

    const forwarded = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unknown'
    const digest = await crypto.subtle.digest(
      'SHA-256',
      new TextEncoder().encode(`${forwarded}:${username}`),
    )
    const fingerprint = Array.from(new Uint8Array(digest)).map((value) => value.toString(16).padStart(2, '0')).join('')
    const { data: allowed, error: rateError } = await admin.rpc(
      'consume_auth_login_attempt',
      { p_fingerprint: fingerprint },
    )
    if (rateError || allowed !== true) return json({ message: 'Vui lòng thử lại sau.' }, 429)

    const { data: profile } = await admin
      .from('profiles')
      .select('id,is_active,role')
      .ilike('username', username)
      .maybeSingle()
    if (!profile?.is_active || !profile.role) {
      await new Promise((resolve) => setTimeout(resolve, 300))
      return json({ message: genericMessage }, 401)
    }

    const { data: userResult } = await admin.auth.admin.getUserById(profile.id)
    const identifier = userResult.user?.email
    if (!identifier) return json({ message: genericMessage }, 401)

    const authClient = createClient(url, publishableKey, { auth: { persistSession: false } })
    const { data, error } = await authClient.auth.signInWithPassword({ email: identifier, password })
    if (error || !data.session) return json({ message: genericMessage }, 401)

    return json({
      access_token: data.session.access_token,
      refresh_token: data.session.refresh_token,
      expires_in: data.session.expires_in,
    })
  } catch {
    return json({ message: genericMessage }, 401)
  }
})
