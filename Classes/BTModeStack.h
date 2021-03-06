//
// Betwixt - Copyright 2012 Three Rings Design

#import "SPSprite.h"
#import "BTMode.h"

@interface BTModeStack : NSObject {
@package
    NSMutableArray* _stack;
    NSMutableArray* _pendingModeTransitions;
    SPSprite* _sprite;
}

@property (nonatomic, readonly) BTMode* topMode;

- (void)pushMode:(BTMode*)mode;
- (void)popMode;
- (void)changeMode:(BTMode*)mode;
- (void)insertMode:(BTMode*)mode atIndex:(int)index;
- (void)removeModeAt:(int)index;
- (void)unwindToMode:(BTMode*)mode;
- (void)clear;

@end
