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

For physical-device builds, an Apple Developer account, unique bundle identifier, signing team and suitable provisioning are required. Configure automatic signing in Xcode on a Mac or configure secure CI signing credentials through the chosen CI service. Keep certificates, private keys and App Store Connect keys out of Git. A signed archive, TestFlight upload and App Store release are not configured or authorized by this workflow.

Alternatively use `./scripts/ios-ci.ps1 -Action check`, `-Action list`, `-Action watch -RunId 123`, `-Action errors -RunId 123`, or `-Action download -RunId 123`. GitHub only permits manual dispatch after the workflow exists on the default branch; pushing a change matching its path filter can trigger the branch workflow in the meantime.

Simulator screenshots do not verify Xcode previews or physical-device behavior. See PROJECT_STATUS.md for current evidence.
