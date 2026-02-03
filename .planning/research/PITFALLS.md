# Domain Pitfalls

**Domain:** Flutter cross-platform phone sync (Android data extraction + local network sync)
**Researched:** 2026-02-03
**Confidence:** MEDIUM-HIGH (verified against official docs and community issues)

## Critical Pitfalls

Mistakes that cause rewrites, Play Store rejection, or major architectural issues.

---

### Pitfall 1: Google Play Store SMS/Call Log Permission Rejection

**What goes wrong:** App gets rejected from Play Store or removed after publishing because it requests READ_SMS, READ_CALL_LOG, or WRITE_CALL_LOG permissions without being the default handler.

**Why it happens:** Google severely restricts these permissions to apps that serve as the default SMS/Phone/Assistant handler. Most utility apps (including sync tools) do NOT qualify for these permissions under current policy.

**Consequences:**
- App rejected during Play Store review
- App removed from Play Store post-publication
- Must rebuild core functionality or distribute outside Play Store

**Prevention:**
1. **Do NOT publish to Play Store** if you need SMS/call log access - distribute via APK sideloading, F-Droid, or enterprise distribution
2. If Play Store distribution is required, use alternative APIs:
   - SMS Retriever API for verification (not applicable here)
   - Intents to share via default SMS app (not applicable here)
3. For this project: **Plan for APK distribution from the start** - update documentation, create self-update mechanism

**Detection (warning signs):**
- Planning Play Store submission with SMS/call log features
- Not checking Google's "Use of SMS or Call Log permission groups" policy early
- Assuming "utility app" qualifies for exception

**Phase to address:** Phase 1 (Foundation) - decide distribution strategy before any development

