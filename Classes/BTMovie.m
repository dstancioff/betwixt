//
// Betwixt - Copyright 2012 Three Rings Design

#import "BTMovie.h"
#import "BTMovie+Package.h"
#import "BTApp.h"
#import "BTDisplayObjectCreator.h"
#import "BTMovieResourceKeyframe.h"
#import "BTResourceManager.h"
#import "BTTextureResource.h"
#import "BTMovieResourceLayer.h"
#import "BTJugglerContainer.h"

#define NO_FRAME -1

NSString * const BTMovieFirstFrame = @"BTMovieFirstFrame";
NSString * const BTMovieLastFrame = @"BTMovieLastFrame";
@interface BTMovieLayer : NSObject {
@public
    int keyframeIdx;// The index of the last keyframe drawn in drawFrame
    int layerIdx;// This layer's index in the movie
    NSMutableArray* keyframes;// <BTMovieResourceKeyframe*>
    // The DisplayObjects that are shown for each keyframe
    NSMutableArray* displays;// <SPDisplayObject*>
    // The movie this layer belongs to
    __weak BTMovie* movie;
    // If the keyframe has changed since the last drawFrame
    BOOL changedKeyframe;
}
@end

@implementation BTMovieLayer

- (BTMovieResourceKeyframe*)kfAtIdx:(int)idx {
    return (BTMovieResourceKeyframe*)[keyframes objectAtIndex:idx];
}

- (id)initForMovie:(BTMovie*)parent withLayer:(BTMovieResourceLayer*)layer {
    if ((self = [super init])) {
        keyframes = layer->keyframes;
        movie = parent;
        
        SPSprite* emptySprite = [[SPSprite alloc] init];
        
        // Create the DisplayObjects that are attached to each keyframe
        displays = [[NSMutableArray alloc] initWithCapacity:[keyframes count]];
        for (int ii = 0; ii < [keyframes count]; ++ii) {
            [displays addObject:emptySprite];
        }
        [layer->keyframesForSymbol enumerateKeysAndObjectsUsingBlock:^(id symbol, NSArray* frameIndices, BOOL *stop) {
            NSString* symbolName = OOONSNullToNil(symbol);
            SPDisplayObject* display = nil;
            if (symbolName == nil) {
                display = emptySprite;
            } else {
                id<BTDisplayObjectCreator> res = 
                [BTApp.resourceManager requireResource:symbol 
                                          conformingTo:@protocol(BTDisplayObjectCreator)];
                display = [res createDisplayObject];
            }
            
            for (NSNumber* num in frameIndices) {
                [displays replaceObjectAtIndex:num.integerValue withObject:display];
            }
        }];
        
        // Add the first keyframe's DisplayObject to the movie
        [movie addChild:[displays objectAtIndex:0]];
        
        layerIdx = movie.numChildren - 1;
        [movie childAtIndex:layerIdx].name = layer->name;
    }
    
    return self;
}

- (void)drawFrame:(int)frame {
    while (keyframeIdx < [keyframes count] - 1 && [self kfAtIdx:keyframeIdx + 1]->index <= frame) {
        keyframeIdx++;
        changedKeyframe = true;
    }
    if (changedKeyframe) {
        SPDisplayObject* display = [displays objectAtIndex:keyframeIdx];
        if (display != [movie childAtIndex:layerIdx]) {
            [movie removeChildAtIndex:layerIdx];
            [movie addChild:display atIndex:layerIdx];
        }
    }
    changedKeyframe = false;

    BTMovieResourceKeyframe* kf = [self kfAtIdx:keyframeIdx];
    SPDisplayObject* layer = [movie childAtIndex:layerIdx];
    if (keyframeIdx == [keyframes count] - 1|| kf->index == frame) {
        layer.x = kf->x;
        layer.y = kf->y;
        layer.scaleX = kf->scaleX;
        layer.scaleY = kf->scaleY;
        layer.skewX = kf->skewX;
        layer.skewY = kf->skewY;
        layer.alpha = kf->alpha;
    } else {
        float interped = (frame - kf->index)/(float)kf->duration;
        float ease = kf->ease;
        if (ease != 0) {
            float t = 0;
            if (ease < 0) {
                // Ease in
                float inv = 1 - interped;
                t = 1 - inv*inv;
                ease = -ease;
            } else {
                // Ease out
                t = interped * interped;
            }
            interped = ease * t + (1 - ease) * interped;
        }
        
        BTMovieResourceKeyframe* nextKf = [self kfAtIdx:keyframeIdx + 1];
        layer.x = kf->x + (nextKf->x - kf->x) * interped;
        layer.y = kf->y + (nextKf->y - kf->y) * interped;
        layer.scaleX = kf->scaleX + (nextKf->scaleX - kf->scaleX) * interped;
        layer.scaleY = kf->scaleY + (nextKf->scaleY - kf->scaleY) * interped;
        layer.skewX = kf->skewX + (nextKf->skewX - kf->skewX) * interped;
        layer.skewY = kf->skewY + (nextKf->skewY - kf->skewY) * interped;
        layer.alpha = kf->alpha + (nextKf->alpha - kf->alpha) * interped;
    }
    
    layer.pivotX = kf->pivotX;
    layer.pivotY = kf->pivotY;
    layer.visible = kf->visible;
}
@end

