# Biometric Login Implementation Guide

This guide explains the complete biometric login implementation for the Jeel ERP Flutter app.

## Overview

The app implements a secure biometric authentication system that:
1. Saves user credentials securely using `flutter_secure_storage`
2. Prompts users to enable biometric login after first login
3. Shows biometric authentication on app launch
4. Auto-fills WebView login form and submits automatically

## Architecture

### Flow Diagram

```
App Launch
    ↓
BiometricGateScreen (checks if biometric enabled)
    ↓ (if enabled)
Biometric Authentication Prompt
    ↓ (on success)
SplashScreen (preloads web page)
    ↓
WebViewScreen (auto-fills and submits form)
```

## Package Setup

### 1. Dependencies in `pubspec.yaml`

The following packages are already configured:

```yaml
dependencies:
  local_auth: ^2.3.0              # Biometric authentication
  flutter_secure_storage: ^9.2.2  # Secure credential storage
  webview_flutter: ^4.13.0        # WebView for login page
```

### 2. Android Setup (`android/app/src/main/AndroidManifest.xml`)

Biometric permissions are already added:

```xml
<!-- Biometric authentication permissions -->
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<uses-permission android:name="android.permission.USE_FINGERPRINT"/>
```

### 3. iOS Setup (`ios/Runner/Info.plist`)

Face ID usage description is required:

```xml
<!-- Face ID Usage Description -->
<key>NSFaceIDUsageDescription</key>
<string>We need Face ID access to authenticate you securely</string>
```

## Key Components

### 1. BiometricGateScreen (`lib/biometric_gate_screen.dart`)

**Purpose**: First screen shown on app launch. Checks if biometric login is enabled and shows authentication prompt.

**Key Methods**:
- `_checkInitialState()`: Checks if credentials exist and biometric is enabled
- `_authenticateAndNavigate()`: Triggers biometric authentication and navigates on success

**Flow**:
1. Checks if saved credentials exist
2. Checks if biometric login is enabled
3. Checks if device supports biometrics
4. Shows authentication prompt if all conditions met
5. Navigates to SplashScreen after authentication

### 2. SecureStorageService (`lib/services/secure_storage_service.dart`)

**Purpose**: Manages secure storage of credentials and settings.

**Key Methods**:
- `saveCredentials()`: Save username and password securely
- `getCredentials()`: Retrieve saved credentials
- `hasSavedCredentials()`: Check if credentials exist
- `setBiometricEnabled()`: Enable/disable biometric login
- `isBiometricEnabled()`: Check if biometric is enabled

**Storage Keys**:
- `saved_username`: Username
- `saved_password`: Password
- `biometric_enabled`: Boolean flag for biometric login

### 3. BiometricService (`lib/services/biometric_service.dart`)

**Purpose**: Handles biometric authentication.

**Key Methods**:
- `isAvailable()`: Check if biometric authentication is available
- `authenticate()`: Trigger biometric authentication
- `getAvailableBiometrics()`: Get list of available biometric types

### 4. WebViewScreen (`lib/webview_screen.dart`)

**Purpose**: Displays the login WebView and handles auto-fill.

**Key Features**:
- Auto-fills login form with saved credentials
- Supports multiple input field selector patterns
- Proper JavaScript string escaping
- Optional auto-submit functionality

**Key Methods**:
- `_autoFillFromStoredCredentials()`: Fills login form automatically
- `_showBiometricEnableDialog()`: Shows dialog to enable biometric after login

### 5. JavaScriptHelpers (`lib/utils/javascript_helpers.dart`)

**Purpose**: Provides JavaScript code generation with proper escaping.

**Key Methods**:
- `escapeJavaScript()`: Escapes special characters in strings
- `generateAutoFillScript()`: Generates JavaScript to fill form fields
- `generateCheckLoginFormScript()`: Checks if login form exists

## Implementation Steps

### Step 1: Save Credentials After Login

When user logs in successfully, show a dialog to save credentials:

