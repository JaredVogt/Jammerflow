function updateTitle() {
  const titleEl = document.querySelector('.conversation-title.gds-title-m');
  if (titleEl && titleEl.textContent.trim()) {
    const title = titleEl.textContent.trim();
    // Truncate if too long
    const truncated = title.length > 50 ? title.substring(0, 47) + '...' : title;
    document.title = truncated;
  }
}

// Run on load
updateTitle();

// Watch for SPA navigation / title changes
const observer = new MutationObserver(updateTitle);
observer.observe(document.body, { childList: true, subtree: true });
