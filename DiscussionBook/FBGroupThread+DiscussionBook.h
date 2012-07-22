//
//  FBGroupThread+DiscussionBook.h
//  DiscussionBook
//
//  Created by Jacob Relkin on 7/21/12.
//  Copyright (c) 2012 Jacob Relkin. All rights reserved.
//

#import "FBGroupThread.h"

@class DBRequest;
@interface FBGroupThread (DiscussionBook)

- (DBRequest *)requestComments:(void(^)(NSArray *comments))handler;

@end
