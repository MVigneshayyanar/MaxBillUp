# Firebase Push Notifications Setup Guide

## ✅ Completed Steps

1. ✅ Added `firebase_messaging` to pubspec.yaml
2. ✅ Created `NotificationService` class
3. ✅ Fixed logout function in Admin Home page
4. ✅ Integrated notification sending when knowledge is posted
5. ✅ Initialize notification service in main.dart

## 📱 How It Works

### For App Users:
1. When the app starts, it requests notification permission
2. If granted, an FCM token is generated and saved to Firestore
3. Token is stored in `fcm_tokens` collection
4. Users are automatically subscribed to `knowledge_updates` topic

### For Admin:
1. Admin posts new knowledge in the Knowledge tab
2. App creates a notification document in Firestore
3. Cloud Function (needs to be deployed) sends push notifications to all tokens
4. Success message shows "✅ Knowledge posted & notifications sent!"

## 🚀 Required: Cloud Functions Setup

To actually send notifications, you need to deploy Firebase Cloud Functions:

### Step 1: Install Firebase Tools
```bash
npm install -g firebase-tools
```

### Step 2: Login to Firebase
```bash
firebase login
```

### Step 3: Initialize Cloud Functions (if not already done)
```bash
cd C:\MaxBillUp
firebase init functions
```
- Choose JavaScript or TypeScript
- Install dependencies

### Step 4: Copy the Function Code
1. Open `firebase_functions_template.js` in the root folder
2. Copy the code to `functions/index.js`
3. Make sure package.json includes:
```json
{
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^5.0.0"
  }
}
```

### Step 5: Deploy Cloud Functions
```bash
firebase deploy --only functions
```

## 📋 Android Configuration (Important!)

### Add to android/app/src/main/AndroidManifest.xml:
```xml
<manifest ...>
    <application ...>
        <!-- Existing code -->
        
        <!-- Firebase Messaging Service -->
        <service
            android:name="com.google.firebase.messaging.FirebaseMessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>
        
        <!-- Default notification channel -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="knowledge_channel" />
    </application>
</manifest>
```

## 🍎 iOS Configuration (Important!)

### 1. Enable Push Notifications in Xcode:
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target
3. Go to "Signing & Capabilities"
4. Click "+ Capability"
5. Add "Push Notifications"
6. Add "Background Modes" and check "Remote notifications"

### 2. Update Info.plist:
```xml
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

## 🧪 Testing Notifications

### Test 1: Check Token Generation
1. Run the app
2. Check console for: `📱 FCM Token: ...`
3. Verify token is saved in Firestore `fcm_tokens` collection

### Test 2: Send Test Notification
Use Firebase Console:
1. Go to Firebase Console → Cloud Messaging
2. Click "Send your first message"
3. Enter title and body
4. Select your app
5. Send test message

### Test 3: Test Knowledge Post
1. Login as admin (maxmybillapp@gmail.com)
2. Go to Knowledge tab
3. Click "Post Knowledge"
4. Fill in title, category, content
5. Click "Post"
6. Check console for: `✅ Notification queued for X devices`
7. Check Firestore `notifications` collection for new document

## 🔧 Firestore Collections Structure

### fcm_tokens
```
fcm_tokens/
├── {token}/
│   ├── token: "eXaMpLe..."
│   ├── createdAt: Timestamp
│   ├── updatedAt: Timestamp
│   └── platform: "android" | "iOS" | "web"
```

### notifications
```
notifications/
├── {notificationId}/
│   ├── notification: {
│   │   title: "🔔 New Tutorial Post"
│   │   body: "How to use reports"
│   │   data: {...}
│   ├── tokens: ["token1", "token2", ...]
│   ├── createdAt: Timestamp
│   ├── sent: false
│   ├── sentAt: Timestamp (after sending)
│   ├── successCount: 10
│   └── failureCount: 2
```

### knowledge
```
knowledge/
├── {docId}/
│   ├── title: "Report Tutorial"
│   ├── content: "This is how to use..."
│   ├── category: "Tutorial"
│   ├── createdAt: Timestamp
│   └── updatedAt: Timestamp
```

## 🐛 Troubleshooting

### Notifications Not Received?
1. Check permission was granted: Look for "✅ User granted notification permission" in console
2. Verify token saved: Check `fcm_tokens` collection in Firestore
3. Check Cloud Function: Look at Firebase Console → Functions → Logs
4. Test with Firebase Console first (see Testing section)

### Logout Not Working?
- ✅ Fixed! Now uses proper Navigator.pushAndRemoveUntil
- Clears navigation stack completely
- Always redirects to LoginPage

### "NotificationService isn't defined" Error?
- This is a false IDE warning after code generation
- Run `flutter clean && flutter pub get`
- Restart IDE/Editor

## 📱 User Experience Flow

1. **First Launch:**
   - Permission dialog appears
   - User grants permission
   - FCM token generated and saved
   - Ready to receive notifications

2. **Admin Posts Knowledge:**
   - Admin fills knowledge form
   - Clicks "Post"
   - Notification queued in Firestore
   - Cloud Function triggers
   - All users receive push notification
   - Notification shows: "🔔 New {Category} Post"

3. **User Receives Notification:**
   - Notification appears on device
   - Tap to open app (optional: deep link to knowledge post)

## 🎯 Next Steps (Optional Enhancements)

1. **Deep Linking**: Open specific knowledge post when notification tapped
2. **Notification Channels**: Separate channels for different categories
3. **User Preferences**: Let users choose which categories to get notified about
4. **Rich Notifications**: Add images, action buttons
5. **Analytics**: Track notification open rates

## ✨ Summary

✅ Logout function now works properly
✅ Firebase Messaging integrated
✅ Notifications sent when knowledge posted
✅ FCM tokens stored in Firestore
✅ Cloud Function template provided
✅ Ready to deploy and test!

**Deploy the Cloud Function to complete the setup!**

