//
//  LYRUIMessageCollectionViewCell.m
//  LayerSample
//
//  Created by Kevin Coleman on 8/31/14.
//  Copyright (c) 2014 Layer, Inc. All rights reserved.
//

#import "LYRUIMessageCollectionViewCell.h"
#import "LYRUIMessagingUtilities.h"
#import "LYRUIIncomingMessageCollectionViewCell.h"
#import "LYRUIOutgoingMessageCollectionViewCell.h"

@interface LYRUIMessageCollectionViewCell ()

@property (nonatomic) BOOL messageSentState;
@property (nonatomic) LYRMessage *message;

@end

@implementation LYRUIMessageCollectionViewCell

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Default UIAppearance
        _messageTextFont = [UIFont systemFontOfSize:14];
        _messageTextColor = [UIColor blackColor];
        _messageLinkTextColor = [UIColor blueColor];
        _bubbleViewColor = [UIColor lightGrayColor];
        _bubbleViewCornerRadius = 12;
        
        _bubbleView = [[LYRUIMessageBubbleView alloc] init];
        _bubbleView.translatesAutoresizingMaskIntoConstraints = NO;
        _bubbleView.layer.cornerRadius = _bubbleViewCornerRadius;
        [self.contentView addSubview:_bubbleView];
        
        _avatarImageView = [[LYRUIAvatarImageView alloc] init];
        _avatarImageView.backgroundColor = LYRUILightGrayColor();
        _avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:_avatarImageView];

        [self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.bubbleView
                                                                     attribute:NSLayoutAttributeHeight
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.contentView
                                                                     attribute:NSLayoutAttributeHeight
                                                                    multiplier:1.0
                                                                      constant:0]];

        [self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.bubbleView
                                                                     attribute:NSLayoutAttributeTop
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.contentView
                                                                     attribute:NSLayoutAttributeTop
                                                                    multiplier:1.0
                                                                      constant:0]];

        CGFloat maxBubbleWidth = LYRUIMaxCellWidth() + LYRUIMessageBubbleLabelHorizontalPadding * 2;
        [self.contentView addConstraint:[NSLayoutConstraint constraintWithItem:self.bubbleView
                                                                     attribute:NSLayoutAttributeWidth
                                                                     relatedBy:NSLayoutRelationLessThanOrEqual
                                                                        toItem:nil
                                                                     attribute:NSLayoutAttributeNotAnAttribute
                                                                    multiplier:1.0
                                                                      constant:maxBubbleWidth]];
    }
    return self;
}

- (void)updateWithParticipant:(id<LYRUIParticipant>)participant
{

}

- (void)shouldDisplayAvatarImage:(BOOL)shouldDisplayAvatarImage
{

}

- (void)isGroupConversation:(BOOL)isGroupConversation
{

}

- (void)presentMessage:(LYRMessage *)message
{
    LYRMessagePart *messagePart = message.parts.firstObject;
    if (!messagePart.data.length) {
        [self.bubbleView displayDownloadActivityIndicator];
        return;
    }
    if ([messagePart.MIMEType isEqualToString:LYRUIMIMETypeTextPlain]) {
        NSString *text = [[NSString alloc] initWithData:messagePart.data encoding:NSUTF8StringEncoding];
        [self.bubbleView updateWithAttributedText:[self attributedStringForText:text]];
        self.accessibilityLabel = [NSString stringWithFormat:@"Message: %@", text];
    } else if ([messagePart.MIMEType isEqualToString:LYRUIMIMETypeImageJPEG] || [messagePart.MIMEType isEqualToString:LYRUIMIMETypeImagePNG]) {
        UIImage *image = [UIImage imageWithData:messagePart.data];
        [self.bubbleView updateWithImage:image];
        self.accessibilityLabel = [NSString stringWithFormat:@"Message: Photo"];
    } else if ([messagePart.MIMEType isEqualToString:LYRUIMIMETypeLocation]) {
        NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:messagePart.data
                                                                   options:NSJSONReadingAllowFragments
                                                                     error:nil];
        double lat = [dictionary[@"lat"] doubleValue];
        double lon = [dictionary[@"lon"] doubleValue];
        [self.bubbleView updateWithLocation:CLLocationCoordinate2DMake(lat, lon)];
    }
    _message = message;
}

- (void)setMessageTextFont:(UIFont *)messageTextFont
{
    _messageTextFont = messageTextFont;
    if (self.message) [self presentMessage:self.message];
}

- (void)setMessageTextColor:(UIColor *)messageTextColor
{
    _messageTextColor = messageTextColor;
    if (self.message) [self presentMessage:self.message];
}

- (void)setMessageLinkTextColor:(UIColor *)messageLinkTextColor
{
    _messageLinkTextColor = messageLinkTextColor;
    if (self.message) [self presentMessage:self.message];
}

- (void)setBubbleViewColor:(UIColor *)bubbleViewColor
{
    _bubbleViewColor = bubbleViewColor;
    self.bubbleView.backgroundColor = bubbleViewColor;
}

- (NSAttributedString *)attributedStringForText:(NSString *)text
{
    NSDictionary *attributes = @{NSFontAttributeName : self.messageTextFont, NSForegroundColorAttributeName : self.messageTextColor};
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:text attributes:attributes];
    NSArray *linkResults = LYRUILinkResultsForText(text);
    for (NSTextCheckingResult *result in linkResults) {
        NSDictionary *linkAttributes = @{NSForegroundColorAttributeName : self.messageLinkTextColor,
                                         NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle)};
        [attributedString addAttributes:linkAttributes range:result.range];
    }
    return attributedString;
}

@end