// Proxies connections to the label monitor connecitions so that once only applies when the desired
// label is fired.
@interface LabelMonitorConnProxy : RAConnection {
@public
    RAConnection* _proxied;
    BOOL _oneShot;
}
@end
@implementation LabelMonitorConnProxy
- (void)proxiedDispatched {
    if (_oneShot) [self disconnect];
}

- (RAConnection*)once {
    _oneShot = YES;
    return self;
}

- (void)disconnect {
    [_proxied disconnect];
    _proxied = nil;
}
@end

@implementation BTMovie

@synthesize duration = _duration;
@synthesize playing = _playing;
@synthesize labelPassed = _labelPassed;
@synthesize frame = _frame;
@synthesize framerate = _framerate;

- (int)frameForLabel:(NSString*)label {
    for (int ii = 0; ii < [_labels count]; ii++) {
        if ([[_labels objectAtIndex:ii] containsObject:label]) return ii;
    }
    
    @throw [NSException
            exceptionWithName:@"UnknownLabel"
            reason:[NSString stringWithFormat:@"Unknown label '%@'", label]
            userInfo:nil];
}

- (RAConnection*)monitorLabel:(NSString*)label withUnit:(RAUnitBlock)slot {
    LabelMonitorConnProxy* proxy = [[LabelMonitorConnProxy alloc] init];
    slot = [slot copy];
    RAConnection* realConn = [_labelPassed connectSlot:^(id labelFired) {
        if ([labelFired isEqualToString:label]) {
            slot();
            [proxy proxiedDispatched];
        }
    }];
    proxy->_proxied = realConn;
    return proxy;
}

- (void)fireLabelsFrom:(int)startFrame to:(int)endFrame {
    for (int ii = startFrame; ii <= endFrame; ii++) {
        for (NSString* label in [_labels objectAtIndex:ii]) [_labelPassed emitEvent:label];
    }
}

- (void)gotoFrame:(int)newFrame fromSkip:(BOOL)fromSkip overDuration:(BOOL)overDuration {
    NSAssert(newFrame >= 0 && newFrame < _labels.count, @"bad frame: %d", newFrame);
    
    if (_goingToFrame) {
        _pendingFrame = newFrame;
        return;
    }
    _goingToFrame = YES;
    BOOL differentFrame = newFrame != _frame;
    BOOL wrapped = newFrame < _frame;
    if (differentFrame) {
        if (wrapped) {
            for (BTMovieLayer* layer in _layers) {
                layer->changedKeyframe = true;
                layer->keyframeIdx = 0;
            }
        }
        for (BTMovieLayer* layer in _layers) [layer drawFrame:newFrame];
    }

    // Update the frame before firing, so if firing changes the frame, it sticks.
    int oldFrame = _frame;
    _frame = newFrame;
    if (fromSkip) {
        [self fireLabelsFrom:newFrame to:newFrame];
        _playTime = newFrame/_framerate;
    } else if (overDuration) {
        [self fireLabelsFrom:oldFrame + 1 to:[_labels count] - 1];
        [self fireLabelsFrom:0 to:_frame];
    } else if (differentFrame) {
        if (wrapped) {
            [self fireLabelsFrom:oldFrame + 1 to:[_labels count] - 1];
            [self fireLabelsFrom:0 to:_frame];
        } else [self fireLabelsFrom:oldFrame + 1 to:_frame];
    }
    _goingToFrame = NO;
    if (_pendingFrame != NO_FRAME) {
        newFrame = _pendingFrame;
        _pendingFrame = NO_FRAME;
        [self gotoFrame:newFrame fromSkip:YES overDuration:NO];
    }
}

- (void)playOnce {
    [self playFromFrame:0 toFrame:self.frames - 1];
}

