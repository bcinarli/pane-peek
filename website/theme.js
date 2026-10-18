(() => {
  const root = document.documentElement;
  const systemTheme = window.matchMedia('(prefers-color-scheme: dark)');
  const storageKey = 'panepeek-theme';
  let theme = 'system';

  try {
    const savedTheme = localStorage.getItem(storageKey);
    if (savedTheme === 'light' || savedTheme === 'dark') {
      theme = savedTheme;
    }
  } catch {
    // Use System when browser storage is unavailable.
  }

  function applyTheme() {
    root.dataset.theme = theme;
    const dark = theme === 'dark' || (theme === 'system' && systemTheme.matches);
    document.querySelectorAll('meta[name="theme-color"]').forEach((meta) => {
      meta.content = dark ? '#24273a' : '#eff1f5';
    });
  }

  applyTheme();
  systemTheme.addEventListener('change', applyTheme);

  document.addEventListener('DOMContentLoaded', () => {
    const select = document.querySelector('.theme-switch select');
    select.value = theme;
    select.addEventListener('change', () => {
      theme = select.value;
      applyTheme();
      try {
        if (theme === 'system') {
          localStorage.removeItem(storageKey);
        } else {
          localStorage.setItem(storageKey, theme);
        }
      } catch {
        // Keep the current-page choice when storage is unavailable.
      }
    });
    select.closest('label').hidden = false;
  });
})();
