//
// Betwixt - Copyright 2012 Three Rings Design

#import "BTAlphaTask.h"
#import "BTInterpolationTask+Protected.h"

@implementation BTAlphaTask

+ (BTAlphaTask*)withTime:(float)seconds alpha:(float)alpha {
    return [[BTAlphaTask alloc] initWithTime:seconds alpha:alpha interpolator:OOOEasing.linear target:nil];
}

+ (BTAlphaTask*)withTime:(float)seconds alpha:(float)alpha interpolator:(id<OOOInterpolator>)interp {
    return [[BTAlphaTask alloc] initWithTime:seconds alpha:alpha interpolator:interp target:nil];
}

+ (BTAlphaTask*)withTime:(float)seconds alpha:(float)alpha target:(SPDisplayObject*)target {
    return [[BTAlphaTask alloc] initWithTime:seconds alpha:alpha interpolator:OOOEasing.linear target:target];
}

+ (BTAlphaTask*)withTime:(float)seconds alpha:(float)alpha interpolator:(id<OOOInterpolator>)interp 
        target:(SPDisplayObject*)target {
    return [[BTAlphaTask alloc] initWithTime:seconds alpha:alpha interpolator:interp target:target];
}

- (id)initWithTime:(float)seconds alpha:(float)alpha interpolator:(id<OOOInterpolator>)interp target:(SPDisplayObject*)target {
    if ((self = [super initWithTime:seconds interpolator:interp target:target])) {
        _endAlpha = alpha;
    }
    return self;
}

- (void)added {
    [super added];
    _startAlpha = _target.alpha;
}

- (void)updateValues {
    _target.alpha = [self interpolate:_startAlpha to:_endAlpha];
}
@end
