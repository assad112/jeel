/// Helper class to capture form data before submission
class FormCaptureHelper {
  /// Generate JavaScript to intercept form submission and capture credentials
  static String generateFormCaptureScript() {
    return '''
(function() {
  // Function to capture credentials before form submission
  function captureCredentials() {
    var usernameInput = document.querySelector('input[name="login"], input[name="username"], input[type="email"]');
    var passwordInput = document.querySelector('input[type="password"], input[name="password"]');
    
    if (usernameInput && passwordInput) {
      var username = usernameInput.value;
      var password = passwordInput.value;
      
      if (username && password) {
        // Send credentials to Flutter
        if (window.FlutterChannel && window.FlutterChannel.postMessage) {
          window.FlutterChannel.postMessage(JSON.stringify({
            action: 'captureCredentials',
            username: username,
            password: password
          }));
        }
        return true;
      }
    }
    return false;
  }
  
  // Intercept form submission
  var forms = document.querySelectorAll('form');
  forms.forEach(function(form) {
    form.addEventListener('submit', function(e) {
      captureCredentials();
    }, true); // Use capture phase
  });
  
  // Intercept button clicks
  var submitButtons = document.querySelectorAll('button[type="submit"], input[type="submit"]');
  submitButtons.forEach(function(button) {
    button.addEventListener('click', function(e) {
      setTimeout(function() {
        captureCredentials();
      }, 100);
    }, true);
  });
  
  // Monitor input changes to capture credentials as user types
  var usernameInput = document.querySelector('input[name="login"], input[name="username"], input[type="email"]');
  var passwordInput = document.querySelector('input[type="password"], input[name="password"]');
  
  if (usernameInput) {
    usernameInput.addEventListener('change', function() {
      if (usernameInput.value && passwordInput && passwordInput.value) {
        captureCredentials();
      }
    });
  }
  
  if (passwordInput) {
    passwordInput.addEventListener('change', function() {
      if (passwordInput.value && usernameInput && usernameInput.value) {
        captureCredentials();
      }
    });
  }
  
  return 'Form capture script loaded';
})();
''';
  }

  /// Generate JavaScript to extract current form values
  static String generateExtractCredentialsScript() {
    return '''
(function() {
  var usernameInput = document.querySelector('input[name="login"], input[name="username"], input[type="email"]');
  var passwordInput = document.querySelector('input[type="password"], input[name="password"]');
  
  if (usernameInput && passwordInput) {
    return JSON.stringify({
      username: usernameInput.value,
      password: passwordInput.value,
      hasValues: !!usernameInput.value && !!passwordInput.value
    });
  }
  return JSON.stringify({username: null, password: null, hasValues: false});
})();
''';
  }
}

