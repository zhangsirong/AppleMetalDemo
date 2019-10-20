/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of the cross-platform view controller
*/

#import "AAPLViewController.h"


#if USE_TRADITIONAL_DEFERRED_LIGHTING
#import "AAPLRenderer_TraditionalDeferred.h"
#define AAPLDeferredRenderer AAPLRenderer_TraditionalDeferred

#elif USE_SINGLE_PASS_DEFERRED_LIGHTING

#import "AAPLRenderer_SinglePassDeferred.h"
#define AAPLDeferredRenderer AAPLRenderer_SinglePassDeferred

#endif

@implementation AAPLViewController
{
    MTKView *_view;

    AAPLDeferredRenderer *_renderer;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Set the view to use the default device
    _view = (MTKView *)self.view;
    _view.device = MTLCreateSystemDefaultDevice();

    NSAssert(_view.device, @"Metal is not supported on this device");

    _renderer = [[AAPLDeferredRenderer alloc] initWithMetalKitView:_view];

    NSAssert(_renderer, @"Renderer failed initialization");
    
    [_renderer mtkView:_view drawableSizeWillChange:_view.drawableSize];

    _view.delegate = _renderer;
}

#if TARGET_IOS

#if SUPPORT_BUFFER_EXAMINATION_MODE
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [_renderer toggleBufferExaminationMode:AAPLExaminationModeAll];
}

#endif // END SUPPORT_BUFFER_EXAMINATION_MODE

- (BOOL)prefersHomeIndicatorAutoHidden
{
    return YES;
}

#elif TARGET_MACOS

- (void)viewDidAppear
{
    // Make the view controller the window's first responder so that it can handle the Key events
    [_view.window makeFirstResponder:self];
}

- (void)keyDown:(NSEvent *)event
{
    NSString* characters = [event characters];

    for (uint32_t k = 0; k < characters.length; k++)
    {
        unichar key = [characters characterAtIndex:k];

        // When space pressed, toggle buffer examination mode
        switch(key)
        {
            // Pause/Un-pause with spacebar
            case ' ':
            {
                _view.paused = !_view.paused;
                break;
            }
#if SUPPORT_BUFFER_EXAMINATION_MODE
            // Enter/exit buffer examination mode with e or return key
            case '\r':
            case '1':
                [_renderer toggleBufferExaminationMode:AAPLExaminationModeAll];
                break;
            case '2':
                [_renderer toggleBufferExaminationMode:AAPLExaminationModeAlbedo];
                break;
            case '3':
                [_renderer toggleBufferExaminationMode:AAPLExaminationModeNormals];
                break;
            case '4':
                [_renderer toggleBufferExaminationMode:AAPLExaminationModeDepth];
                break;
            case '5':
                [_renderer toggleBufferExaminationMode:AAPLExaminationModeSpecular];
                break;
            case '6':
                [_renderer toggleBufferExaminationMode:AAPLExaminationModeShadowGBuffer];
                break;
            case '7':
                [_renderer toggleBufferExaminationMode:AAPLExaminationModeShadowMap];
                break;
            case '8':
                [_renderer toggleBufferExaminationMode:AAPLExaminationModeMaskedLightVolumes];
                break;
            case '9':
                [_renderer toggleBufferExaminationMode:AAPLExaminationModeFullLightVolumes];
                break;
            case '0':
                [_renderer toggleBufferExaminationMode:AAPLExaminationModeDisabled];
                break;
#endif // END SUPPORT_BUFFER_EXAMINATION_MODE
        }
    }
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

#endif // END TARGET_MACOS

@end
