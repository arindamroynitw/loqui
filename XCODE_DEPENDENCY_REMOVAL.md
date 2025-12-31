# Manual Xcode Dependency Removal Steps

**⚠️ IMPORTANT:** The following steps MUST be completed manually in Xcode to remove MLX dependencies.

## Step 1: Remove Package Dependencies

1. Open `Loqui.xcodeproj` in Xcode
2. Select the **Loqui project** (top item in Project Navigator)
3. Select the **Loqui project** (not the target) in the editor
4. Click the **Package Dependencies** tab
5. Remove the following packages:
   - `mlx-swift` (https://github.com/ml-explore/mlx-swift.git)
   - `mlx-swift-lm` (https://github.com/ml-explore/mlx-swift-lm.git)

   To remove: Select each package → click the "−" button at the bottom

## Step 2: Remove Frameworks from Target

1. Select the **Loqui target** (under the project)
2. Go to the **General** tab
3. Scroll to **Frameworks, Libraries, and Embedded Content**
4. Remove the following frameworks:
   - `MLXLLM`
   - `MLXLMCommon`

   To remove: Select each framework → click the "−" button

## Step 3: Verify Removal

1. Click **Product → Clean Build Folder** (Shift+Cmd+K)
2. Click **Product → Build** (Cmd+B)
3. Verify no compilation errors related to MLX

## Step 4: (Optional) Downgrade Deployment Target

If you want to support macOS 13.0 instead of 14.0:

1. Select the **Loqui project**
2. Go to **Build Settings** tab
3. Search for "Deployment Target"
4. Change from `14.6` → `13.0` for both Debug and Release

**Note:** Symbol effects in `MenuBarIconView.swift` require macOS 14.0+, but availability guards are already in place.

## Expected Outcome

After completing these steps:
- ✅ MLX packages removed from Package Dependencies
- ✅ MLXLLM/MLXLMCommon frameworks removed from target
- ✅ Project builds successfully
- ✅ No import errors for MLXLLM or MLXLMCommon
- ✅ Groq cloud API integration working

## Troubleshooting

### If build fails after removal:

1. **"Cannot find type 'MLXLLM'"** → Good! This means old imports are removed
2. **Other errors** → Check that all code changes were applied:
   - `AppState.swift` uses `GroqClient` (not `SpeechCleaner`)
   - `LoquiApp.swift` uses `SettingsView` (not placeholder)
   - New files exist: `LLMError.swift`, `GroqClient.swift`, `ErrorOverlayView.swift`, `SettingsView.swift`

### If Xcode crashes or behaves strangely:

1. Quit Xcode
2. Delete derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData/Loqui-*`
3. Reopen project
4. Clean build folder and rebuild

## Next Steps After Removal

1. **Get Groq API Key:** Visit https://console.groq.com
2. **Configure in App:** Open Settings (Cmd+,) → LLM API tab
3. **Enter API Key:** Paste Groq API key, click Save
4. **Restart App:** Required for API key to take effect
5. **Test:** Press fn key, speak, release, verify transcription works
6. **Verify Latency:** Check console logs for pipeline latency (<4s target)
