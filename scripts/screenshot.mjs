/**
 * Screenshot script for Alfred's Gooi
 *
 * Usage:
 *   node scripts/screenshot.mjs [pages...]
 *
 * Examples:
 *   node scripts/screenshot.mjs                        # screenshots all default pages
 *   node scripts/screenshot.mjs manage my_stats shop   # specific pages by key
 *   node scripts/screenshot.mjs --url /subscriptions/new --name subs_new
 *
 * Config via env vars:
 *   BASE_URL   (default: http://localhost:3000)
 *   EMAIL      (default: read from .screenshot-config)
 *   PASSWORD   (default: read from .screenshot-config)
 *   WIDTH      (default: 390 — iPhone 14 Pro)
 *   HEIGHT     (default: 844)
 */

import puppeteer from 'puppeteer'
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const ROOT = path.join(__dirname, '..')
const OUT_DIR = path.join(__dirname, 'screenshots')

// ── Config ────────────────────────────────────────────────────────────────────

const BASE_URL = process.env.BASE_URL || 'http://localhost:3000'
const WIDTH    = parseInt(process.env.WIDTH  || '390')
const HEIGHT   = parseInt(process.env.HEIGHT || '844')

// Load credentials from .screenshot-config (gitignored)
let email, password
const configPath = path.join(ROOT, '.screenshot-config')
if (fs.existsSync(configPath)) {
  const lines = fs.readFileSync(configPath, 'utf8').trim().split('\n')
  for (const line of lines) {
    const [key, val] = line.split('=').map(s => s.trim())
    if (key === 'EMAIL')    email    = val
    if (key === 'PASSWORD') password = val
  }
}
email    = process.env.EMAIL    || email
password = process.env.PASSWORD || password

// ── Pages to screenshot ───────────────────────────────────────────────────────

const PAGES = {
  home:          { url: '/',                    auth: false },
  login:         { url: '/users/sign_in',       auth: false },
  manage:        { url: '/manage',              auth: true  },
  my_stats:      { url: '/my_stats',            auth: true  },
  shop:          { url: '/shop',                auth: true  },
  subscriptions: { url: '/my_subscriptions',    auth: true  },
  account:       { url: '/account',             auth: true  },
  referrals:     { url: '/referrals',           auth: true  },
  collections:   { url: '/collections_history', auth: true  },
}

// ── Helpers ───────────────────────────────────────────────────────────────────

async function login(page) {
  if (!email || !password) {
    console.error('No credentials. Create .screenshot-config with EMAIL= and PASSWORD= lines.')
    process.exit(1)
  }
  await page.goto(`${BASE_URL}/users/sign_in`, { waitUntil: 'networkidle0' })
  await page.type('#user_email',    email)
  await page.type('#user_password', password)
  await Promise.all([
    page.waitForNavigation({ waitUntil: 'networkidle0' }),
    page.click('input[type="submit"], button[type="submit"]'),
  ])
  console.log(`  ✓ Logged in as ${email}`)
}

async function shot(page, key, url, outDir) {
  const fullUrl = `${BASE_URL}${url}`
  console.log(`  → ${key}: ${fullUrl}`)
  await page.goto(fullUrl, { waitUntil: 'networkidle0' })
  // wait a beat for any JS animations
  await new Promise(r => setTimeout(r, 400))
  const file = path.join(outDir, `${key}.png`)
  // fullPage can crash on very long pages — cap at 16000px
  const bodyHeight = await page.evaluate(() => document.body.scrollHeight)
  await page.screenshot({ path: file, fullPage: bodyHeight < 16000 })
  console.log(`     saved: scripts/screenshots/${path.basename(outDir)}/${key}.png`)
}

// ── Main ──────────────────────────────────────────────────────────────────────

const args = process.argv.slice(2)

// Support --url /path --name key for one-off shots
let adhocUrl, adhocName
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--url')  adhocUrl  = args[i + 1]
  if (args[i] === '--name') adhocName = args[i + 1]
}

// Which page keys to capture
let keys
if (adhocUrl) {
  keys = []
} else {
  const requested = args.filter(a => !a.startsWith('--'))
  keys = requested.length ? requested : Object.keys(PAGES)
}

// Timestamped output folder
const ts = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19)
const outDir = path.join(OUT_DIR, ts)
fs.mkdirSync(outDir, { recursive: true })

const browser = await puppeteer.launch({
  headless: true,
  args: ['--no-sandbox', '--disable-setuid-sandbox'],
})
const page = await browser.newPage()
await page.setViewport({ width: WIDTH, height: HEIGHT, deviceScaleFactor: 2 })

let loggedIn = false

try {
  // Handle one-off --url shot
  if (adhocUrl) {
    const needsAuth = !adhocUrl.startsWith('/users') && adhocUrl !== '/'
    if (needsAuth && !loggedIn) {
      await login(page)
      loggedIn = true
    }
    await shot(page, adhocName || 'custom', adhocUrl, outDir)
  }

  for (const key of keys) {
    const def = PAGES[key]
    if (!def) {
      console.warn(`  ⚠ Unknown page key: ${key}`)
      continue
    }
    if (def.auth && !loggedIn) {
      await login(page)
      loggedIn = true
    }
    await shot(page, key, def.url, outDir)
  }

  console.log(`\nDone. Screenshots in scripts/screenshots/${ts}/`)
} finally {
  await browser.close()
}
