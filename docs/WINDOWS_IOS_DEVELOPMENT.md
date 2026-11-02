# iOS development from Windows

Edit `apps/ios/LockIn` in VS Code. Commit and push a branch containing the source and workflow; GitHub Actions generates the Xcode project from `apps/ios/project.yml` and runs unsigned simulator tests on macOS. Generated `.xcodeproj` files are not the source of truth.

From PowerShell in the repository:

```powershell
gh auth status
gh run list --branch ios/native-clock-ci --limit 5
gh run watch RUN_ID --exit-status
gh run view RUN_ID --log-failed
gh run download RUN_ID --name ios-native-results --dir .local/ios-results
```

Replace RUN_ID with the run number shown by the list command. The artifact may contain simulator screenshots, an xcresult bundle, build logs, and a simulator .app. The .app cannot be installed on an iPhone.

## Physical-device and distribution preparation

The simulator CI is unsigned and produces neither a signed archive nor an iPhone-installable IPA. The current bundle ID `com.lockin.focus` is a development placeholder: its availability and ownership have not been checked.

1. Choose a unique bundle ID under the owner's Apple Developer team. For TestFlight or App Store distribution, create a matching App Store Connect app record. Choose it carefully: Apple does not allow changing the record's bundle ID after the first upload.
2. On authorized remote macOS infrastructure, generate the project with XcodeGen, select the LockIn target, and configure the team and automatic signing. For registered-device development, use the team's development provisioning and register the test device as needed. For automated signing, use the CI provider's secure credential storage; do not put team credentials, certificates, private keys, provisioning profiles, or API keys in Git.
3. Before archiving, set and verify the release version, build number, final app icon, capabilities, bundle identifier, and signing settings. The repository's generated simulator app and current placeholder identity are not evidence of release readiness.
4. Create a Release archive for a generic iOS device on the remote Mac and validate its signing. Export a development build for a registered device or, only with explicit authorization, upload an appropriate distribution archive to App Store Connect for TestFlight. XcodeGen regenerates the project, so changes made only in Xcode's generated project must be translated back into a safe, reproducible configuration before regeneration.

Apple's references: [prepare an app for distribution](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution) and [distribute for beta testing and releases](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases). No signing, archive, upload, TestFlight distribution, or App Store release has been configured or verified here.

Alternatively use `./scripts/ios-ci.ps1 -Action check`, `-Action list`, `-Action watch -RunId 123`, `-Action errors -RunId 123`, or `-Action download -RunId 123`. GitHub only permits manual dispatch after the workflow exists on the default branch; pushing a change matching its path filter can trigger the branch workflow in the meantime.

Simulator screenshots do not verify Xcode previews or physical-device behavior. See PROJECT_STATUS.md for current evidence.
