#import <Foundation/Foundation.h>
#import <Foundation/NSString.h>
#import <Foundation/NSTimer.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSPredicate.h>
#import <AvailabilityMacros.h>
#import <string.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <UIKit/UIKit.h>

#import "../YTVideoOverlay/Header.h"
#import "../YTVideoOverlay/Init.x"
#import "../YouTubeHeader/YTColor.h"
#import "../YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h"
#import "../YouTubeHeader/YTMainAppVideoPlayerOverlayView.h"
#import "../YouTubeHeader/YTMainAppControlsOverlayView.h"
#import "../YouTubeHeader/YTPlayerViewController.h"
#import "../YouTubeHeader/QTMIcon.h"
#import "../YouTubeHeader/YTSingleVideoController.h"

#define TweakKey @"YouFrameStep"
#define IS_ENABLED(k) [[NSUserDefaults standardUserDefaults] boolForKey:k]

// Frame rate constants for different video qualities
static const CGFloat kFrameRateDefault = 30.0; // Default to 30 FPS
static const CGFloat kFrameRateHD = 60.0;      // HD videos might be 60 FPS
static const CGFloat kFrameRate24 = 24.0;      // Some videos are 24 FPS
static const CGFloat kFrameRateHigh = 120.0;   // High frame rate videos

@interface YTMainAppVideoPlayerOverlayViewController (YouFrameStep)
@property (nonatomic, assign) YTPlayerViewController *parentViewController;
@end

@interface YTMainAppVideoPlayerOverlayView (YouFrameStep)
@property (nonatomic, weak, readwrite) YTMainAppVideoPlayerOverlayViewController *delegate;
@end

@interface YTPlayerViewController (YouFrameStep)
- (void)frameStepForward;
- (void)frameStepBackward;
- (CGFloat)getVideoFrameRate;
@end

@interface YTMainAppControlsOverlayView (YouFrameStep)
@property (nonatomic, assign) YTPlayerViewController *playerViewController;
- (void)didPressFrameStepForward:(id)arg;
- (void)didPressFrameStepBackward:(id)arg;
@end

@interface YTInlinePlayerBarContainerView (YouFrameStep)
@property (nonatomic, strong) YTInlinePlayerBarController *delegate;
- (void)didPressFrameStepForward:(id)arg;
- (void)didPressFrameStepBackward:(id)arg;
@end

// Add keyboard support interface
@interface UIApplication (YouFrameStep)
@property (nonatomic, readonly) UIWindow *keyWindow;
@end

// Hook into the main video player overlay controller
%hook YTMainAppVideoPlayerOverlayViewController

%property (nonatomic, assign) YTPlayerViewController *parentViewController;

- (void)viewDidLoad {
    %orig;
    self.parentViewController = (YTPlayerViewController *)[self parentViewController];
}

%end

// Hook into the player view controller to add frame stepping functionality
%hook YTPlayerViewController

%new
- (CGFloat)getVideoFrameRate {
    // Use a simple default frame rate to avoid complex video metadata access
    // that might cause selector issues with ML classes
    return kFrameRateDefault;
}

%new
- (void)frameStepForward {
    if (!IS_ENABLED(TweakKey)) return;
    
    CGFloat currentTime = [self currentVideoMediaTime];
    CGFloat frameRate = [self getVideoFrameRate];
    CGFloat frameTime = 1.0 / frameRate; // Time per frame in seconds
    CGFloat newTime = currentTime + frameTime;
    CGFloat totalTime = [self currentVideoTotalMediaTime];
    
    // Don't go past the end of the video
    if (newTime > totalTime) {
        newTime = totalTime;
    }
    
    [self seekToTime:newTime];
    
    // Pause the video for precise frame stepping
    [self pauseVideo];
}

%new
- (void)frameStepBackward {
    if (!IS_ENABLED(TweakKey)) return;
    
    CGFloat currentTime = [self currentVideoMediaTime];
    CGFloat frameRate = [self getVideoFrameRate];
    CGFloat frameTime = 1.0 / frameRate; // Time per frame in seconds
    CGFloat newTime = currentTime - frameTime;
    
    // Don't go before the beginning of the video
    if (newTime < 0) {
        newTime = 0;
    }
    
    [self seekToTime:newTime];
    
    // Pause the video for precise frame stepping
    [self pauseVideo];
}

%end

// Hook into the main controls overlay view to add frame step buttons
%hook YTMainAppControlsOverlayView

%property (nonatomic, assign) YTPlayerViewController *playerViewController;

- (void)setPlayerViewController:(YTPlayerViewController *)playerViewController {
    %orig;
}

