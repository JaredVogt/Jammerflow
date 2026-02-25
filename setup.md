# Hammerflow Setup Guide

## Required System Permissions

For Hammerflow to work properly, you need to grant Hammerspoon specific permissions in macOS System Preferences/Settings.

### 1. Full Disk Access

Hammerspoon needs Full Disk Access to watch folders and access files across your system.

**Steps:**
1. Open **System Preferences** (or **System Settings** on macOS Ventura+)
2. Go to **Privacy & Security** → **Privacy**
3. Select **Full Disk Access** from the left sidebar
4. Click the lock icon and authenticate
5. Click the **+** button
6. Navigate to `/Applications` and select **Hammerspoon.app**
7. Ensure the checkbox next to Hammerspoon is checked

### 2. Notifications

Enable notifications to see alerts for file events and other Hammerflow activities.

**Steps:**
1. Open **System Preferences** (or **System Settings** on macOS Ventura+)
2. Go to **Notifications & Focus** (or just **Notifications** on older macOS)
3. Find **Hammerspoon** in the application list
4. Turn on **Allow Notifications**
5. Configure your preferred notification style:
   - **Alerts** (recommended) - stay on screen until dismissed
   - **Banners** - appear briefly then disappear
   - **None** - notifications in Notification Center only

### 3. Accessibility (Already Required)

Note: Hammerspoon typically requests Accessibility permissions on first launch. If you haven't granted this yet:

**Steps:**
1. Open **System Preferences** (or **System Settings** on macOS Ventura+)
2. Go to **Privacy & Security** → **Privacy**
3. Select **Accessibility** from the left sidebar
4. Ensure **Hammerspoon** is in the list and checked

## Verifying Permissions

After granting permissions:
1. Quit Hammerspoon completely (right-click the menu bar icon → Quit)
2. Relaunch Hammerspoon
3. Test that folder watching and notifications work correctly

## Troubleshooting

If features aren't working after granting permissions:
- Restart Hammerspoon
- If issues persist, restart your Mac
- Check the Hammerspoon console for error messages (click the Hammerspoon menu bar icon → Console)

## Privacy Note

These permissions allow Hammerspoon to:
- Monitor file system events in specified folders
- Display system notifications
- Control windows and simulate keyboard/mouse input

Hammerspoon is open source and these permissions are only used for the functionality you configure.