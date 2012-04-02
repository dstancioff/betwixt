//
// Betwixt - Copyright 2012 Three Rings Design

#import "BTEventSignal.h"
#import "BTEventSignal+Protected.h"

@implementation BTEventSignal

+ (BTEventSignal*)eventSignalWithDispatcher:(SPEventDispatcher*)dispatcher eventType:(NSString*)eventType {
    return [[BTEventSignal alloc] initWithDispatcher:dispatcher eventType:eventType];
}

+ (BTEventSignal*)touchEventSignalWithDisplayObject:(SPDisplayObject*)disp {
    return [[BTEventSignal alloc] initWithDispatcher:disp eventType:SP_EVENT_TYPE_TOUCH];
}

- (id)initWithDispatcher:(SPEventDispatcher*)dispatcher eventType:(NSString*)eventType {
    if (!(self = [super init])) {
        return nil;
    }
    _dispatcher = dispatcher;
    _eventType = eventType;
    return self;
}

- (void)onEventDispatched:(SPEvent*)event {
    [self emitEvent:event];
}

- (RAConnection*)withPriority:(int)priority connectSlot:(RAObjectSlot)block {
    if (!_connected) {
        // connect to the dispatcher
        _connected = YES;
        [_dispatcher addEventListener:@selector(onEventDispatched:) atObject:self 
                              forType:_eventType];
    }
    return [super withPriority:priority connectSlot:block];
}

- (void)dealloc {
    if (_connected) {
        [_dispatcher removeEventListener:@selector(onEventDispatched:) atObject:self 
                                 forType:_eventType];
    }
}

@end
