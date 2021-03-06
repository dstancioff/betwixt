//
// Betwixt - Copyright 2012 Three Rings Design

#import "BTApp.h"
#import "BTApp+Protected.h"
#import "BTApp+Package.h"
#import "BTResourceManager.h"
#import "BTModeStack+Package.h"

#import "BTTextureGroupFactory.h"
#import "BTTextureResource.h"
#import "BTFontResource.h"
#import "BTMovieResource.h"
#import "BTDeviceType.h"

#import "BTAudioManager.h"
#import "BTAudioManager+Package.h"
#import "BTSoundResource.h"

static BTApp* gInstance = nil;

// We override SPStage in order to handle our own input and update processing.
@interface BTStage : SPStage
@property(nonatomic,weak) BTApp* app;
@end

@interface BTViewController : UIViewController {
    __weak BTApp* _app;
}
- (id)initWithApp:(BTApp*)app;
@end

@implementation BTViewController

- (id)initWithApp:(BTApp *)app {
    if ((self = [super init])) {
        _app = app;
    }
    return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return [_app supportsUIInterfaceOrientation:toInterfaceOrientation];
}

@end

@implementation BTApp

+ (BTApp*)app {
    return gInstance;
}

+ (float)framerate {
    return gInstance->_framerate;
}

+ (BTResourceManager*)resourceManager {
    return gInstance->_resourceMgr;
}

+ (BTAudioManager*)audio {
    return gInstance->_audio;
}

+ (SPView*)view {
    return gInstance->_view;
}

+ (SPPoint*)viewSize {
    return gInstance->_viewSize;
}

+ (BTDeviceType*)deviceType {
    return gInstance->_deviceType;
}

+ (double)timeNow {
    return CACurrentMediaTime();
}

+ (BTModeStack*)createModeStack {
    return [gInstance createModeStack];
}

+ (NSString*)resourcePathFor:(NSString*)resourceName {
    return [gInstance resourcePathFor:resourceName];
}

+ (NSString*)requireResourcePathFor:(NSString*)resourceName {
    return [gInstance requireResourcePathFor:resourceName];
}

- (id)init {
    NSAssert(gInstance == nil, @"BTApp has already been created");
    if ((self = [super init])) {
        gInstance = self;
    }
    return self;
}

static UIImage* LoadPng (NSString* name) {
    return [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:name
                                                                            ofType:@"png" 
                                                                       inDirectory:nil]];
}

static NSString* const DEFAULT_IMAGE_PATHS[] = {
    @"",                            // UIDeviceOrientationUnknown
    @"Default-Portrait",            // UIDeviceOrientationPortrait
    @"Default-PortraitUpsideDown",  // UIDeviceOrientationPortraitUpsideDown
    @"Default-LandscapeLeft",       // UIDeviceOrientationLandscapeLeft
    @"Default-LandscapeRight",      // UIDeviceOrientationLandscapeRight
    @"",                            // UIDeviceOrientationFaceUp
    @""                             // UIDeviceOrientationFaceDown
};

static NSString* const FALLBACK_IMAGE_PATHS[] = {
    @"",                            // UIDeviceOrientationUnknown
    @"Default-Portrait",            // UIDeviceOrientationPortrait
    @"Default-Portrait",            // UIDeviceOrientationPortraitUpsideDown
    @"Default-Landscape",           // UIDeviceOrientationLandscapeLeft
    @"Default-Landscape",           // UIDeviceOrientationLandscapeRight
    @"",                            // UIDeviceOrientationFaceUp
    @""                             // UIDeviceOrientationFaceDown
};

