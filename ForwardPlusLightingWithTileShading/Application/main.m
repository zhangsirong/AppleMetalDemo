/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main app entry point.
*/

#import <UIKit/UIKit.h>
#import <TargetConditionals.h>
#import "AAPLAppDelegate.h"

int main(int argc, char * argv[]) {

#if TARGET_OS_SIMULATOR
#error Sample does not support execution on the iOS/tvOS simulator.  Must build for real device target.
#endif

  @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AAPLAppDelegate class]));
    }
}
