//
//  DBCommentTableViewCell.m
//  DiscussionBook
//
//  Created by Jacob Relkin on 7/22/12.
//  Copyright (c) 2012 Jacob Relkin. All rights reserved.
//

#import "DBCommentTableViewCell.h"
#import "FBComment.h"
#import "FBPost+DiscussionBook.h"
#import "FBUser+DiscussionBook.h"

static NSDateFormatter *CommentDateFormatter() {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateStyle:NSDateFormatterShortStyle];
        [formatter setDoesRelativeDateFormatting:YES];
    });
    return formatter;
}

static NSDateFormatter *CommentTimeFormatter() {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setTimeStyle:NSDateFormatterShortStyle];
    });
    return formatter;
}

@implementation DBCommentTableViewCell

+ (CGFloat)commentWidthForCellWidth:(CGFloat)width {
    CGFloat paddingFromLeftEdgeToImage = 10;
    CGFloat widthOfImage = 44;
    CGFloat paddingFromImageToMessage = 10;
    CGFloat paddingFromMessageToRightEdge = 10;
    
    return width - paddingFromLeftEdgeToImage - widthOfImage - paddingFromImageToMessage - paddingFromMessageToRightEdge;
}

+ (CGFloat)cellHeightForCommentHeight:(CGFloat)height {
    CGFloat paddingFromTopToName = 6;
    CGFloat heightOfName = 16;
    CGFloat paddingFromNameToMessage = 6;
    CGFloat paddingFromMessageToDate = 0;
    CGFloat heightOfDate = 21;
    CGFloat paddingFromDateToBottom = 1;
    
    return height + paddingFromTopToName + heightOfName + paddingFromNameToMessage + paddingFromMessageToDate + heightOfDate + paddingFromDateToBottom;
}

- (void)setHighlighted:(BOOL)highlighted {

}

- (void)prepareForReuse {
    [_userImageView setImage:[UIImage imageNamed:@"silhouette.gif"]];
}

- (void)setRepresentedObject:(id)object {
    _representedObject = object;
    
    FBUser *user = [_representedObject fromUser];
    [_userName setText:[user name]];
    [user requestUserImage:^(UIImage *image) {
        // if we're still showing the same thing...
        if ([self representedObject] == object) {
            [_userImageView setImage:image];
        }
    }];
    
    NSNumber *likes = [_representedObject likes];
    if ([likes integerValue] > 0) {
        NSString *localizedLikes = [NSNumberFormatter localizedStringFromNumber:likes numberStyle:NSNumberFormatterDecimalStyle];
        NSString *likesString = [NSString stringWithFormat:@"👍 %@", localizedLikes];
        [_likesLabel setText:likesString];
    } else {
        [_likesLabel setText:@""];
    }
    
    NSDate *postedDate = [_representedObject creationDate];
    NSString *postedDay = [CommentDateFormatter() stringFromDate:postedDate];
    NSString *postedTime = [CommentTimeFormatter() stringFromDate:postedDate];
    NSString *posted = [NSString stringWithFormat:@"%@ at %@", postedDay, postedTime];
    [_dateLabel setText:posted];
    
    [_messageLabel setFont:COMMENT_FONT];
    CGRect frame = [self frame];
    CGFloat width = [[self class] commentWidthForCellWidth:frame.size.width];
    if ([_representedObject hasComputedHeightForWidth:width]) {
        [_messageLabel setText:[_representedObject message]];
    } else {
        [_messageLabel setText:@"Loading..."];
    }
}

@end
