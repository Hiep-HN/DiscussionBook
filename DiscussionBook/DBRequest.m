//
//  DBRequest.m
//  DiscussionBook
//
//  Created by Jacob Relkin on 7/21/12.
//  Copyright (c) 2012 Jacob Relkin. All rights reserved.
//

#import "DBRequest.h"
#import "DBAppDelegate.h"
#import "FBObject+DiscussionBook.h"
#import "DBFacebookAuthenticationManager.h"

UIKIT_STATIC_INLINE NSOperationQueue *DBRequestOperationQueue() {
    static NSOperationQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[NSOperationQueue alloc] init];
    });
    return queue;
}

typedef enum {
    DBRequestStateReady = 0,
    DBRequestStateStarted,
    DBRequestStateCancelled,
    DBRequestStateFinished,
} DBRequestState;

static NSString * DBRequestMethods[] = {
    @"GET",
    @"POST",
    @"DELETE",
    @"PUT",
    @"HEAD"
};

@interface DBRequest() <FBRequestDelegate>

@property (nonatomic, readonly) DBAppDelegate *appDelegate;

@end

@implementation DBRequest {
    FBRequest *_request;
    NSManagedObjectContext *_context;
    
    DBRequestState _state;

    id _mergeNotificationObserver;
}

- (id)initWithResponseObjectType:(Class)responseObjectType {
    self = [super init];
    if(self) {
        _responseObjectsKeyPath = @"data";
        _responseObjectType = responseObjectType;
        _state = DBRequestStateReady;
    }
    return self;
}

- (BOOL)isFinished {
    return _state == DBRequestStateFinished;
}

- (BOOL)isCancelled {
    return _state == DBRequestStateCancelled;
}

- (BOOL)isExecuting {
    return _state == DBRequestStateStarted;
}

- (BOOL)isReady {
    return _state == DBRequestStateReady;
}

- (BOOL)isConcurrent {
    return YES;
}

- (void)cancel {
    [self _performKVCModificationWithKey:@"isCancelled" block:^{
        _state = DBRequestStateCancelled;
    }];
    
    [super cancel];
    
    _mergeNotificationObserver = nil;
    [[_request connection] cancel];
}

- (void)start {
    [self _performKVCModificationWithKey:@"isStarted" block:^{
        _state = DBRequestStateStarted;
    }];
    
    [super start];
}

- (void)main {
    @autoreleasepool {
        _context = [[NSManagedObjectContext alloc] init];
        
        NSPersistentStoreCoordinator *psc = [[self appDelegate] persistentStoreCoordinator];
        [_context setPersistentStoreCoordinator:psc];
        
        NSURL *url = [NSURL URLWithString:[self route] relativeToURL:[NSURL URLWithString:@"https://graph.facebook.com"]];
        
        DBFacebookAuthenticationManager *manager = [DBFacebookAuthenticationManager sharedManager];
        NSMutableDictionary *params = [NSMutableDictionary new];
        [params addEntriesFromDictionary:[self parameters]];
        [params setObject:[manager accessToken] forKey:@"access_token"];
        
        _request = [FBRequest new];
        _request.httpMethod = DBRequestMethods[[self method]];
        _request.url        = [url absoluteString];
        _request.params     = params;
        _request.delegate   = self;
        
        [_request connect];
        
        while ([self isFinished] == NO) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
        }        
    }
}

- (void)execute {
    [DBRequestOperationQueue() addOperation:self];
}

#pragma mark - FBRequestDelegate

- (void)request:(FBRequest *)request didFailWithError:(NSError *)error {    
    if(_failureBlock) {
        _failureBlock(error);
    }
}

- (void)request:(FBRequest *)request didLoad:(id)result {
    
    id data = result;
    if(_responseObjectsKeyPath) {
        data = [data valueForKeyPath:_responseObjectsKeyPath];
    }

    if([data isKindOfClass:[NSArray class]]) {
        for(id obj in data) {
            [self _createModelObjectWithDictionary:obj];
        }
    } else {
        [self _createModelObjectWithDictionary:data];
    }
    
    [self _requestSucceeded];
}

#pragma mark Private

- (DBAppDelegate *)appDelegate {
    return [[UIApplication sharedApplication] delegate];
}

- (void)_performKVCModificationWithKey:(NSString *)key block:(dispatch_block_t)block {
    [self willChangeValueForKey:key];
    if(block) {
        block();
    }
    [self didChangeValueForKey:key];
}

- (void)_requestSucceeded {
    void (^notificationBlock)(NSNotification *) = ^(NSNotification *note) {
        _mergeNotificationObserver = nil;
        
        NSManagedObjectContext *mainContext = [[self appDelegate] managedObjectContext];
        [mainContext mergeChangesFromContextDidSaveNotification:note];
        
        _state = DBRequestStateFinished;
    };
    
    _mergeNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextDidSaveNotification
                                                                                   object:nil
                                                                                    queue:[NSOperationQueue mainQueue]
                                                                               usingBlock:notificationBlock];
    NSError *error = nil;
    if (![_context save:&error]) {
        NSLog(@"error saving: %@", error);
    }
}

- (void)_createModelObjectWithDictionary:(NSDictionary *)dictionary {
    Class cls = [self responseObjectType];
    if(!cls) {
        return;
    }
    
    FBObject *object = [cls objectWithDictionary:dictionary inContext:_context];
    if (_initializationCallback) {
        _initializationCallback(object);
    }
}

@end
