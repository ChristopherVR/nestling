/**
 * Links used across the site. Change them here only.
 */
const repo = 'https://github.com/ChristopherVR/nestling'

export const site = {
  /** Public address of the deployed site (GitHub Pages project site). */
  url: 'https://christophervr.github.io/nestling/',
  repo,
  releases: `${repo}/releases`,
  latestRelease: `${repo}/releases/latest`,
  issues: `${repo}/issues`,
  play: 'https://play.google.com/store/apps/details?id=io.github.christophervr.nestling',
} as const
