/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    main
 */

#include <TargetConditionals.h>

#if TARGET_OS_IOS

#import <UIKit/UIKit.h>
#import "AAPLAppDelegate.h"

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AAPLAppDelegate class]));
    }
}

#elif TARGET_OS_OSX

@import Cocoa;

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}

#endif
