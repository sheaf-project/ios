# Fix: "Integrity Could Not Be Verified" Error

## Step-by-Step Debugging Process

Since standard solutions didn't work, let's systematically diagnose the issue:

### **Step 1: Verify Your Setup**

Answer these questions to help identify the problem:

1. **Are you testing on:**
   - [ ] iOS/watchOS Simulator
   - [ ] Real iPhone + Apple Watch
   - [ ] Just the Watch simulator

2. **What's your Xcode version?**
   - Xcode 14.0+ is required for watchOS widgets

3. **Did you add App Groups through:**
   - [ ] Xcode UI (Signing & Capabilities)
   - [ ] Manually editing entitlements files
   - [ ] Both

---

### **Step 2: Remove App Groups Temporarily**

Let's test if App Groups is causing the issue:

1. **For each target**, go to **Signing & Capabilities**
2. **Remove** the App Groups capability (click the - button)
3. **Clean** (Cmd+Shift+K) and **rebuild**
4. Try installing again

**Does it install now?**
- ✅ **YES** → The issue is with App Groups configuration (go to Step 3)
- ❌ **NO** → There's a deeper code signing issue (go to Step 4)

---

### **Step 3: Re-add App Groups Correctly**

If removing App Groups fixed installation, add it back properly:

#### **3A: Add to Main App First**

1. Select **Sheaf** (main app) target
2. **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Click **+** under App Groups
6. Enter: `group.systems.lupine.sheaf`
7. Make sure it's **checked**

#### **3B: Add to Watch App**

1. Select **SheafWatch** target
2. **Signing & Capabilities** tab
3. Add **App Groups** capability
4. **Use the same group**: `group.systems.lupine.sheaf`

#### **3C: Add to Widget Extension**

1. Select **SheafWatchWidgetExtension** target
2. **Signing & Capabilities** tab
3. Add **App Groups** capability
4. **Use the same group**: `group.systems.lupine.sheaf`

#### **3D: Verify Bundle IDs**

Make sure your bundle identifiers follow this pattern:

```
Main App:       com.yourcompany.sheaf
Watch App:      com.yourcompany.sheaf.watchkitapp
Widget:         com.yourcompany.sheaf.watchkitapp.widgetextension
```

**The widget MUST be a sub-bundle of the watch app!**

---

### **Step 4: Deep Code Signing Reset**

If the problem persists, completely reset code signing:

#### **4A: Remove All Provisioning Profiles**

1. In Xcode, go to **Preferences** → **Accounts**
2. Select your Apple ID
3. Click **Download Manual Profiles**
4. Close Xcode completely

5. In Finder, navigate to:
   ```
   ~/Library/MobileDevice/Provisioning Profiles/
   ```

6. **Delete all files** in this folder

7. **Reopen Xcode**

#### **4B: Reset Signing for Each Target**

For **EACH** target (Main, Watch, Widget):

1. **Build Settings** → Search for "Code Signing"
2. Set these to **blank/default**:
   - Code Signing Identity → (Automatic)
   - Provisioning Profile → (Automatic)

3. Go to **Signing & Capabilities**
4. **Uncheck** "Automatically manage signing"
5. **Wait 5 seconds**
6. **Re-check** "Automatically manage signing"
7. Select your **Team** from the dropdown
8. Wait for Xcode to finish (you'll see "Provisioning profile [name] downloaded")

#### **4C: Clean Everything**

```bash
# In Terminal, navigate to your project directory
cd /path/to/your/project

# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Clean build
xcodebuild clean
```

Or in Xcode:
- **Product** → **Clean Build Folder** (hold Option key, then Shift+Cmd+K)

---

### **Step 5: Simulator-Specific Fixes**

If you're using the **simulator**:

#### **Option A: Reset Specific Simulator**
1. Open Simulator app
2. **Device** → **Erase All Content and Settings**

#### **Option B: Delete and Recreate Simulator**
1. In Xcode: **Window** → **Devices and Simulators**
2. Select your simulator
3. Click **-** to delete it
4. Click **+** to create a new one

---

### **Step 6: Check for Widget Extension Issues**

#### **6A: Verify Target Dependencies**

1. Select your project (not a target) in the navigator
2. Select the **Watch App** target
3. Go to **Build Phases** → **Dependencies**
4. Make sure **SheafWatchWidgetExtension** is listed
5. If not, click **+** and add it

#### **6B: Check Extension Point**

1. Select **SheafWatchWidgetExtension** target
2. Go to **Info** tab
3. Look for **NSExtension** section
4. Verify:
   ```
   NSExtensionPointIdentifier = com.apple.widgetkit-extension
   ```

---

### **Step 7: Try Without Widget Extension**

Let's test if the widget extension itself is the problem:

1. **Edit your scheme**:
   - **Product** → **Scheme** → **Edit Scheme**
   - Under **Build**, find **SheafWatchWidgetExtension**
   - **Uncheck** it temporarily

2. **Clean and build** without the widget

3. **Does it install now?**
   - ✅ **YES** → The widget extension has a configuration problem
   - ❌ **NO** → The issue is with the main/watch app

---

### **Step 8: Create Minimal Test Widget**

If the widget is the problem, let's create a minimal version to test:

<function_calls>
<invoke name="str_replace_based_edit_tool">
<parameter name="command">view