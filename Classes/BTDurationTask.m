//
// Betwixt - Copyright 2012 Three Rings Design

#import "BTDurationTask.h"
#import "BTDurationTask+Protected.h"

@implementation BTDurationTask

- (id)initWithTime:(float)time {
    if ((self = [super init])) {
        _totalTime = time;
    }
    return self;
}

- (void)update:(float)dt {
    _elapsedTime = MIN(_elapsedTime + dt, _totalTime);
    [self updateValues];
    if (_elapsedTime == _totalTime) {
        [self removeSelf];
    }
}

- (void)updateValues {}

@end
