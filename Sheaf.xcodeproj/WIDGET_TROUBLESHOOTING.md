# Widget Complication Troubleshooting Guide

## Issue: Cloud Icon or Empty Widget

If you're seeing a cloud icon or placeholder in your watch complication, follow these steps:

### 1. ✅ Enable App Groups for Widget Extension

**In Xcode:**
1. Select the **SheafWatchWidgetExtension** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability** button
4. Add **App Groups**
5. Enable/check the box for: `group.systems.lupine.sheaf`

**Verify on ALL targets:**
- ✓ Main app target (Sheaf)
- ✓ Watch app target (SheafWatch)  
- ✓ Widget extension target (SheafWatchWidgetExtension)

### 2. 🔧 Check Entitlements Files

Make sure you have entitlements files for each target with App Groups enabled:

**SheafWatchWidgetExtension.entitlements:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.systems.lupine.sheaf</string>
    </array>
</dict>
</plist>
```

### 3. 🏃 Test Data Writing

Run the main app and:
1. Make sure someone is set as fronting
2. Check the Console app (macOS) or Xcode console for widget logs:
   - `✅ Widget: Loaded fronting data` - Success!
   - `⚠️ Widget: Unable to access App Group` - Entitlements not configured
   - `⚠️ Widget: No fronting data found` - App hasn't written data yet

### 4. 🔄 Force Widget Reload

After fixing entitlements:
1. **Delete the widget** from your watch face
2. **Clean build folder** in Xcode (Cmd+Shift+K)
3. **Rebuild** the app
4. **Reinstall** on your device/simulator
5. **Re-add the complication** to your watch face

### 5. 📱 Verify Data is Being Written

In your main app's code, check that `SystemStore.updateWatchComplication()` is being called when fronting changes.

Look for this code in `SystemStore.swift`:
```swift
private func updateWatchComplication() {
    guard let sharedDefaults = UserDefaults(suiteName: "group.systems.lupine.sheaf") else {
        return
    }
    // ... writes data
    WidgetKit.WidgetCenter.shared.reloadAllTimelines()
}
```

Make sure this is called when fronting members change!

### 6. 🐛 Debug with Simulator

If testing on simulator:
1. Make sure you're using **watchOS 9.0+** simulator
2. Some widget features may not work perfectly in simulator
3. Test on a real device for best results

### 7. 📦 Check Target Membership

For these files, verify they're included in the **SheafWatchWidgetExtension** target:
- ✓ `FrontingComplication.swift`
- ✓ `FrontingComplicationBundle.swift` 
- ✓ `SharedFrontingData.swift`
- ✓ Any Color extension files (from Models.swift)

### 8. 🎨 Widget Still Shows Placeholder?

If the widget gallery shows your widget but it stays as a cloud icon on the face:

**Common causes:**
- App Group data hasn't been written yet (launch main app first)
- Widget crashed during loading (check crash logs)
- Timeline provider returning errors

**Try this test:**
Add temporary test data to verify widget can display:
```swift
func getTimeline(in context: Context, completion: @escaping (Timeline<FrontingEntry>) -> Void) {
    // TEMPORARY TEST - remove after confirming it works
    let testEntry = FrontingEntry(
        date: Date(),
        frontingMember: SharedMember.example,
        frontCount: 1
    )
    let timeline = Timeline(entries: [testEntry], policy: .atEnd)
    completion(timeline)
}
```

If this shows data, the issue is with reading from UserDefaults App Group.

---

## Quick Checklist

- [ ] App Groups capability added to widget extension
- [ ] Entitlements file exists and is correct
- [ ] Main app writes to shared UserDefaults
- [ ] Widget reads from same App Group ID
- [ ] Rebuilt app after adding entitlements
- [ ] Removed and re-added complication to watch face
- [ ] Checked console logs for widget errors

---

## Still Having Issues?

1. Check Xcode console for error messages
2. Verify the App Group ID matches exactly in all places
3. Make sure you're signed in and have someone fronting in the main app
4. Try testing on a real device (not simulator)