- (UIImage*)loadSplashImage:(UIInterfaceOrientation)orientation {
    UIImage* image = LoadPng(DEFAULT_IMAGE_PATHS[orientation]);
    if (image == nil) {
        image = LoadPng(FALLBACK_IMAGE_PATHS[orientation]);
    }
    if (image == nil) {
        image = LoadPng(@"Default");
    }
    return image;
}

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
    
    // Window
    CGRect windowBounds = [UIScreen mainScreen].bounds;
    _window = [[UIWindow alloc] initWithFrame:windowBounds];
    _viewController = [[BTViewController alloc] initWithApp:self];
    _window.rootViewController = _viewController;
    
    // Determine the type of device we're on by our resolution
    int deviceWidth = windowBounds.size.width * [UIScreen mainScreen].scale;
    int deviceHeight = windowBounds.size.height * [UIScreen mainScreen].scale;
    for (BTDeviceType* deviceType in BTDeviceType.values) {
        if ((deviceWidth == deviceType.screenWidth && 
             deviceHeight == deviceType.screenHeight) ||
            (deviceWidth == deviceType.screenHeight &&
             deviceHeight == deviceType.screenWidth)) {
                
            _deviceType = deviceType;
            break;    
        }
    }
    
    CGRect viewBounds = windowBounds;
    if (![self supportsUIInterfaceOrientation:UIInterfaceOrientationPortrait] &&
        ![self supportsUIInterfaceOrientation:UIInterfaceOrientationPortraitUpsideDown]) {
        CGFloat tmp = viewBounds.size.width;
        viewBounds.size.width = viewBounds.size.height;
        viewBounds.size.height = tmp;
    }
    
    // View
    _view = [[SPView alloc] initWithFrame:viewBounds];
    _view.multipleTouchEnabled = YES;
    _viewController.view = _view;
    
    // Stage
    [BTStage setSupportHighResolutions:YES];
    BTStage* stage = [[BTStage alloc] initWithWidth:viewBounds.size.width 
                                             height:viewBounds.size.height];
    stage.app = self;
    _view.stage = stage;
    // Framerate must be set after the stage has been attached to the view.
    stage.frameRate = 60;
    
    _viewSize = [SPPoint pointWithX:stage.width y:stage.height];
    
    // Setup ResourceManager
    _resourceMgr = [[BTResourceManager alloc] init];
    [_resourceMgr registerFactory:[BTSoundResource sharedFactory] forType:BT_SOUND_RESOURCE_NAME];
    [_resourceMgr registerFactory:[BTTextureResource sharedFactory] forType:BT_TEXTURE_RESOURCE_NAME];
    [_resourceMgr registerFactory:[BTFontResource sharedFactory] forType:BT_FONT_RESOURCE_NAME];
    [_resourceMgr registerFactory:[BTMovieResource sharedFactory] forType:BT_MOVIE_RESOURCE_NAME];
    [_resourceMgr registerMultiFactory:[BTTextureGroupFactory sharedFactory] forType:BT_TEXTURE_GROUP_RESOURCE_NAME];
    
    // Setup AudioManager
    _audio = [[BTAudioManager alloc] init];
    [_audio setup];
    
    // create default mode stack
    _modeStacks = [NSMutableArray array];
    [self run:[self createModeStack]];
    
    [_window makeKeyAndVisible];
    
    // Show our splash image
    UIImage* splashImage = [self loadSplashImage:_viewController.interfaceOrientation];
    if (splashImage != nil) {
        _splashScreenView = [[UIImageView alloc] initWithImage:splashImage];
        [_window addSubview:_splashScreenView];
        [_window bringSubviewToFront:_splashScreenView];
    }
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication*)application {
    [_view stop];
}

- (void)applicationDidBecomeActive:(UIApplication*)application {
    [_view start];
}

- (void)dealloc {
    _resourceMgr = nil;
    _resourceMgr = nil;
    _modeStacks = nil;
    _view = nil;
    [_audio shutdown];
    _audio = nil;
}

- (void)run:(BTModeStack*)defaultStack {
    OOO_IS_ABSTRACT();
}

- (void)update:(float)dt {
    if (_splashScreenView != nil) {
        [_splashScreenView removeFromSuperview];
        _splashScreenView = nil;
    }
    
    _framerate = 1.0f / dt;
    [_audio update:dt];
    for (BTModeStack* stack in _modeStacks) {
        [stack update:dt];
    }
}

- (void)processTouches:(NSSet*)touches {
    for (BTModeStack* stack in _modeStacks) {
        [stack processTouches:touches];
    }
}

- (BTModeStack*)createModeStack {
    BTModeStack* stack = [[BTModeStack alloc] init];
    [_view.stage addChild:stack->_sprite];
    [_modeStacks addObject:stack];
    return stack;
}

- (BOOL)supportsUIInterfaceOrientation:(UIInterfaceOrientation)orientation {
    return UIInterfaceOrientationIsPortrait(orientation);
}

- (NSString*)resourcePathPrefix {
    return @"";
}

- (NSString*)requireResourcePathFor:(NSString*)resourceName {
    NSString* path = [self resourcePathFor:resourceName];
    if (path == nil) {
        [NSException raise:NSGenericException 
                    format:@"required resource does not exist: '%@'", resourceName];
    }
    return path;
}

- (NSString*)resourcePathFor:(NSString*)resourceName {
    NSBundle* bundle = [NSBundle bundleForClass:[self class]];
    
    NSString* devicePath = [[self.resourcePathPrefix stringByAppendingPathComponent:_deviceType.deviceClass] stringByAppendingPathComponent:resourceName];
    devicePath = [bundle pathForResource:devicePath];
    if (devicePath) {
        return devicePath;
    }
    NSString *resourcePath = [self.resourcePathPrefix stringByAppendingPathComponent:resourceName];
    resourcePath = [bundle pathForResource:resourcePath];
    return resourcePath;
}

@end

@implementation BTStage

@synthesize app;

- (void)advanceTime:(double)seconds {
    [self.juggler advanceTime:seconds];
    [self.app update:(float) seconds];
}

- (void)processTouches:(NSSet*)touches {
    [self.app processTouches:touches];
}

@end
