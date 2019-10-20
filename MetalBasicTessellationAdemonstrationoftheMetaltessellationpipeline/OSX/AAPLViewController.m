/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information
    
    Abstract:
    View Controller for the OS X version of MetalBasicTessellation.
            The UI elements that can modify a tessellation pass are: a segmented control to select a patch type, a button to enable/disable wireframe rendering, sliders to change the edge and inside tessellation factors.
            The MTKView's drawing loop is only executed when the view appears, when it receives a view notification (setNeedsDisplay methods), or when its draw method is explicitly called (IBAction receiver methods).
            The MTKView's delegate methods are contained in the TessellationPipeline class.
 */

#import <MetalKit/MetalKit.h>
#import "AAPLViewController.h"
#import "AAPLTessellationPipeline.h"

@interface AAPLViewController ()

@property (weak) IBOutlet MTKView *mtkView;
@property (weak) IBOutlet NSTextField *edgeLabel;
@property (weak) IBOutlet NSTextField *insideLabel;
@property (strong, nonatomic) AAPLTessellationPipeline* tessellationPipeline;

@end

@implementation AAPLViewController

#pragma mark ViewController setup methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.mtkView.paused = YES;
    self.mtkView.enableSetNeedsDisplay = YES;
    self.mtkView.sampleCount = 4;
}

- (void)viewDidAppear
{
    [super viewDidAppear];
    
    self.tessellationPipeline = [[AAPLTessellationPipeline alloc] initWithMTKView:self.mtkView];
    [self.mtkView draw];
}

#pragma mark IBAction receiver methods

- (IBAction)patchTypeSegmentedControlDidChange:(NSSegmentedControl *)sender {
    self.tessellationPipeline.patchType = (sender.selectedSegment == 0) ? MTLPatchTypeTriangle : MTLPatchTypeQuad;
    [self.mtkView draw];
}

- (IBAction)wireframeDidChange:(NSButton *)sender {
    self.tessellationPipeline.wireframe = (sender.state == NSOnState);
    [self.mtkView draw];
}

- (IBAction)edgeSliderDidChange:(NSSlider *)sender {
    self.edgeLabel.stringValue = [NSString stringWithFormat:@"%.1f", sender.floatValue];
    self.tessellationPipeline.edgeFactor = sender.floatValue;
    [self.mtkView draw];
}

- (IBAction)insideSliderDidChange:(NSSlider *)sender {
    self.insideLabel.stringValue = [NSString stringWithFormat:@"%.1f", sender.floatValue];
    self.tessellationPipeline.insideFactor = sender.floatValue;
    [self.mtkView draw];
}

@end
