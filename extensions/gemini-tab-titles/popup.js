async function loadTabs() {
  const tabList = document.getElementById('tabList');

  // Add "New Chat" option at top
  const newChatLi = document.createElement('li');
  newChatLi.className = 'tab-item new-chat';
  newChatLi.textContent = '+ New Chat';
  newChatLi.addEventListener('click', () => {
    chrome.tabs.create({ url: 'https://gemini.google.com/' });
    window.close();
  });
  tabList.appendChild(newChatLi);

  // Query all Gemini tabs
  const tabs = await chrome.tabs.query({ url: 'https://gemini.google.com/*' });

  if (tabs.length === 0) {
    const li = document.createElement('li');
    li.className = 'empty';
    li.textContent = 'No Gemini tabs open';
    tabList.appendChild(li);
    return;
  }

  // Add each tab
  tabs.forEach(tab => {
    const li = document.createElement('li');
    li.className = 'tab-item';
    li.textContent = tab.title || 'Gemini';
    li.title = tab.title; // Full title on hover
    li.addEventListener('click', () => {
      chrome.tabs.update(tab.id, { active: true });
      chrome.windows.update(tab.windowId, { focused: true });
      window.close();
    });
    tabList.appendChild(li);
  });
}

loadTabs();