```dart
import 'widgets/credential_saver_dialog.dart';

// After successful login
showDialog(
  context: context,
  builder: (context) => CredentialSaverDialog(
    username: 'user@example.com',
    password: 'password123',
  ),
);
```

### Step 2: Update HTML Selectors

If your login form uses different field names, update the selectors in `JavaScriptHelpers.generateAutoFillScript()`:

```dart
final autoFillScript = JavaScriptHelpers.generateAutoFillScript(
  username: username,
  password: password,
  usernameSelector: 'input[name="your-username-field"]',
  passwordSelector: 'input[name="your-password-field"]',
  autoSubmit: true, // Set to true to auto-submit form
);
```

### Step 3: Enable Auto-Submit (Optional)

To automatically submit the form after filling, set `autoSubmit: true`:

```dart
await _controller.runJavaScript(
  JavaScriptHelpers.generateAutoFillScript(
    username: username,
    password: password,
    autoSubmit: true, // Auto-submit after filling
  ),
);
```

### Step 4: Handle String Escaping

The `JavaScriptHelpers.escapeJavaScript()` method handles:
- Backslashes (`\`)
- Single quotes (`'`)
- Double quotes (`"`)
- Newlines, carriage returns, tabs

Always use the helper when injecting JavaScript to prevent injection attacks.

## Testing

### Test Biometric Login Flow

1. **First Launch**:
   - Open app
   - Should show BiometricGateScreen briefly, then SplashScreen
   - No credentials saved yet

2. **After First Login**:
   - Log in normally through WebView
   - Dialog should appear asking to save credentials
   - Enable biometric if desired

3. **Subsequent Launches**:
   - Should show biometric prompt
   - On success, auto-fill and login automatically

### Test Auto-Fill

1. Check console logs for JavaScript execution
2. Verify form fields are filled correctly
3. Test with different login form structures

## Troubleshooting

### Biometric Not Working

1. **Check Permissions**: Verify AndroidManifest.xml and Info.plist
2. **Check Device Support**: Ensure device has fingerprint/Face ID
3. **Check Biometric Enrollment**: User must have biometrics enrolled on device

### Auto-Fill Not Working

1. **Check Selectors**: Verify HTML field names match selectors in JavaScriptHelpers
2. **Check Timing**: Add delay if form loads slowly
3. **Check Console**: Look for JavaScript errors in WebView console

### Credentials Not Saving

1. **Check Secure Storage**: Verify flutter_secure_storage is properly configured
2. **Check Permissions**: Ensure app has necessary permissions
3. **Check Error Logs**: Look for storage errors in console

## Security Considerations

1. **Secure Storage**: Credentials are encrypted using platform keychain/keystore
2. **Biometric Protection**: Biometric authentication required before accessing credentials
3. **JavaScript Escaping**: All user input is properly escaped to prevent injection
4. **No Plain Text**: Credentials never stored in plain text

## Customization

### Change Biometric Reason Text

In `BiometricGateScreen._authenticateAndNavigate()`:

```dart
final authenticated = await BiometricService.authenticate(
  reason: 'Your custom authentication message',
);
```

### Change Form Selectors

In `JavaScriptHelpers.generateAutoFillScript()`, modify the selector arrays:

```dart
var usernameSelectors = [
  'input[name="your-field"]',
  // Add more selectors
];
```

### Customize Auto-Fill Timing

Adjust delays in `WebViewScreen._autoFillFromStoredCredentials()`:

```dart
await Future.delayed(const Duration(milliseconds: 1000)); // Increase delay
```

## Notes

- Biometric authentication requires physical presence (fingerprint/Face ID)
- Credentials are stored securely using platform encryption
- JavaScript injection happens after page load for reliability
- Multiple selector patterns ensure compatibility with different form structures
- All string escaping prevents JavaScript injection attacks

## Future Enhancements

- Add WebView JavaScript channel for bidirectional communication
- Implement credential extraction from successful login callback
- Add biometric fallback to PIN/password
- Support for multiple saved accounts
- Auto-logout after inactivity period

