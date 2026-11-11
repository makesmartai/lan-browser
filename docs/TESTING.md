# Manual testing

Automated checks run with `Scripts/check.sh`; see the [README](../README.md#testing). The checks below are on-device checks. They need WebKit, a real network, and the Local Network permission, so they can’t run in the automated checks.

## Settings and first launch

- From the bookmark screen, open **Settings** (gear). Verify the privacy policy is readable offline and that **Ask for Help or Report a Problem** opens GitHub Issues.
- Run **Browser Check** offline, save the sample file, and open it in Files.
- Sign in to a test website, then use **Clear Cookies & Website Data** in Settings. Confirm the website session is signed out, all tabs close except one blank tab, and bookmarks and exported files remain.
- A fresh install shows only the notice and starts with no bookmarks. Open **Settings › Public Wi-Fi**, tap **Add Wi-Fi Sign-In Bookmark**, confirm it appears and the button is then disabled. Open it and confirm [http://wifi.makesmart.ai/](http://wifi.makesmart.ai/) loads over HTTP. On a captive network, confirm the sign-in page appears instead. With Local Network Features on, confirm the Wi-Fi Sign-In row shows no status dot and keeps the fallback network icon (no icon is fetched). To reset, delete the app, or run `defaults delete com.jesse.lanbrowser trustedNetworkNoticeAccepted` and remove `bookmarks.json` from the app’s Application Support folder.
- First launch shows the “For Trusted Home Networks” notice once. Tap **I Understand**, force-quit, relaunch, and confirm it doesn’t return.
- Test with the keyboard visible, in landscape, in dark mode, and with larger system text.

## Browsing and tabs

- Navigate between pages, and check Back, Forward, Reload, Stop, and swipe navigation. A new-window link should open in a new tab.
- Enter an HTTPS page and test a server’s HTTP-to-HTTPS redirect. The address bar should reflect the resulting address.
- Tabs: tap a bookmark and confirm it opens in a new tab, and that opening one from a blank tab fills that tab. Create and close tabs from the Tabs switcher and from the Tabs button’s long-press menu. Set **Open Bookmarks In** to Current Tab and confirm a bookmark replaces the current page.
- Return to the list: with **Open Bookmarks In** set to New Tab, open a discovered device, tap **Done**, and confirm the list shows and the tab count is back to what it was before the tap. Repeat with **Back**. With Current Tab, confirm Done and Back show the list in the same tab. On iPhone, confirm the navigation bar with Done appears only on these pages and the page title is shown.
- Open a few tabs with some history, force-quit, and relaunch. The tabs should return, and a restored tab should load only when you switch to it. Turn **Restore Tabs on Launch** off, relaunch, and confirm tabs are not restored.

## Bookmarks

- Add a home-service bookmark such as `192.168.1.20:8080`, open it, and verify the service loads over HTTP.
- Add, edit, reorder, and delete bookmarks. Force-quit and relaunch: the edited list should survive, and the app should open bookmarks. Deleting every bookmark should leave an empty list after relaunch.

- Save `http://fixture.local`, then try `HTTP://FIXTURE.local:80/`: Add should show the existing bookmark for editing. Editing a different bookmark to that URL must show an error. Different schemes, paths, query strings and fragments remain separate.
- Seed duplicate URLs in `bookmarks.json`, relaunch, and confirm only the first entry remains in its original position. Check the adjacent `bookmarks-before-deduplication-<UUID>.json` backup contains the original file.
- With Local Network Features off, save a fixture bookmark and confirm its icon appears without delaying Save. Denied Local Network permission must still allow saving with the fallback symbol. Reopen the list and relaunch: the cached icon should remain without icon requests.
- Save bookmarks from Bonjour and a confirmed port scan. Stop their servers, refresh the scan, cancel another scan, clear results, and turn discovery off. Every saved bookmark must remain after relaunch.
- Check bookmark and discovery icons with status dots on iPhone and iPad, including large text and dark mode. Scan results with icons should transfer those icons to newly saved bookmarks.
- Use `/icons/relative`, `/icons/fallback`, `/icons/missing`, `/icons/malformed`, `/icons/oversized`, `/icons/redirect`, `/icons/external`, and `/icons/delayed` on the fixture. Valid icons appear; failures use the network symbol. Check server logs for no requests to the external icon destination. Delete a bookmark or change its URL during a delayed response; the late icon must not restore or alter it. Cancel a scan or background the app during delayed responses; old results must not reappear.
- A self-signed HTTPS site can still open as before, but its icon must use the fallback because icon fetching does not override certificate trust.

## Errors and certificates

- Visit an unreachable address, then use **Edit Address** or **Retry** to recover. Tap **Diagnose** and confirm the failing step and advice make sense. Try a closed port, a misspelled `.local` name, and a self-signed HTTPS device.
- Open a self-signed HTTPS device on your network, such as a router or NAS at `https://YOUR_DEVICE_LAN_IP/`. Confirm the page opens with the red “!” strip, and that the certificate sheet shows its SHA-256 fingerprint.
- Open [https://self-signed.badssl.com/](https://self-signed.badssl.com/) and confirm it is still rejected with the system’s normal error.
- Tap **Diagnose** on an `http://` address that redirects to `https://`, such as `http://YOUR_DEVICE_LAN_IP/`. Confirm the Web Server step lists both hops.

## Local network features

- Turn on **Local Network Features** from the bookmark-list card. Confirm the Local Network prompt appears, then **Scan This Network?** lists **Common Web Apps (22 ports)**, **Custom** (or **Set Up Custom Scan…** before Custom Scan Ports has been opened once), **Standard Web (Ports 80 and 443)**, **Bonjour Only**, and **No Scan**. Each port-scan choice shows its port count, address count and worst-case time.
- Choose **Bonjour Only** on a clean install. The sheet should close before the scan starts. **On This Network** should then list devices that advertise a web page, **+** should save one as a bookmark, and status dots should turn green or red. The scan line should end with “Bonjour” and show no port count.
- Clear Discovered Services, turn the feature off, then turn it on again with no saved scan. **Scan This Network?** should appear again. Choose **No Scan**: nothing should start, and On This Network should stay empty.
- With a saved scan present, turn the feature off and on again. **Scan This Network?** should not appear.
- Clear Discovered Services, turn the feature off, then turn it on from **Settings**. **Scan This Network?** should appear over Settings. Choose **Standard Web** and confirm the sheet closes smoothly before progress starts.
- Relaunch the app. The saved scan should appear with its scan time, and no new scan should start. The circular arrow on On This Network, or a pull down on the bookmark list, should ask which scan to run: **Common Web Apps (22 ports)**, **Custom** (or **Set Up Custom Scan…** before Custom Scan Ports has been opened once), **Standard Web (Ports 80 and 443)**, or **Bonjour Only**. There is no **No Scan** choice there. Cancel should start nothing. On a Mac, use the circular arrow, since there is no pull down. Editing Custom Scan Ports in Settings never starts a scan.
- Deny the permission in the Settings app (System Settings on a Mac) and confirm the list and diagnostics explain how to turn it back on. Turn the switch off and confirm the list and dots disappear.
- Compare the scan line after a Bonjour Only scan with the one after a Common Web Apps scan. The first should end with “Bonjour” and the second with “Bonjour + 22 ports”.
- Tap the circular arrow and choose **Common Web Apps (22 ports)**. The menu closes, and then the scan starts. Progress should appear with a **Cancel** button, and web apps that don’t advertise over Bonjour should be listed with a “port scan” tag. Relaunch the app: the saved results should appear with their scan time, and no new scan should start. Start another scan and tap **Cancel** partway through. The previous list should remain.
- Run a web server on port 8888 on a host in the confirmed range that silently drops connections to 80 and 443 and does not advertise Bonjour. Choose **Common Web Apps** from the circular arrow. The service must appear after the scan finishes, even though both standard web ports time out. **Standard Web** must not probe 8888. Confirm progress counts every selected port on every address; allow several minutes on large ranges. Choosing **Bonjour Only** runs Bonjour only and turns the port scan off.
- Rename a device from Page Info (ⓘ), then rename one from a bookmark’s long-press menu with **Rename Device…**. Confirm every bookmark on that host updates. Tap **+** on a discovered device and confirm the new bookmark uses a `.local` URL.
- Check bookmark/discovery labels and Page Info endpoint details with implicit HTTP/HTTPS ports, explicit port 8888, a remembered IP and IPv6. Every displayed endpoint includes its port, including 80 and 443; IPv6 uses brackets. Renaming a device keeps its port visible.
- Open **Settings › Local Network › Custom Scan Ports**. The list should start with the 22 Common Web Apps ports, and the footer should show the total.
- Enter `8000-8010` in the field at the top and add it. The list should show one row, 8000-8010. Entering the same range with an en dash (`8000–8010`) or with “to” (`8000 to 8010`) should not add a second row.
- Add `8005-8020`. The list should show one merged row, 8000-8020, not two overlapping rows.
- Tap the 8000-8020 row, change it to `8000-8030`, and save. The row should update, and no second row should appear.
- Delete rows one at a time: swipe one left, use **Edit**, and use the row’s menu.
- Enter `1-2000`. A message should explain the 1,024-port limit, and the list should not change. Enter an invalid entry such as `70000` or `9-3`. A clear message should explain it, and the list should not change.
- Tap ••• and choose **Reset to Common Web Apps**, then confirm the list returns to the 22 ports. Choose **Remove All Ports**. Custom should disappear from the scan sheet and from the circular arrow menu. Reset to bring it back.
- On Wi-Fi with Local Network Features on, the footer should show the connection count and worst-case time. Editing ports must not start a scan: On This Network should not change while you edit.
- Choose **Custom** from the circular arrow. The scan should use the saved ports, and its scan line should read “Bonjour + custom ports”.
- On a fresh install (or after `defaults delete com.jesse.lanbrowser customScanPortsVisited`), choose **Set Up Custom Scan…** from **Scan This Network?**. Settings should open on Custom Scan Ports, and no scan should start. Go back, choose **Custom** from the circular arrow, and confirm the scan starts directly.
- To test discovery without a home server, use the test fixture described below.

## Downloads

- Download a file, choose an **On My iPhone/iPad** or **iCloud Drive** destination, and open it in Files. Download the same name twice to check the system’s conflict handling. Cancel a Save to Files picker and verify browsing still works.
- Test a failed download, a file from a logged-in service if available, and multiple downloads. Each successful download should get its own destination picker.

## Test fixture

`Tests/serve_fixture.py` is a small local server for redirects, download links, attachment responses, blob downloads, new-window links, and JavaScript dialogs. It serves only generated test pages and files.

```sh
python3 Tests/serve_fixture.py
```

Keep Terminal running and, from another device on the same Wi-Fi such as an iPhone or iPad, open `http://YOUR_MAC_LAN_IP:8889/`. Allow incoming connections if macOS asks. Stop the server with Control-C.

To test discovery without a home server, advertise the fixture from the Mac over Bonjour:

```sh
dns-sd -R "LAN Fixture" _http._tcp local 8889
```

After a scan with **Local Network Features** on, the fixture should appear in **On This Network**.

## iPad

- At full width, such as landscape or the full iPad window, check the top bar: Back and Forward on the left, the address field in the middle, and Reload, Page Info, Bookmarks and Tabs on the right. The bottom toolbar should not appear. On the bookmark list, **Edit** sits next to Back and Forward, and **+** and **Settings** are on the right.
- Open Split View or Slide Over with another app. Confirm the bottom toolbar returns and the address text you entered is still there. Return to full width and confirm the top bar comes back.
- Rotate through all four orientations, including upside down, with a page loaded and with the bookmark list showing. Check that the layout fits and the top bar or bottom toolbar stays usable.
- With a hardware keyboard, try each shortcut: ⌘L, ⌘T, ⌘W, ⌘R, ⌘., ⌘[, ⌘], ⌘D, ⌘⇧\, and ⌘,. Confirm each does what its name says.
- Open the tab overview with several tabs. It should show more columns than on iPhone.
- Open Page Info, Settings, the bookmark editor and the rename alert. Check that the sheets and alerts fit the iPad width and look right in light and dark mode.

## Mac (Designed for iPad, Apple silicon)

Run the app on a Mac with Apple silicon. Intel Macs are not supported. In Xcode, choose **My Mac (Designed for iPad)** as the run destination and press **⌘R**.

- Launch the app and confirm the top bar shows at full width.
- Turn on **Local Network Features**. Confirm the Local Network prompt appears once. Then deny access in **System Settings › Privacy & Security › Local Network**, open a local address with **Why can’t I connect?**, and confirm the advice points to that System Settings path. The advice should have no **Open Settings** button. Turn access back on in System Settings.
- With the fixture server and `dns-sd` running as described above, tap the circular arrow on On This Network and choose **Bonjour Only**. Confirm **LAN Fixture** appears in **On This Network**. There is no pull down on a Mac.
- With both Ethernet and Wi-Fi connected, tap the circular arrow and choose **Common Web Apps**. The scan starts once you choose it. Compare the addresses it reaches with the home network shown for Ethernet and Wi-Fi in **System Settings › Network**. Tap **Cancel** if you do not want it to finish.
- Open a self-signed HTTPS device on your network. Confirm the page opens with the red “!” strip, and that the certificate sheet shows its SHA-256 fingerprint.
- Download a file and confirm the Save to Files panel appears. Choose a folder, then check that the file saved there.
- With two or more tabs, press ⌘W and confirm it closes the current tab, not the window. With one tab, confirm the window behavior is what you expect. Check the other shortcuts from the iPad list above.
- Resize the window narrow, such as beside another window, and confirm the bottom toolbar appears. Widen it again and confirm the top bar returns.
- After adding a bookmark and opening a few tabs, check the app data in `~/Library/Containers/com.jesse.lanbrowser/Data/Library/Application Support/LANBrowser/`. The files there include `bookmarks.json` and `tabs.json`.

## Saved passwords

- Focus website username and other text fields on iPhone and iPad: the first character must not be capitalized automatically. Repeat in a dynamically inserted form, an embedded frame, a JavaScript prompt and the native bookmark-title and rename fields. Manually using Shift must still allow capitals, and existing field values must remain unchanged.
Run `node Tests/password_capture_checks.js` and `node Tests/password_autofill_checks.js` for the form-detection and AutoFill checks (no packages required). The fixture’s **Password saving** link opens a POST login form that discards submitted values and redirects back to itself; use made-up credentials.

- On a fresh install, confirm **Settings > Offer to Save Passwords** is on. Submit a standard username/password login over HTTP, HTTPS and self-signed local HTTPS. Confirm **Save Password?** identifies the original scheme, host, port and username, including when the login redirects immediately.
- Choose **Not Now** and check **Saved Passwords** stays empty. Submit again and choose **Save**. Relaunch; reveal the saved entry and verify both values. Change the password and save again; confirm the entry is updated. Submit unchanged credentials again; the offer must appear again.
- With an existing saved login, submit a different password for the same username and address, then choose **Not Now**. Relaunch and reveal the saved entry: the old password must remain. Repeat and choose **Save**: the new password must replace it. A different username at the same address saves as a separate account and leaves the old account intact.
- Submit using the keyboard, a normal submit button and a form-less JavaScript login button. A click and its submit event must produce one prompt. Test dynamically inserted forms and a new-window tab. Embedded frames, HTTP authentication dialogs and some custom forms are unsupported.
- Test password-only forms, email usernames, Unicode credentials, IPv6 hosts and two accounts on the same service. HTTP/HTTPS and different ports must keep distinct entries. Empty passwords and new-password or multi-password registration forms must not offer to save.
- Toggle **Offer to Save Passwords** off, return to an already loaded page and submit: no offer. Relaunch and confirm it stays off. Turn it on again and retry. Previously saved entries must remain.
- Reveal a password, background the app and return: it must be hidden. Delete an entry using its swipe action and relaunch: it must be gone. Clear website data and confirm saved passwords remain. Confirm credentials do not appear in the app’s JSON files or preferences.
- Verify a background tab cannot trigger an offer, changing tabs or backgrounding dismisses a pending offer, and site scripts cannot call the isolated password bridge. Confirm that filling only occurs in the selected foreground tab, for the exact saved scheme, host and port.
- Check the save alert and Saved Passwords on iPhone and iPad with larger text and on Mac (Designed for iPad). Check failed Keychain operations show an error rather than claiming a save succeeded.

- With **AutoFill Saved Passwords** on (the default), save made-up credentials, leave the login page and return. Confirm both fields fill automatically on HTTP, HTTPS and a self-signed local HTTPS page; the form must not submit itself. Repeat after relaunch and with a dynamically inserted form.
- Save two usernames for one origin. A blank form should fill the most recently saved account. Enter the other saved username; its password should fill. An unknown username must not receive another account’s password. Changing an automatically filled username must clear its old automatic password. A password you type or clear manually must not be overwritten.
- Turn **AutoFill Saved Passwords** off and reload: fields must stay empty, while offers to save remain on. Turn save offers off independently: saved entries can still fill while AutoFill is on. Confirm embedded frames, hidden forms and registration forms do not receive credentials. Test a slow page load while typing and while navigating to a different host; a late reply must not overwrite input or cross origins.
- Debug builds emit fixed event names and Keychain status codes under subsystem `com.jesse.lanbrowser`, category `passwords`. No usernames, passwords, hosts or page text are included in these password diagnostics. `Tests/PasswordSaveChecks.swift` is a standalone simulator app that checks real Keychain writes, dismissal before Save, Not Now, replacements, native WebKit AutoFill, origin separation, the AutoFill setting and dynamically inserted forms. It uses a loopback fixture on port 8893.

### Favicon request checks

`Scripts/check_favicons.sh` builds the native favicon and discovery code for macOS and checks bookmark/discovery storage isolation without network requests. For integration coverage, start the normal fixture plus a second fixture with a root favicon:

```sh
python3 Tests/serve_fixture.py --port 8890 --fallback-icon
```

With both servers running, run:

```sh
Scripts/check_favicons.sh http://127.0.0.1:8889 http://127.0.0.1:8890
```

This additionally exercises enabled discovery refresh/cancellation, direct icon requests, relative links, same-origin redirects, chunked responses, malformed and oversized images, cancellation of shared requests, deletion during a pending request, and the root favicon fallback. The default fixture has no root icon so failure cases use the network symbol; `--fallback-icon` enables `/favicon.ico` for the fallback check.
