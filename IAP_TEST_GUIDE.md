# IAP Testing Guide for ChordLibre

## Quick Test Setup

1. **Enable StoreKit Configuration:**
   - Edit Scheme → Run → Options
   - Select "StoreKit Configuration.storekit"

## Test Cases

### ✅ Happy Path Testing
1. **Purchase Flow:**
   - Launch app
   - Go to Settings
   - Tap "Support Development"
   - Verify price shows as £0.99
   - Tap "Support" button
   - Complete purchase (auto-approved in test mode)
   - Verify tips banner disappears
   - Verify "Thank you for your support!" message appears

2. **Restore Purchase:**
   - Delete app / Clear UserDefaults
   - Reinstall
   - Go to Settings → Support Development
   - Tap "Restore Purchase"
   - Verify previous purchase is restored
   - Verify tips banner is removed

### 🔴 Error Testing

1. **Network Failure:**
   - In StoreKit Configuration:
   - Enable "Load Products" error → "Network Error"
   - Launch app
   - Verify error message appears

2. **Purchase Failure:**
   - Enable "Purchase" error → "Purchase Failed"
   - Try to purchase
   - Verify error handling

3. **User Cancellation:**
   - Start purchase
   - Cancel at payment sheet
   - Verify app handles gracefully

## StoreKit Transaction Manager

**Access via:** Xcode → Debug → StoreKit → Manage Transactions

Features:
- View all test purchases
- Delete transactions to test fresh purchase
- Refund purchases to test restore
- Speed up/slow down time for subscriptions (not needed here)

## Testing on Real Device (Sandbox)

1. **Create Sandbox Tester:**
   - App Store Connect → Users and Access → Sandbox Testers
   - Create new tester with fake email

2. **On Device:**
   - Settings → App Store → Sandbox Account → Sign in
   - Run app from Xcode
   - Purchases will use sandbox (no real charges)

## Command Line Testing

```bash
# Reset all purchases (simulator only)
xcrun simctl shutdown all
xcrun simctl erase all

# Or just your app's container
xcrun simctl uninstall booted com.chordlibre.app
```

## Verify Implementation

### Check These States:
- [ ] Fresh install - tips banner visible
- [ ] After purchase - tips banner hidden
- [ ] After app restart - purchase persisted
- [ ] Settings shows/hides support option correctly
- [ ] Restore works after reinstall
- [ ] Error messages are user-friendly

## Production Checklist

Before going live:
1. Remove StoreKit Configuration from scheme
2. Test with real App Store Connect product
3. Verify product ID matches exactly: `com.addedpixels.chordlibre.supporttip`
4. Test with TestFlight and sandbox testers
5. Ensure proper error handling for all cases

## App Store Connect Setup

Create this exact product:
- **Product ID:** `com.addedpixels.chordlibre.supporttip`
- **Reference Name:** Support ChordLibre
- **Type:** Non-Consumable
- **Price:** Tier 1 (£0.99 / $0.99)