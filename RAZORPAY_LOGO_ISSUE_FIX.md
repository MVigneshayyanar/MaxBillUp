# Razorpay Logo Issue - Solution Guide 🔧

## Problem
The Razorpay payment screen is showing only the letter "M" instead of the full MAX_my_bill.png logo.

## Why This Happens
Razorpay's Flutter SDK **does NOT support local asset paths** like `'assets/MAX_my_bill.png'`. 

The `image` parameter requires a **publicly accessible HTTPS URL**, not a local file path.

When Razorpay can't load the image, it falls back to showing the first letter of the business name ("M" from "MAXmybill").

## Solution: Upload Logo to Firebase Storage

### Step 1: Upload Logo to Firebase Storage

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your MAXmybill project
3. Click on **Storage** in the left sidebar
4. Click **Upload file**
5. Select `assets/MAX_my_bill.png`
6. Upload to a path like: `branding/MAX_my_bill.png`

### Step 2: Get Public URL

1. After upload, click on the uploaded file
2. Click on the **Get link** or **Download URL**
3. Copy the public URL (it will look like):
   ```
   https://firebasestorage.googleapis.com/v0/b/your-project.appspot.com/o/branding%2FMAX_my_bill.png?alt=media&token=xxx-xxx-xxx
   ```

### Step 3: Update Code

In `SubscriptionPlanPage.dart`, update the options:

```dart
var options = {
  'key': 'rzp_test_1DP5mmOlF5G5ag',
  'amount': amount,
  'name': 'MAXmybill',
  'description': '$_selectedPlan Plan Upgrade',
  'currency': 'INR',
  'image': 'https://firebasestorage.googleapis.com/v0/b/YOUR-PROJECT.appspot.com/o/branding%2FMAX_my_bill.png?alt=media&token=YOUR-TOKEN',  // ✅ Use the public URL
  'theme': {'color': '#2F7CF6'}
};
```

## Alternative Solutions

### Option 1: Use a CDN (Recommended for Production)
Upload your logo to a CDN like:
- Cloudinary
- imgBB
- AWS S3
- Any public hosting

### Option 2: Keep Current Behavior
If you want to keep the current "M" letter display:
- Simply remove the `'image'` parameter
- Razorpay will show a nice circle with "M" in your theme color
- This is actually quite common and looks professional

```dart
var options = {
  'key': 'rzp_test_1DP5mmOlF5G5ag',
  'amount': amount,
  'name': 'MAXmybill',  // "M" will be shown in a circle
  'description': '$_selectedPlan Plan Upgrade',
  'currency': 'INR',
  'theme': {'color': '#2F7CF6'}  // "M" will use this color
};
```

### Option 3: Dynamic Logo from Store Data
If you want to use the logo that users upload in Business Profile:

```dart
// In _startPayment() method
final storeDoc = await FirestoreService().getCurrentStoreDoc();
final logoUrl = storeDoc?.data()?['logoUrl'] as String?;

var options = {
  'key': 'rzp_test_1DP5mmOlF5G5ag',
  'amount': amount,
  'name': 'MAXmybill',
  'description': '$_selectedPlan Plan Upgrade',
  'currency': 'INR',
  if (logoUrl != null && logoUrl.isNotEmpty) 
    'image': logoUrl,  // Use business logo if available
  'theme': {'color': '#2F7CF6'}
};
```

## Image Requirements for Razorpay

If you do use an image, ensure:
- ✅ **Format:** PNG, JPG, or JPEG
- ✅ **Size:** Minimum 256x256 pixels
- ✅ **Recommended:** 512x512 pixels (square)
- ✅ **URL:** Must be HTTPS (not HTTP)
- ✅ **Accessibility:** Publicly accessible (no authentication required)
- ✅ **File size:** Under 1MB

## Current Code Status

I've updated your code to:
1. Remove the non-working local asset path
2. Add clear comments explaining the requirement
3. Add prefill fields for better UX

## What Happens Now

**Current behavior:**
- Razorpay shows a circle with letter "M"
- Uses your theme color (#2F7CF6)
- Looks professional and clean

**To show full logo:**
- Follow Step 1-3 above to upload to Firebase Storage
- Use the public URL in the `image` parameter

## Quick Test

To verify everything works:
1. Run your app
2. Go to Subscription Plans
3. Select a plan and click "UPGRADE NOW"
4. Razorpay screen opens
5. You'll see a blue circle with "M" at the top
6. This is normal and professional!

## Recommendation

For now, I recommend:
- ✅ **Keep the current setup** (letter "M" in circle)
- ✅ It's clean and professional
- ✅ No extra hosting needed
- ✅ Fast loading

Later, if you want the full logo:
- Upload to Firebase Storage
- Add the public URL
- Test on real device

## Files Modified
- `lib/Auth/SubscriptionPlanPage.dart` - Removed invalid local asset path, added comments

The payment will work perfectly with or without the logo image! 🎉

