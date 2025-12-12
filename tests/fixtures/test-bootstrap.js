// TEST_BOOTSTRAP fixture file for helm chart testing
(function() {
  console.log("Test bootstrap loaded from file");
  window.TEST_BOOTSTRAP = {
    loaded: true,
    timestamp: Date.now()
  };
})();