**Confidence:** HIGH - verified against [Google Play Console Help](https://support.google.com/googleplay/android-developer/answer/10208820)

---

### Pitfall 2: Incremental Sync Missing Deleted Records

**What goes wrong:** Incremental sync based on timestamps misses records that were deleted on the phone. The desktop shows "ghost" records that no longer exist on the device.

**Why it happens:** Standard incremental sync queries "records modified since timestamp X" - but deleted records have no modification timestamp. Without tombstone tracking or full reconciliation, deletions are invisible.

**Consequences:**
- Data inconsistency between phone and desktop
- User confusion when exported Excel has outdated contacts/calls
- No way to know what was deleted without full resync
- Grows worse over time as more deletions accumulate

**Prevention:**
1. **Implement tombstone awareness:** Track what record IDs existed in last sync, compare against current IDs
2. **Periodic full reconciliation:** Every N syncs, do a full ID comparison (not full data transfer)
3. **Store sync snapshots:** Keep list of record IDs from last sync to detect removals
4. **Consider hybrid approach:** Incremental for additions/modifications, ID-set comparison for deletions

**Detection (warning signs):**
- Sync implementation only considers "modified since" timestamp
- No tracking of previously-synced record IDs
- Unit tests only cover additions and updates, not deletions

**Phase to address:** Phase 3 (Sync Protocol) - must be designed into sync architecture from the start

**Confidence:** MEDIUM-HIGH - verified via [Couchbase Tombstones documentation](https://docs.couchbase.com/sync-gateway/current/manage/managing-tombstones.html) and [Salesforce Mobile SDK incremental sync docs](https://developer.salesforce.com/docs/platform/mobile-sdk/guide/entity-framework-native-inc-sync.html)

---

### Pitfall 3: Android Content Provider Cursor Memory Exhaustion

**What goes wrong:** Querying SMS, call logs, or contacts with large datasets causes OutOfMemory errors or severe performance degradation. App crashes or hangs during sync.

**Why it happens:** SQLiteCursor uses CursorWindow (2MB buffer). For large result sets, each page requires re-running query from position 0 and skipping rows - O(n^2) behavior. Call logs with 50,000+ entries or SMS with 100,000+ messages hit this hard.

**Consequences:**
- App crashes with OOM errors
- Sync takes exponentially longer as dataset grows
- Battery drain from inefficient queries
- Users with extensive history cannot use the app

**Prevention:**
1. **Always paginate queries:** Use LIMIT and OFFSET, fetch in chunks of 100-500 records
2. **Use ContentPager** (Android O+) for background paging with reduced CursorWindow swaps
3. **Close cursors immediately:** Always close cursors after processing each page
4. **Stream processing:** Process each page before fetching next, don't accumulate in memory
5. **Add progress reporting:** Show user progress during large syncs

**Detection (warning signs):**
- Querying all SMS/calls without LIMIT clause
- Accumulating all records in memory before processing
- Not testing with large datasets (10,000+ records)
- Ignoring "Could not allocate CursorWindow" errors in testing

**Phase to address:** Phase 2 (Android Data Access) - implement pagination from day one

**Confidence:** HIGH - verified via [Android Developers Medium article on large database queries](https://medium.com/androiddevelopers/large-database-queries-on-android-cb043ae626e8)

---

### Pitfall 4: Platform Channel Type Mismatch Runtime Crashes

**What goes wrong:** App crashes at runtime with `PlatformException` or null pointer errors when passing data between Dart and native Android code.

**Why it happens:** Platform channels have no compile-time type validation. Dart expects one type, Kotlin/Java sends another. The mismatch only appears at runtime.

**Consequences:**
- Sporadic crashes in production
- Difficult to debug (errors happen across language boundary)
- Silent data corruption if types coerce unexpectedly

**Prevention:**
1. **Document the contract:** Create explicit documentation of method names, argument types, return types
2. **Use only StandardMessageCodec types:** int, double, String, bool, List, Map with JSON-safe contents
3. **Validate on both sides:** Check types before using on native side, use generics on Dart side
4. **Create integration tests:** Test actual platform channel calls, not just mocked versions
5. **Consider code generation:** Tools like Pigeon generate type-safe platform channel code

**Detection (warning signs):**
- No documentation of platform channel contract
- Passing complex objects without explicit serialization
- Tests mock the platform channel instead of testing actual calls
- Channel name defined in multiple places (can drift)

**Phase to address:** Phase 2 (Android Data Access) - establish patterns before building all data accessors

**Confidence:** HIGH - verified via [Flutter official platform channels documentation](https://docs.flutter.dev/platform-integration/platform-channels)

---

### Pitfall 5: mDNS Discovery Fails on Real Devices / Different Platforms

**What goes wrong:** Local network discovery works in simulator/emulator but fails on real devices, or works on one platform but not others.

**Why it happens:** Multiple platform-specific issues:
- iOS: Requires NSLocalNetworkUsageDescription and NSBonjourServices in Info.plist
- macOS 15+: New Local Network Privacy permission required
- Android: Service name must end with a dot
- Windows: No native mDNS, uses socket-based fallback (triggers firewall dialog)
- Real devices have different network conditions than simulators

**Consequences:**
- App appears broken on certain platforms
- Users cannot pair devices
- Works for developer, fails for users

**Prevention:**
1. **Configure all platform permissions early:**
   - iOS: Add NSLocalNetworkUsageDescription and NSBonjourServices to Info.plist
   - macOS: Add com.apple.security.network.server entitlement
   - Android: Ensure service names end with dot
   - Windows: Handle firewall dialog gracefully
2. **Test on real devices:** Each platform, real hardware, real network
3. **Implement fallback:** Manual IP entry as backup when discovery fails
4. **Use established packages:** `nsd` package wraps platform differences

**Detection (warning signs):**
- Only testing in simulators/emulators
- Not configuring Info.plist for iOS local network
- mDNS working in development but not in release builds

**Phase to address:** Phase 4 (Network Layer) - test on all target platforms early

**Confidence:** HIGH - verified via [Flutter GitHub issue #166843](https://github.com/flutter/flutter/issues/166843), [Flutter GitHub issue #177307](https://github.com/flutter/flutter/issues/177307)

---

## Moderate Pitfalls

Mistakes that cause delays, technical debt, or degraded user experience.

---

### Pitfall 6: macOS/Desktop Networking Entitlements Not Configured

**What goes wrong:** Desktop app throws `SocketException: Connection failed (Operation not permitted)` or cannot connect to Android device.

**Why it happens:** macOS apps are sandboxed by default. Without proper entitlements, network operations fail silently or with cryptic errors.

**Prevention:**
1. Add to `macos/Runner/DebugProfile.entitlements` AND `Release.entitlements`:
   ```xml
   <key>com.apple.security.network.client</key>
   <true/>
   <key>com.apple.security.network.server</key>
   <true/>
   ```
2. For Windows: Be prepared to handle firewall prompts on first launch
3. Test release builds (debug builds have different entitlement defaults)

**Detection (warning signs):**
- Network works in debug but fails in release build
- "Operation not permitted" errors on macOS
- Not checking entitlements files

**Phase to address:** Phase 4 (Network Layer)

**Confidence:** HIGH - verified via [Flutter macOS documentation](https://docs.flutter.dev/platform-integration/macos/building), [Code With Andrea tip](https://codewithandrea.com/tips/socket-exception-connection-failed-macos/)

---

### Pitfall 7: Excel Generation Memory Exhaustion with Large Datasets

**What goes wrong:** Generating Excel file with 50,000+ rows causes OutOfMemory error, especially on mobile or web platforms.

**Why it happens:** Excel packages load entire workbook into memory. Large datasets (10MB+ JSON or 50,000+ rows) exceed available memory.

**Consequences:**
- App crashes during export
- Web platform particularly vulnerable (browser memory limits)
- Users with large sync datasets cannot export

**Prevention:**
1. **Use asynchronous save:** `workbook.save()` async method
2. **Always dispose workbooks:** Call `workbook.dispose()` after saving
3. **Consider CSV for very large exports:** Much lower memory overhead
4. **Set row limits with warnings:** Warn users if export exceeds safe thresholds
5. **Chunk processing:** For very large datasets, generate multiple files

**Detection (warning signs):**
- Not calling `dispose()` on workbook objects
- Testing only with small datasets (< 1000 rows)
- Using synchronous file operations for large exports

**Phase to address:** Phase 5 (Export) - test with realistic data volumes

**Confidence:** MEDIUM - verified via [Syncfusion Flutter Widgets issue #448](https://github.com/syncfusion/flutter-widgets/issues/448)

---

### Pitfall 8: Android Permission Dialog Not Showing

**What goes wrong:** `Permission.contacts.request()` returns without showing the permission dialog. User never gets asked, app assumes permission denied.

**Why it happens:** Known issue with flutter-permission-handler on certain Android versions. Dialog doesn't pause app execution, code continues before user responds.

**Prevention:**
1. **Check permission status after request:** Don't assume request showed dialog
2. **Implement retry logic:** If status is still undetermined, prompt user to check settings
3. **Test on multiple Android versions:** Behavior varies by Android version
4. **Show manual instructions:** Guide user to Settings if automatic dialog fails

**Detection (warning signs):**
- Permissions always showing as "denied" without dialog appearing
- Not verifying permission status after request call
- Only testing on one Android version

**Phase to address:** Phase 2 (Android Data Access)

**Confidence:** MEDIUM - verified via [flutter-permission-handler issue #770](https://github.com/Baseflow/flutter-permission-handler/issues/770)

---

### Pitfall 9: Phone + Call Log Permission Coupling (Android 9+)

**What goes wrong:** Requesting phone permission also requests call log permission, confusing users or triggering rejection.

**Why it happens:** On Android 9+, permission groups are handled differently. The permission_handler plugin requests both PHONE and CALL_LOG when requesting phone permission.

**Prevention:**
1. **Request only what you need:** If you only need call log, don't request phone permission
2. **Explain to users:** In permission rationale, explain why both are needed
3. **Test on Android 9+ devices:** This behavior is version-specific

**Detection (warning signs):**
- Users confused by permission requests
- Not testing on Android 9+ specifically

**Phase to address:** Phase 2 (Android Data Access)

**Confidence:** MEDIUM - verified via [flutter-permission-handler issue #115](https://github.com/Baseflow/flutter-permission-handler/issues/115)

---

### Pitfall 10: Flutter Monorepo Melos/Pub Workspace Confusion

**What goes wrong:** Running `flutter pub get` in individual packages breaks dependencies. Builds fail with version conflicts.

**Why it happens:** Melos has been updated to use Dart's pub workspaces. Old tutorials mix outdated Melos concepts with new workspace system. Running pub get manually bypasses workspace resolution.

**Prevention:**
1. **Use `melos bootstrap`** instead of `flutter pub get`
2. **Keep Flutter/Dart updated:** Pub workspaces require newer versions
3. **Follow current Melos documentation:** Avoid tutorials mixing old/new patterns
4. **Define packages via path dependencies:** Let workspace resolve versions

**Detection (warning signs):**
- Running `flutter pub get` in subpackages
- Version conflicts after adding new packages
- Using pre-Melos 3.x tutorials

**Phase to address:** Phase 1 (Foundation)

**Confidence:** MEDIUM - verified via [Medium article on Flutter Monorepo 2025/2026](https://medium.com/@sijalneupane5/flutter-monorepo-from-scratch-2025-going-into-2026-pub-workspaces-melos-explained-properly-fae98bfc8a6e)

---

## Minor Pitfalls

Mistakes that cause annoyance or small rework but are fixable.

---

### Pitfall 11: PIN Pairing Without TLS Vulnerable to Eavesdropping

**What goes wrong:** PIN displayed on one device, entered on other, but data transfer is unencrypted. Attacker on same network can intercept synced data.

**Prevention:**
1. **Use TLS for all data transfer:** Even on local network
2. **PIN establishes trust, TLS provides encryption:** Separate concerns
3. **Consider certificate pinning:** Prevent MITM even with compromised CA
4. **Document security model:** Be clear about threat model and protections

**Detection (warning signs):**
- Sending data over plain HTTP
- Assuming local network is "trusted"
- No encryption layer in protocol design

**Phase to address:** Phase 4 (Network Layer)

**Confidence:** MEDIUM - general security best practice

---

### Pitfall 12: Sync Interrupted Leaves Inconsistent State

**What goes wrong:** User closes app or loses network mid-sync. Partial data synced, but sync state shows "complete." Next sync misses the gap.

**Prevention:**
1. **Checkpoint system:** Track progress incrementally, resume from last checkpoint
2. **Atomic commits:** Only update sync cursor after full batch completes
3. **Transaction rollback:** If interrupted, roll back partial data
4. **Verification step:** After sync, verify record counts match

**Detection (warning signs):**
- Updating sync cursor before data is fully written
- No recovery mechanism for interrupted syncs
- Not testing interruption scenarios

**Phase to address:** Phase 3 (Sync Protocol)

**Confidence:** MEDIUM - verified via general sync architecture patterns

---

### Pitfall 13: iOS Call Log Access Not Possible

**What goes wrong:** Planning iOS version assumes call log access is possible. iOS provides no API for call history.

**Prevention:**
1. **Document iOS limitations upfront:** Call logs are not accessible on iOS
2. **Scope iOS version differently:** Contacts only, or don't build iOS version
3. **Communicate clearly:** Users expect feature parity, manage expectations

**Detection (warning signs):**
- Roadmap shows iOS call log sync
- Not researching iOS capabilities early

**Phase to address:** Phase 1 (Foundation) - scope decisions

**Confidence:** HIGH - iOS platform limitation

---

### Pitfall 14: Android Doze Mode Interrupts Long Syncs

**What goes wrong:** During a large sync (many thousands of records), Android puts app in Doze mode. Network access suspended, sync fails silently.

**Prevention:**
1. **Use foreground service with notification:** Exempt from Doze restrictions
2. **Keep syncs short:** Better to do multiple small syncs than one large one
3. **Handle interruption gracefully:** Detect Doze, inform user, resume later
4. **Consider wake lock:** For critical operations (use sparingly, impacts battery)

**Detection (warning signs):**
- Long-running sync operations without foreground service
- Sync failures on devices with aggressive battery optimization
- Not testing with screen off / app in background

**Phase to address:** Phase 3 (Sync Protocol) - if syncs can run long

**Confidence:** MEDIUM - verified via [Android Doze documentation](https://developer.android.com/training/monitoring-device-state/doze-standby)

---

## Phase-Specific Warnings

| Phase | Likely Pitfall | Mitigation |
|-------|---------------|------------|
| Phase 1: Foundation | Play Store rejection (Pitfall 1) | Decide APK distribution strategy before development |
| Phase 1: Foundation | Monorepo confusion (Pitfall 10) | Use Melos 3.x+ with pub workspaces, never run pub get in subpackages |
| Phase 2: Android Data | Cursor memory issues (Pitfall 3) | Implement pagination from day one |
| Phase 2: Android Data | Platform channel crashes (Pitfall 4) | Document contract, use only standard types |
| Phase 2: Android Data | Permission dialog issues (Pitfall 8, 9) | Test on multiple Android versions |
| Phase 3: Sync Protocol | Missing deleted records (Pitfall 2) | Design tombstone/reconciliation into architecture |
| Phase 3: Sync Protocol | Interrupted sync state (Pitfall 12) | Implement checkpoints and atomic commits |
| Phase 4: Network | mDNS platform differences (Pitfall 5) | Configure all platform permissions, test real devices |
| Phase 4: Network | Desktop entitlements (Pitfall 6) | Configure macOS entitlements for both debug and release |
| Phase 4: Network | Unencrypted transfer (Pitfall 11) | Use TLS even on local network |
| Phase 5: Export | Excel memory exhaustion (Pitfall 7) | Test with large datasets, use async save and dispose |

---

## Sources

### Official Documentation
- [Google Play Console: Use of SMS or Call Log permission groups](https://support.google.com/googleplay/android-developer/answer/10208820)
- [Flutter: Writing custom platform-specific code](https://docs.flutter.dev/platform-integration/platform-channels)
- [Flutter: Building macOS apps](https://docs.flutter.dev/platform-integration/macos/building)
- [Android: Optimize for Doze and App Standby](https://developer.android.com/training/monitoring-device-state/doze-standby)
- [Android: App permissions best practices](https://developer.android.com/training/permissions/usage-notes)

### Community/GitHub Issues
- [flutter-permission-handler issue #115: Phone/Call Log coupling](https://github.com/Baseflow/flutter-permission-handler/issues/115)
- [flutter-permission-handler issue #770: Contact permission dialog not showing](https://github.com/Baseflow/flutter-permission-handler/issues/770)
- [Flutter issue #166843: macOS 15 mDNS permission](https://github.com/flutter/flutter/issues/166843)
- [Flutter issue #177307: mDNS works on simulator but not real device](https://github.com/flutter/flutter/issues/177307)
- [Syncfusion issue #448: OOM on large Excel files](https://github.com/syncfusion/flutter-widgets/issues/448)

### Technical Articles
- [Android Developers Medium: Large Database Queries on Android](https://medium.com/androiddevelopers/large-database-queries-on-android-cb043ae626e8)
- [Couchbase: Managing Tombstones](https://docs.couchbase.com/sync-gateway/current/manage/managing-tombstones.html)
- [Salesforce Mobile SDK: Incremental Syncs](https://developer.salesforce.com/docs/platform/mobile-sdk/guide/entity-framework-native-inc-sync.html)
- [Medium: Flutter Monorepo 2025/2026](https://medium.com/@sijalneupane5/flutter-monorepo-from-scratch-2025-going-into-2026-pub-workspaces-melos-explained-properly-fae98bfc8a6e)
- [Code With Andrea: SocketException on macOS](https://codewithandrea.com/tips/socket-exception-connection-failed-macos/)
