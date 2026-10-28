# Rice2K Project Explorer

**Public site:** https://rice2k.github.io/rice2k-startdeck/projects/

A free searchable catalog of Rice2K's public GitHub repositories and the account's publicly starred repositories. This is a separate feature under RiceDeck, not a replacement for the normal homepage.

## Features

- Live public GitHub API index with no credentials, API key, server, or paid dependency.
- Searches repository names, descriptions, topics, categories, and programming languages.
- Typo tolerance and synonyms such as GS2, Graal, PC repair, and Windows tools.
- Categories: GraalOnline, Windows & IT, Web Archives, Security, Discord, Automation, Web Projects, Productivity, and Other.
- Filter by programming language; sort by relevance, latest push, stars, or A–Z.
- Switch between public repositories and repositories starred by Rice2K (read-only, never stars or unstars anything).
- Share filters and searches through URL query parameters.
- Responsive, keyboard-accessible layout with slash-to-focus shortcut.
- GitHub Pages-compatible static HTML, CSS, and JavaScript with no build step.

## Indexing and privacy

The site requests public metadata from GitHub's REST endpoints:

- https://api.github.com/users/rice2k/repos?per_page=100&page=1&type=owner
- https://api.github.com/users/rice2k/starred?per_page=100&page=1

Up to 10 pages are fetched if needed; private repositories are excluded. Successful responses are cached in the visitor's browser for two hours to reduce GitHub unauthenticated rate limits. Refresh forces a new request.

If GitHub is unreachable, the owned collection can show a visibly labeled limited sample catalog. Starred repositories only display live or cached results. The site never asks for GitHub credentials and never changes the account's stars, follows, files, or settings. **Search covers GitHub repository metadata, not every code file.**

## Host and deployment

The Rice2K GitHub profile repository does not currently have Pages enabled. These files live under the existing Pages-enabled RiceDeck repository in the projects/ folder.

- projects/index.html: page, controls and SEO metadata
- projects/styles.css: responsive styles
- projects/app.js: search, public API, cache and rendering
- projects/README.md: documentation

The existing RiceDeck homepage, installer, and core app are unchanged. No paid services or workflow minutes are required for site functionality.

## Updating search and discoverability

1. Add a clear description, relevant topics, and a valid public homepage URL in each repository's GitHub About settings.
2. Make the README opening paragraph explain what the project does, its status, and the intended platform.
3. Provide screenshots, supported OS information, trustworthy download links, release notes, and appropriate attribution.
4. Use caution with alpha encryption software and web archives that document missing artifacts.
5. Metadata updates appear after the browser cache expires or users press Refresh.
6. Do not add private repository details, secrets, personal files, or access tokens to this public site.

## Testing checklist

- Open on desktop and mobile after GitHub Pages publishes.
- Search Graal, Windows, archive, GS2, and a typo such as windwos.
- Test category, language, scope, and sorting controls.
- Copy a filtered link and load it in another tab.
- Check external links and live-site links.
- Disconnect temporarily to test cached data and the labeled fallback catalog.

## Static search and resilience

- [Complete static repository list](all-projects.html) — browse all 62 public repositories without JavaScript. Grouped static HTML links are easier for crawlers to discover.
- [Static metadata fallback](catalog.json) — an October 27, 2026 public-repository snapshot with verified descriptions where available. The browser search uses this complete fallback if GitHub's API is unavailable and no recent cache exists.
- The live GitHub API remains the source for the latest stars, last update dates, new repositories, and current topics whenever it is reachable.
- The snapshot is not a mirror of private repository content, source code or releases, and will require a manual update if many new public repositories are added.

## Limitations

GitHub can rate-limit unauthenticated API calls. Caches can be up to two hours old. Search is metadata-based and does not index every source code file. The Starred collection is public and read-only.
