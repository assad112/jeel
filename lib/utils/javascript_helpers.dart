// /// Helper class for JavaScript injection with proper escaping
// class JavaScriptHelpers {
//   /// Escape JavaScript string to prevent injection attacks
//   static String escapeJavaScript(String input) {
//     return input
//         .replaceAll('\\', '\\\\')  // Backslash
//         .replaceAll("'", "\\'")    // Single quote
//         .replaceAll('"', '\\"')    // Double quote
//         .replaceAll('\n', '\\n')   // Newline
//         .replaceAll('\r', '\\r')   // Carriage return
//         .replaceAll('\t', '\\t');  // Tab
//   }

//   /// Generate JavaScript code to fill login form fields
//   /// Supports multiple selector patterns for username and password fields
//   static String generateAutoFillScript({
//     required String username,
//     required String password,
//     String usernameSelector = 'input[name="login"]',
//     String passwordSelector = 'input[name="password"]',
//     bool autoSubmit = false,
//   }) {
//     final escapedUsername = escapeJavaScript(username);
//     final escapedPassword = escapeJavaScript(password);

//     return '''
// (function() {
//   // Multiple selector patterns for username field
//   var usernameSelectors = [
//     'input[name="login"]',
//     'input[name="username"]',
//     'input[name="email"]',
//     'input[type="email"]',
//     'input[id*="login"]',
//     'input[id*="username"]',
//     'input[id*="email"]',
//     'input[placeholder*="email" i]',
//     'input[placeholder*="username" i]',
//     'input[placeholder*="login" i]'
//   ];

//   // Multiple selector patterns for password field
//   var passwordSelectors = [
//     'input[name="password"]',
//     'input[type="password"]',
//     'input[id*="password"]'
//   ];

//   var usernameInput = null;
//   var passwordInput = null;

//   // Find username input
//   for (var i = 0; i < usernameSelectors.length; i++) {
//     usernameInput = document.querySelector(usernameSelectors[i]);
//     if (usernameInput) break;
//   }

//   // Find password input
//   for (var i = 0; i < passwordSelectors.length; i++) {
//     passwordInput = document.querySelector(passwordSelectors[i]);
//     if (passwordInput) break;
//   }

//   if (usernameInput) {
//     usernameInput.value = '$escapedUsername';
//     // Trigger events to notify framework
//     usernameInput.dispatchEvent(new Event('input', { bubbles: true }));
//     usernameInput.dispatchEvent(new Event('change', { bubbles: true }));
//     usernameInput.focus();
//     usernameInput.blur();
//   }

//   if (passwordInput) {
//     passwordInput.value = '$escapedPassword';
//     // Trigger events to notify framework
//     passwordInput.dispatchEvent(new Event('input', { bubbles: true }));
//     passwordInput.dispatchEvent(new Event('change', { bubbles: true }));
//     passwordInput.focus();
//     passwordInput.blur();
//   }

//   ${autoSubmit ? '''
//   // Auto submit form if fields are found
//   if (usernameInput && passwordInput) {
//     // Wait a bit for framework to process the values
//     setTimeout(function() {
//       var form = usernameInput.closest('form');
//       if (form) {
//         // Try to find and click submit button
//         var submitButton = form.querySelector('button[type="submit"], input[type="submit"], button:not([type])');
//         if (submitButton) {
//           submitButton.click();
//         } else {
//           // Fallback: submit form directly
//           form.submit();
//         }
//       } else {
//         // If no form found, try to find submit button near inputs
//         var submitButton = document.querySelector('button[type="submit"], input[type="submit"]');
//         if (submitButton) {
//           submitButton.click();
//         }
//       }
//     }, 500);
//   }
//   ''' : ''}

//   return {
//     usernameFound: !!usernameInput,
//     passwordFound: !!passwordInput
//   };
// })();
// ''';
//   }

//   /// Generate JavaScript to check if login form exists
//   static String generateCheckLoginFormScript() {
//     return '''
// (function() {
//   var hasLoginForm = false;
//   var usernameInput = document.querySelector('input[name="login"], input[name="username"], input[type="email"]');
//   var passwordInput = document.querySelector('input[type="password"], input[name="password"]');

//   if (usernameInput && passwordInput) {
//     hasLoginForm = true;
//   }

