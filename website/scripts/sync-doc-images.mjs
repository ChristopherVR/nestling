// Pages that include ../docs/*.md resolve their relative image paths from website/guides/,
// so copy docs/images there before dev/build. The copy is gitignored; docs/images is the source.
import { cpSync, rmSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

const from = fileURLToPath(new URL('../../docs/images', import.meta.url))
const to = fileURLToPath(new URL('../guides/images', import.meta.url))
rmSync(to, { recursive: true, force: true })
cpSync(from, to, { recursive: true })
