/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    Application delegate for MetalBasicTessellation.
 */

#import "AAPLAppDelegate.h"

#if TARGET_OS_IOS

@implementation AAPLAppDelegate
@end

#elif TARGET_OS_OSX

@interface AAPLAppDelegate ()

@property (weak) IBOutlet NSWindow *window;

@end

@implementation AAPLAppDelegate
@end

#endif
