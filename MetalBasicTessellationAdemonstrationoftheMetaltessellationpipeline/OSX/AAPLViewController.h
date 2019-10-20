/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    View Controller for the OS X version of MetalBasicTessellation.
            The UI elements that can modify a tessellation pass are: a segmented control to select a patch type, a button to enable/disable wireframe rendering, sliders to change the edge and inside tessellation factors.
            The MTKView's drawing loop is only executed when the view appears, when it receives a view notification (setNeedsDisplay methods), or when its draw method is explicitly called (IBAction receiver methods).
            The MTKView's delegate methods are contained in the TessellationPipeline class.
 */

#import <Cocoa/Cocoa.h>

@interface AAPLViewController : NSViewController

@end
