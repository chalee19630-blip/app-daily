import { createClient } from '@/lib/supabase/server'
import { NextResponse } from 'next/server'

/**
 * Validates a redirect path to prevent open redirect attacks.
 * Ensures the destination is a same-origin relative URL.
 * Only rejects path traversal (`..`) in the pathname portion,
 * allowing harmless `..` in query strings and fragments.
 */
function getSafeRedirect(redirectParam: string | null): string {
  if (!redirectParam) {
    return '/'
  }

  const trimmed = redirectParam.trim()
  if (trimmed.length === 0) {
    return '/'
  }

  // Reject backslashes (could bypass forward-slash checks)
  if (trimmed.includes('\\')) {
    return '/'
  }

  // Reject control characters (newlines, tabs, null bytes)
  if (/[\x00-\x1f\x7f]/.test(trimmed)) {
    return '/'
  }

  // Reject protocol-relative URLs (//evil.com)
  if (trimmed.startsWith('//')) {
    return '/'
  }

  // Must start with a single forward slash
  if (!trimmed.startsWith('/')) {
    return '/'
  }

  // Use URL parser with a fixed origin to validate same-origin destination
  try {
    const baseOrigin = 'http://localhost'
    const parsed = new URL(trimmed, baseOrigin)

    // Verify the origin matches (same-origin guarantee)
    if (parsed.origin !== baseOrigin) {
      return '/'
    }

    // Only reject path traversal in pathname, not in query/hash
    // This allows harmless `..` in query strings like ?foo=..bar
    if (parsed.pathname.includes('..')) {
      return '/'
    }

    // Return pathname + search + hash (preserves query strings and fragments)
    return parsed.pathname + parsed.search + parsed.hash
  } catch {
    return '/'
  }
}

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url)
  const code = searchParams.get('code')

  // Check cookie for redirect destination (set before OAuth since query params get lost)
  const cookieHeader = request.headers.get('cookie') || ''
  const oauthRedirectMatch = cookieHeader.match(/oauth_redirect=([^;]+)/)
  let cookieRedirect: string | null = null
  try {
    cookieRedirect = oauthRedirectMatch ? decodeURIComponent(oauthRedirectMatch[1]) : null
  } catch {
    // Malformed URI component - treat as null (safe default)
    cookieRedirect = null
  }
  const next = getSafeRedirect(cookieRedirect)

  if (code) {
    const supabase = await createClient()
    const { error } = await supabase.auth.exchangeCodeForSession(code)

    if (!error) {
      // Clear the oauth_redirect cookie after successful login
      const response = NextResponse.redirect(`${origin}${next}`)
      response.cookies.set('oauth_redirect', '', { maxAge: 0, path: '/' })
      return response
    }
  }

  // Return the user to an error page with instructions
  return NextResponse.redirect(`${origin}/login?error=auth_callback_error`)
}