- (id)initWithDelegate:(id)delegate {
    if ((self = %orig)) {
        if (IS_ENABLED(TweakKey)) {
            self.playerViewController = (YTPlayerViewController *)delegate;
        }
    }
    return self;
}

- (void)layoutSubviews {
    %orig;
    if (IS_ENABLED(TweakKey)) {
        [self addFrameStepButtons];
    }
}

%new
- (void)addFrameStepButtons {
    if (!self.overlayButtons) {
        self.overlayButtons = [NSMutableDictionary dictionary];
    }
    
    // Create frame backward button
    YTQTMButton *frameBackButton = self.overlayButtons[@"YouFrameStep.frameBack"];
    if (!frameBackButton) {
        frameBackButton = [self createFrameStepButtonWithImageName:@"step_back" selector:@selector(didPressFrameStepBackward:)];
        self.overlayButtons[@"YouFrameStep.frameBack"] = frameBackButton;
        [self addSubview:frameBackButton];
    }
    
    // Create frame forward button
    YTQTMButton *frameForwardButton = self.overlayButtons[@"YouFrameStep.frameForward"];
    if (!frameForwardButton) {
        frameForwardButton = [self createFrameStepButtonWithImageName:@"step_forward" selector:@selector(didPressFrameStepForward:)];
        self.overlayButtons[@"YouFrameStep.frameForward"] = frameForwardButton;
        [self addSubview:frameForwardButton];
    }
    
    // Position the buttons
    CGFloat buttonSize = 44; // Standard button size for touch targets
    CGFloat spacing = 16;
    CGRect bounds = self.bounds;
    
    // Position buttons in bottom right area
    CGFloat rightMargin = 60;
    CGFloat bottomMargin = 100;
    
    frameForwardButton.frame = CGRectMake(bounds.size.width - rightMargin, bounds.size.height - bottomMargin, buttonSize, buttonSize);
    frameBackButton.frame = CGRectMake(bounds.size.width - rightMargin - buttonSize - spacing, bounds.size.height - bottomMargin, buttonSize, buttonSize);
}

%new
- (YTQTMButton *)createFrameStepButtonWithImageName:(NSString *)imageName selector:(SEL)selector {
    YTQTMButton *button = [[%c(YTQTMButton) alloc] init];
    
    // Use system symbols for the icons
    UIImage *buttonImage;
    if ([imageName isEqualToString:@"step_back"]) {
        buttonImage = [UIImage systemImageNamed:@"gobackward"];
    } else {
        buttonImage = [UIImage systemImageNamed:@"goforward"];
    }
    
    if (buttonImage) {
        [button setImage:buttonImage forState:UIControlStateNormal];
    } else {
        // Fallback to text if system images aren't available
        [button setTitle:([imageName isEqualToString:@"step_back"] ? @"◄◄" : @"►►") forState:UIControlStateNormal];
    }
    
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    button.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    button.layer.cornerRadius = 22;
    
    return button;
}

%new
- (void)didPressFrameStepBackward:(id)arg {
    if (self.playerViewController) {
        [self.playerViewController frameStepBackward];
    }
}

%new
- (void)didPressFrameStepForward:(id)arg {
    if (self.playerViewController) {
        [self.playerViewController frameStepForward];
    }
}

%end

// Hook into the inline player bar container for compact player controls
%hook YTInlinePlayerBarContainerView

- (void)layoutSubviews {
    %orig;
    if (IS_ENABLED(TweakKey)) {
        [self addCompactFrameStepButtons];
    }
}

%new
- (void)addCompactFrameStepButtons {
    if (!self.overlayButtons) {
        self.overlayButtons = [NSMutableDictionary dictionary];
    }
    
    // Create compact frame buttons for inline player
    YTQTMButton *frameBackButton = self.overlayButtons[@"YouFrameStep.compactBack"];
    if (!frameBackButton) {
        frameBackButton = [self createCompactFrameStepButtonWithImageName:@"step_back" selector:@selector(didPressFrameStepBackward:)];
        self.overlayButtons[@"YouFrameStep.compactBack"] = frameBackButton;
        [self addSubview:frameBackButton];
    }
    
    YTQTMButton *frameForwardButton = self.overlayButtons[@"YouFrameStep.compactForward"];
    if (!frameForwardButton) {
        frameForwardButton = [self createCompactFrameStepButtonWithImageName:@"step_forward" selector:@selector(didPressFrameStepForward:)];
        self.overlayButtons[@"YouFrameStep.compactForward"] = frameForwardButton;
        [self addSubview:frameForwardButton];
    }
    
    // Position buttons in compact player
    CGFloat buttonSize = 32; // Smaller for compact player
    CGFloat spacing = 8;
    CGRect bounds = self.bounds;
    CGFloat rightMargin = 50;
    CGFloat y = (bounds.size.height - buttonSize) / 2;
    
    frameForwardButton.frame = CGRectMake(bounds.size.width - rightMargin, y, buttonSize, buttonSize);
    frameBackButton.frame = CGRectMake(bounds.size.width - rightMargin - buttonSize - spacing, y, buttonSize, buttonSize);
}