- (void)play {
    [self playFromFrame:self.frame];
}

- (void)stop {
    [self gotoFrame:self.frame];
}

- (void)playToLabel:(NSString*)label {
  [self playToFrame:[self frameForLabel:label]];
}

- (void)playToFrame:(int)frame {
    _stopFrame = frame;
    _playing.value = YES;
}

- (void)playFromLabel:(NSString*)startLabel toLabel:(NSString*)stopLabel {
    [self playFromFrame:[self frameForLabel:startLabel] toFrame:[self frameForLabel:stopLabel]];
}

- (void)playFromFrame:(int)startFrame toLabel:(NSString*)stopLabel {
    [self playFromFrame:startFrame toFrame:[self frameForLabel:stopLabel]];
}
- (void)playFromLabel:(NSString*)startLabel toFrame:(int)stopFrame {
    [self playFromFrame:[self frameForLabel:startLabel] toFrame:stopFrame];
}

- (void)playFromFrame:(int)startFrame toFrame:(int)stopFrame {
    [self playToFrame:stopFrame];
    [self gotoFrame:startFrame fromSkip:YES overDuration:NO];
}

- (void)playFromLabel:(NSString*)label {
    [self playFromFrame:[self frameForLabel:label]];
}

- (void)playFromFrame:(int)frame {
    _playing.value = YES;
    _stopFrame = NO_FRAME;
    [self gotoFrame:frame fromSkip:YES overDuration:NO];
}

- (void)gotoLabel:(NSString*)label {
    [self gotoFrame:[self frameForLabel:label]];
}

- (void)gotoFrame:(int)frame {
    _playing.value = NO;
    [self gotoFrame:frame fromSkip:YES overDuration:NO];
}

- (int)frames { return [_labels count]; }

- (void)advanceTime:(double)dt {
    if (!_playing.value) return;
    
    _playTime += dt;
    float actualPlaytime = _playTime;
    if (_playTime >= _duration) _playTime = fmodf(_playTime, _duration);
    int newFrame = (int)(_playTime * _framerate);
    BOOL overDuration = dt >= _duration;
    // If the update crosses or goes to the stopFrame, go to the stop frame, stop the movie and
    // clear it
    if (_stopFrame != NO_FRAME) {
        // how many frames remain to the stopframe?
        int framesRemaining = 
            (_frame <= _stopFrame ? _stopFrame - _frame : self.frames - _frame + _stopFrame);
        int framesElapsed = (int)(actualPlaytime * _framerate) - _frame;
        if (framesElapsed >= framesRemaining) {
            _playing.value = NO;
            newFrame = _stopFrame;
            _stopFrame = NO_FRAME;
        }
    }
    [self gotoFrame:newFrame fromSkip:NO overDuration:overDuration];
}

- (BOOL)isComplete { return NO; }

- (void)addedToStage:(SPEvent*)event {
    SPDisplayObject* parent = self.parent;
    while (parent) {
        if ([parent conformsToProtocol:@protocol(BTJugglerContainer)]) {
            _juggler = ((id<BTJugglerContainer>)parent).juggler;
            break;
        }
        parent = parent.parent;
    }
    if (!_juggler) _juggler = [[SPStage mainStage] juggler];
    [_juggler addObject:self];
}

- (void)removedFromStage:(SPEvent*)event {
    [_juggler removeObject:self];
    _juggler = nil;
}

- (id)initWithFramerate:(float)framerate layers:(NSMutableArray*)layers labels:(NSArray*)labels {
    if ((self = [super init])) {
        _framerate = framerate;
        _layers = [[NSMutableArray alloc] initWithCapacity:[layers count]];
        for (BTMovieResourceLayer* layer in layers) {
            [_layers addObject:[[BTMovieLayer alloc] initForMovie:self withLayer:layer]];
        }
        _pendingFrame = NO_FRAME;
        _stopFrame = NO_FRAME;
        _frame = NO_FRAME;
        _labels = labels;
        _duration = [labels count] / _framerate;
        _playing = [[RABoolValue alloc] init];
        _playing.value = YES;
        _labelPassed = [[RAObjectSignal alloc] init];
        [self gotoFrame:0 fromSkip:YES overDuration:NO];
        [self addEventListener:@selector(addedToStage:) atObject:self 
                       forType:SP_EVENT_TYPE_ADDED_TO_STAGE];
        [self addEventListener:@selector(removedFromStage:) atObject:self 
                       forType:SP_EVENT_TYPE_REMOVED_FROM_STAGE];
    }
    return self;
}
@end
