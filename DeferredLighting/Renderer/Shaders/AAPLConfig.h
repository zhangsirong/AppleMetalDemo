/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header defining preprocessor conditional values that control the configuration of the app
*/

// Must account for simulator target in both application ObjC code and Metal shader code so
// use __APPLE_EMBEDDED_SIMULATOR__ to check if building for simulator target in Metal shader code
#if TARGET_OS_SIMULATOR || defined(__APPLE_EMBEDDED_SIMULATOR__)
#define TARGET_OS_SIMULATOR 1
#endif

// Chooses whether to use traditional deferred lighting or single pass deferred lighting.  The
// traditional deferred lighting renderer is used on macOS and iOS & tvOS simulators, while single
// pass derferred lighting is only possible to use on iOS and tVOS devices.
#if defined(TARGET_MACOS) || TARGET_OS_SIMULATOR
#define USE_TRADITIONAL_DEFERRED_LIGHTING 1
#elif defined(TARGET_IOS) || defined(TARGET_TVOS)
#define USE_TRADITIONAL_DEFERRED_LIGHTING 0
#endif

#define USE_SINGLE_PASS_DEFERRED_LIGHTING (!USE_TRADITIONAL_DEFERRED_LIGHTING)

// When enabled, writes depth values in eye space to the g-buffer depth component. This allows the
// deferred pass to calculate the eye space fragment position more easily in order to apply lighting.
// When disabled, the screen depth is written to the g-buffer depth component and an extra inverse
// transform from screen space to eye space is necessary to calculate lighting contributions in
// the deferred pass.
#define USE_EYE_DEPTH                   1

// When enabled, uses the stencil buffer to avoid execution of lighting calculations on fragments
// that do not intersect with a 3D light volume.
// When disabled, all fragments covered by a light in screen space will have lighting calculations
// executed. This means that considerably more fragments will have expensive lighting calculations
// executed than is actually necessary.
#define LIGHT_STENCIL_CULLING           1

// Enables toggling of buffer examination mode at runtime. Code protected by this definition
// is only useful to examine parts of the underlying implementation (i.e. it's a debug feature).
#define SUPPORT_BUFFER_EXAMINATION      1