%new
- (YTQTMButton *)createCompactFrameStepButtonWithImageName:(NSString *)imageName selector:(SEL)selector {
    YTQTMButton *button = [[%c(YTQTMButton) alloc] init];
    
    // Use smaller system symbols for compact view
    UIImage *buttonImage;
    if ([imageName isEqualToString:@"step_back"]) {
        buttonImage = [UIImage systemImageNamed:@"gobackward"];
    } else {
        buttonImage = [UIImage systemImageNamed:@"goforward"];
    }
    
    if (buttonImage) {
        // Scale down for compact view
        UIImageConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
        buttonImage = [buttonImage imageWithConfiguration:config];
        [button setImage:buttonImage forState:UIControlStateNormal];
    } else {
        [button setTitle:([imageName isEqualToString:@"step_back"] ? @"◄" : @"►") forState:UIControlStateNormal];
    }
    
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    button.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
    button.layer.cornerRadius = 16;
    
    return button;
}

%new
- (void)didPressFrameStepBackward:(id)arg {
    // Find the player view controller through the view hierarchy
    UIViewController *vc = (UIViewController *)self.delegate;
    while (vc && ![vc isKindOfClass:%c(YTPlayerViewController)]) {
        vc = vc.parentViewController;
    }
    if (vc) {
        [(YTPlayerViewController *)vc frameStepBackward];
    }
}

%new  
- (void)didPressFrameStepForward:(id)arg {
    // Find the player view controller through the view hierarchy
    UIViewController *vc = (UIViewController *)self.delegate;
    while (vc && ![vc isKindOfClass:%c(YTPlayerViewController)]) {
        vc = vc.parentViewController;
    }
    if (vc) {
        [(YTPlayerViewController *)vc frameStepForward];
    }
}

%end

// Hook into the main app to handle keyboard events for frame stepping  
%hook UIApplication

- (void)sendEvent:(UIEvent *)event {
    %orig;
    
    if (!IS_ENABLED(TweakKey)) return;
    
    if (event.type == UIEventTypeKeypress) {
        // Check for arrow key presses (external keyboard support)
        for (UIPress *press in event.allPresses) {
            if (press.phase == UIPressPhaseEnded) {
                // Get the current player view controller
                UIViewController *topVC = self.keyWindow.rootViewController;
                YTPlayerViewController *playerVC = nil;
                
                // Find the player view controller in the view hierarchy
                if ([topVC isKindOfClass:%c(YTPlayerViewController)]) {
                    playerVC = (YTPlayerViewController *)topVC;
                } else {
                    // Search for player view controller in presented view controllers
                    UIViewController *presentedVC = topVC.presentedViewController;
                    while (presentedVC) {
                        if ([presentedVC isKindOfClass:%c(YTPlayerViewController)]) {
                            playerVC = (YTPlayerViewController *)presentedVC;
                            break;
                        }
                        presentedVC = presentedVC.presentedViewController;
                    }
                    
                    // Also check child view controllers
                    if (!playerVC) {
                        for (UIViewController *childVC in topVC.childViewControllers) {
                            if ([childVC isKindOfClass:%c(YTPlayerViewController)]) {
                                playerVC = (YTPlayerViewController *)childVC;
                                break;
                            }
                        }
                    }
                }
                
                if (playerVC) {
                    // Handle comma (,) and period (.) keys for frame stepping
                    // These are commonly used in video editing software
                    if (press.key.keyCode == 54) { // Comma key - step backward
                        [playerVC frameStepBackward];
                    } else if (press.key.keyCode == 55) { // Period key - step forward
                        [playerVC frameStepForward];
                    }
                    // Also support left/right arrow keys
                    else if (press.key.keyCode == 123) { // Left arrow
                        [playerVC frameStepBackward];
                    } else if (press.key.keyCode == 124) { // Right arrow
                        [playerVC frameStepForward];
                    }
                }
            }
        }
    }
}

%end

// Initialize the tweak
%ctor {
    // Basic initialization - frame stepping is now available via keyboard controls
    // On-screen button integration would require more complex overlay system integration
}