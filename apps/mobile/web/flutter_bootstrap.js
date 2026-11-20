{{flutter_js}}
{{flutter_build_config}}

// Custom industrial bootstrap for Saark ERP
// Avoids legacy service-worker reload loops and provides smooth splash transition
function dismissLoadingScreen() {
  const loader = document.getElementById('app-loading-screen');
  if (loader && !loader.classList.contains('dismissed')) {
    loader.classList.add('dismissed');
    setTimeout(() => {
      if (loader.parentNode) loader.parentNode.removeChild(loader);
    }, 450);
  }
}

// Fallback observer: if Flutter inserts flutter-view or canvas, dismiss loader
const observer = new MutationObserver((mutations) => {
  for (const m of mutations) {
    for (const node of m.addedNodes) {
      if (node.nodeName === 'FLUTTER-VIEW' || node.classList?.contains('flt-glass-pane') || node.nodeName === 'CANVAS') {
        observer.disconnect();
        dismissLoadingScreen();
        return;
      }
    }
  }
});
observer.observe(document.body, { childList: true, subtree: true });

_flutter.loader.load({
  onEntrypointLoaded: async function(engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      dismissLoadingScreen();
      await appRunner.runApp();
    } catch (err) {
      console.error('Flutter initialization error:', err);
      dismissLoadingScreen();
    }
  }
});

