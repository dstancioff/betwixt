//
// Betwixt - Copyright 2012 Three Rings Design

#import "BTNode.h"

@interface BTSequenceTask : BTNode {
@protected
    NSArray* _nodes;
    int _position;
}

+ (BTSequenceTask*)withNodes:(BTNode*)node, ... NS_REQUIRES_NIL_TERMINATION;
- (id)initWithNodes:(NSArray*)nodes;
@end
