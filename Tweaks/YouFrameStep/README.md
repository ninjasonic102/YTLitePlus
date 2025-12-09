# YouFrameStep

A frame-by-frame video control tweak for YTLitePlus that allows precise video navigation.

## Features

- **Frame-by-frame forward/backward**: Move through video one frame at a time
- **Automatic frame rate detection**: Attempts to detect actual video frame rate from metadata
- **Keyboard support**: Use arrow keys (←/→) or comma/period keys (,/.) for frame stepping
- **Automatic pause**: Video automatically pauses during frame stepping for precise control
- **Fallback frame rate**: Uses 30 FPS as default when detection fails

## Usage

### Settings
1. Go to YouTube Settings → YTLitePlus → Video Controls Overlay Options
2. Enable "Frame-by-Frame Controls"

### Controls
- **Keyboard (External)**: 
  - Left Arrow or Comma (,): Step backward one frame
  - Right Arrow or Period (.): Step forward one frame
- **On-screen buttons**: Frame step buttons appear in the video player overlay when enabled

### Technical Details
- Supports videos at 15-120 FPS
- Frame stepping automatically pauses playback for precision
- Frame rate detection uses AVAssetTrack metadata when available
- Falls back to 30 FPS default for compatibility

## Implementation

The tweak hooks into:
- `YTPlayerViewController` for core frame stepping functionality
- `YTMainAppControlsOverlayView` for on-screen button integration
- `UIApplication` for keyboard event handling
- Video overlay system for UI button placement

## Frame Rate Support

| Video Type | Frame Rate | Notes |
|------------|------------|-------|
| Standard | 30 FPS | Default fallback |
| HD/4K | 30-60 FPS | Auto-detected from metadata |
| High Frame Rate | 60-120 FPS | Auto-detected when available |
| Film/Cinema | 24 FPS | Auto-detected |

## Compatibility

- iOS/iPadOS 14.0+
- YouTube app (version varies with YTLitePlus)
- External keyboard support for iPad
- Works with all video qualities and formats