//
// Betwixt - Copyright 2012 Three Rings Design

#import "BTLoadingMode.h"
#import "RAUnitSignal.h"
#import "BTMode+Protected.h"
#import "BTApp.h"
#import "BTResourceManager.h"

@interface BTLoadingMode ()
- (void)loadNextFile;
@end

@implementation BTLoadingMode

@synthesize loadComplete = _loadComplete;

- (id)init {
    if ((self = [super init])) {
        _loadComplete = [[RAUnitSignal alloc] init];
        _filenames = [NSMutableArray array];
        _filenameIdx = -1;
        
        [_conns onReactor:self.entered connectUnit:^{
            if (_filenameIdx < 0) {
                // Start the load
                [self loadNextFile];
            }
        }];
    }
    
    return self;
}

- (void)addFiles:(NSString*)filename, ... {
    [_filenames addObjectsFromArray:OOO_VARARGS_TO_ARRAY(NSString*, filename)];
}

- (void)addFilesFromArray:(NSArray*)filenames {
    [_filenames addObjectsFromArray:filenames];
}

- (void)onError:(NSException*)err {
    NSLog(@"LoadingMode error: %@", err);
}

- (void)loadNextFile {
    if (++_filenameIdx >= _filenames.count) {
        [_loadComplete emit];
        return;
    }
    NSString* filename = [_filenames objectAtIndex:_filenameIdx];

    __weak BTLoadingMode* this = self;
    [BTApp.resourceManager loadResourceFile:filename onComplete:^{
        [this loadNextFile];
    } onError:^(NSException* err) {
        [this onError:err];
    }];
}

@end