//   return hasLoginForm;
// })();
// ''';
//   }
// }

import 'dart:convert'; // Tambahkan ini untuk jsonEncode

class JavaScriptHelpers {
  /// Generate JavaScript code to fill login form fields
  static String generateAutoFillScript({
    required String username,
    required String password,
    bool autoSubmit = false,
  }) {
    // Menggunakan jsonEncode jauh lebih aman daripada replaceAll manual.
    // jsonEncode otomatis menangani quote, backslash, unicode, dll.
    final jsonUsername = jsonEncode(username);
    final jsonPassword = jsonEncode(password);

    return '''
(function() {
  // 1. Definisikan Selector Patterns
  var usernameSelectors = [
    'input[name="login"]',
    'input[name="username"]',
    'input[name="email"]',
    'input[type="email"]',
    'input[id*="user"]',
    'input[id*="login"]',
    'input[placeholder*="user" i]',
    'input[placeholder*="email" i]',
    'input[aria-label*="user" i]'
  ];
  
  var passwordSelectors = [
    'input[name="password"]',
    'input[type="password"]',
    'input[id*="pass"]',
    'input[placeholder*="pass" i]'
  ];

  // 2. Fungsi Helper untuk set value secara "Native" (PENTING UNTUK REACT)
  function setNativeValue(element, value) {
    if (!element) return;
    
    // Simpan value terakhir agar tidak trigger event jika sama
    const lastValue = element.value;
    element.value = value;
    
    // Hack khusus React 15/16+
    // React meng-override properti .value, jadi kita harus memanggil
    // setter asli dari prototype HTMLInputElement agar React "sadar" ada perubahan.
    const tracker = element._valueTracker;
    if (tracker) {
      tracker.setValue(lastValue);
    }
    
    // Dapatkan setter asli
    let descriptor = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value");
    
    // Jika tidak ada di HTMLInputElement, coba cek di prototype rantai (jarang terjadi)
    if (!descriptor) {
        descriptor = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(element), "value");
    }

    if (descriptor && descriptor.set) {
        descriptor.set.call(element, value);
    }

    // Trigger events standard
    var events = ['focus', 'input', 'change', 'blur'];
    for (var i = 0; i < events.length; i++) {
        var event = new Event(events[i], { bubbles: true, cancelable: true });
        element.dispatchEvent(event);
    }
  }

  // 3. Cari Element
  var usernameInput = null;
  var passwordInput = null;
  
  for (var i = 0; i < usernameSelectors.length; i++) {
    usernameInput = document.querySelector(usernameSelectors[i]);
    if (usernameInput) break;
  }
  
  for (var i = 0; i < passwordSelectors.length; i++) {
    passwordInput = document.querySelector(passwordSelectors[i]);
    if (passwordInput) break;
  }
  
  // 4. Eksekusi Pengisian
  if (usernameInput) {
    setNativeValue(usernameInput, $jsonUsername);
  }
  
  if (passwordInput) {
    setNativeValue(passwordInput, $jsonPassword);
  }
  
  // 5. Auto Submit Logic
  ${autoSubmit ? '''
  if (usernameInput && passwordInput) {
    setTimeout(function() {
      // Prioritaskan tombol submit di dalam form yang sama
      var form = usernameInput.closest('form');
      var submitBtn = null;
      
      if (form) {
        submitBtn = form.querySelector('button[type="submit"], input[type="submit"]');
        if (!submitBtn) {
           // Coba cari button apapun di dalam form yang mungkin tombol login
           submitBtn = form.querySelector('button:not([type="button"]):not([type="reset"])');
        }
      }
      
      if (submitBtn) {
        submitBtn.click();
      } else if (form) {
        // Fallback terakhir: submit form langsung (bypass validasi JS kadang-kadang)
        form.submit();
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
  // Cek apakah ada input password yang terlihat (bukan hidden)
  var passwordInput = document.querySelector('input[type="password"]');
  
  // Cek apakah element tersebut visible (bukan display: none)
  if (passwordInput && passwordInput.offsetParent !== null) {
      return true;
  }
  
  // Fallback cek nama field jika type password tidak ketemu
  var specificInput = document.querySelector('input[name*="pass"], input[name*="login"]');
  return !!specificInput;
})();
''';
  }
}
