"""Builds the Nestling website into website/_site/.

    pip install -r website/requirements.txt
    python website/build.py
    python -m http.server -d website/_site

Every page is Markdown rendered into layout.html. Most pages live in
website/pages/; the camera guide, privacy policy and disclaimer are read from
docs/local-camera.md, PRIVACY.md and DISCLAIMER.md so they have one source.
Each page is written as <path>/index.html, so /privacy works on GitHub Pages.
All links are relative, so the site works under /nestling/ and locally.
"""

import html
import pathlib
import re
import shutil

import markdown

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent
OUT = HERE / '_site'
REPO = 'https://github.com/ChristopherVR/nestling'

GUIDES = [
    ('guides/logging', 'Logging'),
    ('guides/habits', 'Habits & reminders'),
    ('guides/routines', 'Routines'),
    ('guides/growth', 'Growth'),
    ('guides/history', 'History & charts'),
    ('guides/sharing', 'Sharing with a partner'),
    ('guides/pump', 'Momcozy pump'),
    ('guides/camera', 'Nanit camera'),
    ('guides/backups', 'Backups'),
]

# Page path -> Markdown source. Paths without a source file in pages/ come
# from the repository root.
SOURCES = {
    '': HERE / 'pages' / 'index.md',
    'get-started': HERE / 'pages' / 'get-started.md',
    'privacy': ROOT / 'PRIVACY.md',
    'disclaimer': ROOT / 'DISCLAIMER.md',
    'guides/camera': ROOT / 'docs' / 'local-camera.md',
}
for path, _ in GUIDES:
    SOURCES.setdefault(path, HERE / 'pages' / f'{path}.md')

# Front matter for the pages whose source has none.
META = {
    'privacy': {'description': 'What Nestling does with your information: your log stays on your own devices.'},
    'disclaimer': {'description': 'Nestling is provided as is, at your own risk, and is not a medical device.'},
    'guides/camera': {
        'title': 'Nanit camera',
        'description': 'Watch and listen to your Nanit camera on your home Wi-Fi, without a Nanit account.',
        'source': f'{REPO}/blob/main/docs/local-camera.md',
    },
}

STATIC = ['style.css', 'site.js', 'favicon.png', 'apple-touch-icon.png', 'images']


def front_matter(text: str) -> tuple[dict, str]:
    meta = {}
    match = re.match(r'---\n(.*?)\n---\n', text, re.S)
    if match:
        for line in match[1].splitlines():
            key, _, value = line.partition(':')
            meta[key.strip()] = value.strip()
        text = text[match.end():]
    return meta, text


def guide_nav(current: str, root: str) -> str:
    items = ''.join(
        f'<li><a href="{root}{path}/"'
        + (' aria-current="page"' if path == current else '')
        + f'>{html.escape(label)}</a></li>'
        for path, label in [('get-started', 'Get started'), *GUIDES]
    )
    return f'<ul>{items}</ul>'


def pager(current: str, root: str) -> str:
    paths = [p for p, _ in GUIDES]
    i = paths.index(current)
    parts = []
    if i > 0:
        p, label = GUIDES[i - 1]
        parts.append(f'<a class="prev" href="{root}{p}/"><span>Previous</span>{html.escape(label)}</a>')
    if i < len(GUIDES) - 1:
        p, label = GUIDES[i + 1]
        parts.append(f'<a class="next" href="{root}{p}/"><span>Next</span>{html.escape(label)}</a>')
    return f'<nav class="pager" aria-label="More guides">{"".join(parts)}</nav>'


def render(path: str, layout: str) -> str:
    meta, text = front_matter(SOURCES[path].read_text(encoding='utf-8').replace('\r\n', '\n'))
    meta = {**META.get(path, {}), **meta}
    heading = re.match(r'# (.+)\n+', text)
    if heading:
        meta.setdefault('title', heading[1])
        text = text[heading.end():]
    title = meta['title']
    depth = path.count('/') + 1 if path else 0
    root = '../' * depth

    body = markdown.markdown(
        text,
        extensions=['extra', 'admonition', 'sane_lists', 'toc'],
        extension_configs={'toc': {'permalink': False}},
    )
    body = body.replace('{{root}}', root)
    # Bare URLs (as in the policies) become links.
    body = re.sub(r'(?<![">=])(https://[^\s<]+[^\s<.,;:)])', r'<a href="\1">\1</a>', body)

    guide = path.startswith('guides/')
    intro = f'<p class="lede">{html.escape(meta["lede"])}</p>' if meta.get('lede') else ''
    source = meta.get('source')
    if source:
        intro += f'<p class="from-source">This guide also lives on <a href="{source}">GitHub</a>.</p>'
    article = (
        f'<article class="prose"><h1>{html.escape(title)}</h1>{intro}{body}'
        + (pager(path, root) if guide else '')
        + '</article>'
    )
    # Guides and the home page share the guide list: a sidebar on wide
    # screens, a menu at the top on phones.
    if guide or path == '':
        summary = f'Guides: {html.escape(title)}' if guide else 'Guides'
        main = (
            '<div class="with-side">'
            f'<nav class="side" id="guides" aria-label="Guides"><p class="side-title">Guides</p>{guide_nav(path, root)}</nav>'
            f'<details class="guide-menu"><summary>{summary}</summary>{guide_nav(path, root)}</details>'
            f'{article}</div>'
        )
    else:
        main = article

    full_title = title if 'Nestling' in title else f'{title} · Nestling'
    section = 'guides' if guide else path
    page = (
        layout.replace('{{title}}', html.escape(full_title))
        .replace('{{description}}', html.escape(meta.get('description', '')))
        .replace('{{main}}', main)
        .replace('{{root}}', root)
        .replace('{{year}}', '2026')
    )
    # Mark the current top-level section in the header.
    page = page.replace(f'data-section="{section}"', f'data-section="{section}" aria-current="true"')
    return page


def main() -> None:
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir()
    for name in STATIC:
        source = HERE / name
        if source.is_dir():
            shutil.copytree(source, OUT / name)
        else:
            shutil.copy2(source, OUT / name)
    layout = (HERE / 'layout.html').read_text(encoding='utf-8')
    for path in SOURCES:
        target = OUT / path / 'index.html'
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(render(path, layout), encoding='utf-8')
    # The camera guide's images, at the relative paths it uses.
    shutil.copytree(ROOT / 'docs' / 'images' / 'camera', OUT / 'guides' / 'camera' / 'images' / 'camera')
    print(f'Built {len(SOURCES)} pages into {OUT.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
