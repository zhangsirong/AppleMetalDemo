/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header for the iOS & tvOS application delegate
*/
#if defined(TARGET_IOS) || defined(TARGET_TVOS)
@import UIKit;
#define PlatformAppDelegate UIResponder <UIApplicationDelegate>
#else
@import AppKit;
#define PlatformAppDelegate NSObject<NSApplicationDelegate>
#endif

@interface AAPLAppDelegate : PlatformAppDelegate

#if defined(TARGET_IOS) || defined(TARGET_TVOS)
@property (strong, nonatomic) UIWindow *window;
#endif

@end
