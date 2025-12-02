/// Helper class for JavaScript injection with proper escaping
class JavaScriptHelpers {
  /// Escape JavaScript string to prevent injection attacks
  static String escapeJavaScript(String input) {
    return input
        .replaceAll('\\', '\\\\')  // Backslash
        .replaceAll("'", "\\'")    // Single quote
        .replaceAll('"', '\\"')    // Double quote
        .replaceAll('\n', '\\n')   // Newline
        .replaceAll('\r', '\\r')   // Carriage return
        .replaceAll('\t', '\\t');  // Tab
  }

  /// Generate JavaScript code to fill login form fields
  /// Supports multiple selector patterns for username and password fields
  static String generateAutoFillScript({
    required String username,
    required String password,
    String usernameSelector = 'input[name="login"]',
    String passwordSelector = 'input[name="password"]',
    bool autoSubmit = false,
  }) {
    final escapedUsername = escapeJavaScript(username);
    final escapedPassword = escapeJavaScript(password);

    return '''
(function() {
  // Multiple selector patterns for username field
  var usernameSelectors = [
    'input[name="login"]',
    'input[name="username"]',
    'input[name="email"]',
    'input[type="email"]',
    'input[id*="login"]',
    'input[id*="username"]',
    'input[id*="email"]',
    'input[placeholder*="email" i]',
    'input[placeholder*="username" i]',
    'input[placeholder*="login" i]'
  ];
  
  // Multiple selector patterns for password field
  var passwordSelectors = [
    'input[name="password"]',
    'input[type="password"]',
    'input[id*="password"]'
  ];
  
  var usernameInput = null;
  var passwordInput = null;
  
  // Find username input
  for (var i = 0; i < usernameSelectors.length; i++) {
    usernameInput = document.querySelector(usernameSelectors[i]);
    if (usernameInput) break;
  }
  
  // Find password input
  for (var i = 0; i < passwordSelectors.length; i++) {
    passwordInput = document.querySelector(passwordSelectors[i]);
    if (passwordInput) break;
  }
  
  if (usernameInput) {
    usernameInput.value = '$escapedUsername';
    // Trigger events to notify framework
    usernameInput.dispatchEvent(new Event('input', { bubbles: true }));
    usernameInput.dispatchEvent(new Event('change', { bubbles: true }));
    usernameInput.focus();
    usernameInput.blur();
  }
  
  if (passwordInput) {
    passwordInput.value = '$escapedPassword';
    // Trigger events to notify framework
    passwordInput.dispatchEvent(new Event('input', { bubbles: true }));
    passwordInput.dispatchEvent(new Event('change', { bubbles: true }));
    passwordInput.focus();
    passwordInput.blur();
  }
  
  ${autoSubmit ? '''
  // Auto submit form if fields are found
  if (usernameInput && passwordInput) {
    // Wait a bit for framework to process the values
    setTimeout(function() {
      var form = usernameInput.closest('form');
      if (form) {
        // Try to find and click submit button
        var submitButton = form.querySelector('button[type="submit"], input[type="submit"], button:not([type])');
        if (submitButton) {
          submitButton.click();
        } else {
          // Fallback: submit form directly
          form.submit();
        }
      } else {
        // If no form found, try to find submit button near inputs
        var submitButton = document.querySelector('button[type="submit"], input[type="submit"]');
        if (submitButton) {
          submitButton.click();
        }
      }
    }, 500);
  }
  ''' : ''}
  
  return {
    usernameFound: !!usernameInput,
    passwordFound: !!passwordInput
  };
})();
''';
  }

  /// Generate JavaScript to check if login form exists
  static String generateCheckLoginFormScript() {
    return '''
(function() {
  var hasLoginForm = false;
  var usernameInput = document.querySelector('input[name="login"], input[name="username"], input[type="email"]');
  var passwordInput = document.querySelector('input[type="password"], input[name="password"]');
  
  if (usernameInput && passwordInput) {
    hasLoginForm = true;
  }
  
  return hasLoginForm;
})();
''';
  }
}

