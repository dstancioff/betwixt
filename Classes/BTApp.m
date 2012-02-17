//
// Betwixt - Copyright 2012 Three Rings Design

#import "BTApp.h"
#import "BTApp+Protected.h"
#import "BTApp+Package.h"
#import "BTResourceManager.h"
#import "BTModeStack+Package.h"

#import "BTAtlasFactory.h"
#import "BTTextureResource.h"
#import "BTMovieResource.h"

static BTApp* gInstance = nil;

// We override SPStage in order to handle our own input and update processing.
@interface BTStage : SPStage
@property(nonatomic,weak) BTApp* app;
@end

@implementation BTApp

+ (BTApp*)app {
    return gInstance;
}

- (id)init {
    NSAssert(gInstance == nil, @"BTApp has already been created");
    if (!(self = [super init])) return nil;
    gInstance = self;
    
    _window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _window.rootViewController = [[UIViewController alloc] init];
    _resourceMgr = [[BTResourceManager alloc] init];
    _modeStacks = [NSMutableArray array];
    return self;
}

- (BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)launchOptions {
    [self runInternal];
    [_window makeKeyAndVisible];
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
    _modeStacks = nil;
    _view = nil;
    //[SPAudioEngine stop];
}

- (void)runInternal {
    NSAssert(_view == nil, @"runInternal has already been called");

    // Setup Sparrow
    [BTStage setSupportHighResolutions:YES];
    BTStage* stage = [[BTStage alloc] init];
    stage.app = self;
    
    _view = [[SPView alloc] initWithFrame:_window.bounds];
    _view.multipleTouchEnabled = YES;
    _view.stage = stage;
    // Framerate must be set after the stage has been attached to the view.
    _view.stage.frameRate = 60;
    // Attach the view to the window
    _window.rootViewController.view = _view;
    
    _viewSize = [SPPoint pointWithX:_view.stage.width y:_view.stage.height];

    // TODO - figure out why this is throwing an exception. Looks like an iOS 5 bug
    //[SPAudioEngine start];

    // Setup ResourceManager
    [_resourceMgr registerFactory:[BTTextureResource sharedFactory] forType:BTTEXTURE_RESOURCE_NAME];
    [_resourceMgr registerFactory:[BTMovieResource sharedFactory] forType:BTMOVIE_RESOURCE_NAME];
    [_resourceMgr registerMultiFactory:[BTAtlasFactory sharedFactory] forType:BTATLAS_RESOURCE_NAME];
    
    // create default mode stack
    [self run:[self createModeStack]];
}

- (void)run:(BTModeStack*)defaultStack {
    NSLog(@"BTApp.run must be implemented by a subclass");
    [self doesNotRecognizeSelector:_cmd];
}

- (void)update:(float)dt {
    for (BTModeStack* stack in _modeStacks) {
        [stack update:dt];
    }
}

- (float)framerate {
    return _view.stage.frameRate;
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

@synthesize resourceManager=_resourceMgr, view=_view, viewSize=_viewSize;

@end

@implementation BTStage

- (void)advanceTime:(double)seconds {
    [self.juggler advanceTime:seconds];
    [self.app update:(float) seconds];
}

- (void)processTouches:(NSSet*)touches {
    [self.app processTouches:touches];
}

@synthesize app;

@end
