const markdownPaths = new Map([
  ['/', '/index.md'],
  ['/support/', '/support/index.md'],
  ['/privacy/', '/privacy/index.md'],
]);

function splitOutsideQuotes(value, separator) {
  const parts = [];
  let start = 0;
  let quoted = false;
  for (let index = 0; index < value.length; index += 1) {
    if (quoted && value[index] === '\\') {
      index += 1;
    } else if (value[index] === '"') {
      quoted = !quoted;
    } else if (!quoted && value[index] === separator) {
      parts.push(value.slice(start, index).trim());
      start = index + 1;
    }
  }
  return quoted ? null : [...parts, value.slice(start).trim()];
}

function prefersMarkdown(accept) {
  const preferences = {
    'text/html': { specificity: -1, quality: 0 },
    'text/markdown': { specificity: -1, quality: 0 },
  };
  for (const range of splitOutsideQuotes(accept ?? '', ',') ?? []) {
    const [media, ...parameters] = splitOutsideQuotes(range.toLowerCase(), ';') ?? [];
    if (!['*/*', 'text/*', ...Object.keys(preferences)].includes(media)) {
      continue;
    }
    let quality = 1;
    let hasQuality = false;
    let charset = false;
    let valid = true;
    for (const parameter of parameters) {
      const weight = /^q\s*=\s*(0(?:\.\d{0,3})?|1(?:\.0{0,3})?)$/.exec(parameter);
      if (weight && !hasQuality) {
        quality = Number(weight[1]);
        hasQuality = true;
      } else if (/^charset\s*=\s*(utf-8|"utf-8")$/.test(parameter) && !charset) {
        charset = true;
      } else {
        valid = false;
      }
    }
    if (!valid) {
      continue;
    }
    const specificity = (media === '*/*' ? 0 : media === 'text/*' ? 1 : 2) + (charset ? 0.1 : 0);
    for (const [type, preference] of Object.entries(preferences)) {
      if (media === type || media.endsWith('/*')) {
        if (specificity > preference.specificity || (specificity === preference.specificity && quality > preference.quality)) {
          Object.assign(preference, { specificity, quality });
        }
      }
    }
  }
  const markdown = preferences['text/markdown'];
  return markdown.specificity >= 2 && markdown.quality > 0 && markdown.quality >= preferences['text/html'].quality;
}

export default {
  /** Select a generated representation on canonical content routes; delegate all other requests to Pages. */
  async fetch(request, env) {
    const url = new URL(request.url);
    const markdownPath = markdownPaths.get(url.pathname);
    if (!markdownPath || !['GET', 'HEAD'].includes(request.method)) {
      return env.ASSETS.fetch(request);
    }

    const assetHeaders = new Headers(request.headers);
    // Canonical responses are uncacheable full representations, independent of a previous variant's validators.
    for (const name of ['If-None-Match', 'If-Modified-Since', 'If-Match', 'If-Unmodified-Since', 'Range', 'If-Range']) {
      assetHeaders.delete(name);
    }
    let response;
    let markdownSelected = false;
    if (prefersMarkdown(request.headers.get('Accept'))) {
      const markdownUrl = new URL(url);
      markdownUrl.pathname = markdownPath;
      try {
        response = await env.ASSETS.fetch(new Request(markdownUrl, { headers: assetHeaders }));
      } catch {
        // A missing generated asset must leave the authored HTML available.
      }
      if (response?.status === 200 && /^text\/markdown(?:;|$)/i.test(response.headers.get('Content-Type') ?? '')) {
        markdownSelected = true;
      } else {
        await response?.body?.cancel();
        response = undefined;
      }
    }
    response ??= await env.ASSETS.fetch(new Request(url, { headers: assetHeaders }));
    const headers = new Headers(response.headers);
    if (markdownSelected) {
      headers.set('Content-Type', 'text/markdown; charset=utf-8');
    }
    headers.set('Cache-Control', 'no-store');
    const vary = headers.get('Vary')?.split(',').map((name) => name.trim()) ?? [];
    if (!vary.some((name) => ['accept', '*'].includes(name.toLowerCase()))) {
      headers.set('Vary', [...vary, 'Accept'].join(', '));
    }
    if (request.method === 'HEAD') {
      await response.body?.cancel();
    }
    return new Response(request.method === 'HEAD' ? null : response.body, {
      status: response.status,
      statusText: response.statusText,
      headers,
    });
  },
};
