//
// Betwixt - Copyright 2012 Three Rings Design

#import "PlayMovieMode.h"

#import "BTMovieResource.h"
#import "BTMovie.h"
#import "BTModeStack.h"

@implementation PlayMovieMode
- (id)init {
    if ((self = [super init])) {
        BTMovie *movie = [BTMovieResource newMovie:@"squaredance/squaredance"];
        BTMovie* nested = [BTMovieResource newMovie:@"squaredance/nesteddance"];
        [self.sprite addChild:movie];
        [self.sprite addChild:nested];
        NSMutableSet* seen = [[NSMutableSet alloc] init];
        // Play the movie once and pop the mode
        [_conns onObjectReactor:movie.labelPassed connectSlot:^(id label) { [seen addObject:label]; }];
        [_conns onObjectReactor:nested.labelPassed connectSlot:^(id label) { [seen addObject:label]; }];
        [[movie monitorLabel:BTMovieLastFrame withUnit:^{
            [movie playFromFrame:0 toLabel:BTMovieLastFrame];
        }] once];
        [movie.playing connectUnit:^{ 
            NSAssert([seen containsObject:@"blueswitch"], nil);
            NSAssert([seen containsObject:@"redswitch"], nil);
            NSAssert([seen containsObject:@"timepassed"], nil);
            NSAssert([seen containsObject:@"moretimepassed"], nil);
            NSAssert([seen count] == 6, nil);// Last and first frame as well
            [self.modeStack popMode]; 
        }];
    }
    return self;
}

@end
