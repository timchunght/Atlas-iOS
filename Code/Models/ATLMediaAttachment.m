//
//  ATLMediaAttachment.h
//  Atlas
//
//  Created by Klemen Verdnik on 2/14/15.
//  Copyright (c) 2015 Layer, Inc. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "ATLMediaAttachment.h"
#import "ATLMessagingUtilities.h"
#import "ATLMediaInputStream.h"
#import <MobileCoreServices/MobileCoreServices.h>

/**
 @abstract Fetches the ALAsset from library based on given `assetURL`.
 @param assetURL URL identifier representing the asset.
 @param assetLibrary Library instance from whence to fetch the asset.
 @return An `ALAsset` if successfully retrieved from asset library, otherwise `nil`.
 */
ALAsset *ATLMediaAttachmentFromAssetURL(NSURL *assetURL, ALAssetsLibrary *assetLibrary);

static char const ATLMediaAttachmentAsyncToBlockingQueueName[] = "com.layer.Atlas.ATLMediaAttachment.blocking";

#pragma mark - Private class definitions

@interface ATLMediaAttachment ()

@property (nonatomic) UIImage *attachableThumbnailImage;
@property (nonatomic, readwrite) ATLMediaAttachmentType mediaType;
@property (nonatomic, readwrite) NSUInteger thumbnailSize;
@property (nonatomic, readwrite) NSString *textRepresentation;
@property (nonatomic, readwrite) NSString *mediaMIMEType;
@property (nonatomic, readwrite) NSInputStream *mediaInputStream;
@property (nonatomic, readwrite) NSString *thumbnailMIMEType;
@property (nonatomic, readwrite) NSInputStream *thumbnailInputStream;
@property (nonatomic, readwrite) NSString *metadataMIMEType;
@property (nonatomic, readwrite) NSInputStream *metadataInputStream;

@end

@interface ATLAssetMediaAttachment : ATLMediaAttachment

@property (nonatomic) NSURL *inputAssetURL;

- (instancetype)initWithAssetURL:(NSURL *)assetURL thumbnailSize:(NSUInteger)thumbnailSize;

@end

@interface ATLImageMediaAttachment : ATLMediaAttachment

@property (nonatomic) UIImage *inputImage;

- (instancetype)initWithImage:(UIImage *)image thumbnailSize:(NSUInteger)thumbnailSize;

@end

@interface ATLLocationMediaAttachment : ATLMediaAttachment

- (instancetype)initWithLocation:(CLLocation *)location;

@end

@interface ATLTextMediaAttachment : ATLMediaAttachment

- (instancetype)initWithText:(NSString *)text;

@end

#pragma mark - Private class implementations

@implementation ATLAssetMediaAttachment

- (instancetype)initWithAssetURL:(NSURL *)assetURL thumbnailSize:(NSUInteger)thumbnailSize
{
    self = [super init];
    if (self) {
        if (!assetURL) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Cannot initialize %@ with `nil` assetURL.", self.class] userInfo:nil];
        }
        _inputAssetURL = assetURL;
        self.thumbnailSize = thumbnailSize;
        
        // --------------------------------------------------------------------
        // Fetching the asset from the assets library and bringing
        // it into this thread.
        // --------------------------------------------------------------------
        ALAssetsLibrary *assetLibrary = [[ALAssetsLibrary alloc] init];
        ALAsset *asset = ATLMediaAttachmentFromAssetURL(assetURL, assetLibrary);
        if (!asset) {
            // Asset not found
            return nil;
        }
        NSString *assetType = [asset valueForProperty:ALAssetPropertyType];
        
        // --------------------------------------------------------------------
        // Prepare the input stream and MIMEType for the full size media.
        // --------------------------------------------------------------------
        self.mediaInputStream = [ATLMediaInputStream mediaInputStreamWithAssetURL:asset.defaultRepresentation.url];
        self.mediaMIMEType = (__bridge NSString *)(UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)(asset.defaultRepresentation.UTI), kUTTagClassMIMEType));
        
        // --------------------------------------------------------------------
        // Prepare the input stream and MIMEType for the thumbnail.
        // --------------------------------------------------------------------
        self.thumbnailInputStream = [ATLMediaInputStream mediaInputStreamWithAssetURL:asset.defaultRepresentation.url];
        ((ATLMediaInputStream *)self.thumbnailInputStream).maximumSize = thumbnailSize;
        ((ATLMediaInputStream *)self.thumbnailInputStream).compressionQuality = 0.5;
        self.thumbnailMIMEType = ATLMIMETypeImageJPEGPreview;
        
        // --------------------------------------------------------------------
        // Prepare the input stream and MIMEType for the metadata
        // about the asset.
        // --------------------------------------------------------------------
        NSDictionary *imageMetadata = @{ @"width": @(asset.defaultRepresentation.dimensions.width),
                                         @"height": @(asset.defaultRepresentation.dimensions.height) };
        NSError *JSONSerializerError;
        NSData *JSONData = [NSJSONSerialization dataWithJSONObject:imageMetadata options:NSJSONWritingPrettyPrinted error:&JSONSerializerError];
        if (JSONData) {
            self.metadataInputStream = [NSInputStream inputStreamWithData:JSONData];
            self.metadataMIMEType = ATLMIMETypeImageSize;
        } else {
            NSLog(@"ATLMediaAttachment failed to generate a JSON object for image metadata");
        }
        
        // --------------------------------------------------------------------
        // Prepare the attachable thumbnail meant for UI (which is inlined with
        // text in the message composer).
        // --------------------------------------------------------------------
        self.attachableThumbnailImage = [UIImage imageWithCGImage:asset.aspectRatioThumbnail];
        
        // --------------------------------------------------------------------
        // Set the type - public property.
        // --------------------------------------------------------------------
        if ([assetType isEqualToString:ALAssetTypePhoto]) {
            self.mediaType = ATLMediaAttachmentTypeImage;
        } else if ([assetType isEqualToString:ALAssetTypeVideo]) {
            self.mediaType = ATLMediaAttachmentTypeVideo;
        } else {
            return nil;
        }
        
        self.textRepresentation = @"Attachment: Image";
    }
    return self;
}

@end

@implementation ATLImageMediaAttachment

- (instancetype)initWithImage:(UIImage *)image thumbnailSize:(NSUInteger)thumbnailSize
{
    self = [super init];
    if (self) {
        if (!image) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Cannot initialize %@ with `nil` image.", self.class] userInfo:nil];
        }
        self.mediaType = ATLMediaAttachmentTypeImage;
        self.mediaInputStream = [ATLMediaInputStream mediaInputStreamWithImage:image];
        self.inputImage = image;
        self.thumbnailSize = thumbnailSize;
        self.textRepresentation = @"Attachment: Image";
    }
    return self;
}

@end

@implementation ATLLocationMediaAttachment

- (instancetype)initWithLocation:(CLLocation *)location
{
    self = [super init];
    if (self) {
        if (!location) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Cannot initialize %@ with `nil` location.", self.class] userInfo:nil];
        }
        self.mediaType = ATLMediaAttachmentTypeLocation;
        self.mediaMIMEType = ATLMIMETypeLocation;
        NSData *data = [NSJSONSerialization dataWithJSONObject:@{ ATLLocationLatitudeKey: @(location.coordinate.latitude),
                                                                  ATLLocationLongitudeKey:  @(location.coordinate.longitude) } options:0 error:nil];
        self.mediaInputStream = [NSInputStream inputStreamWithData:data];
        self.textRepresentation = @"Attachment: Location";
    }
    return self;
}

@end

@implementation ATLTextMediaAttachment

- (instancetype)initWithText:(NSString *)text
{
    self = [super init];
    if (self) {
        if (!text) {
            @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"Cannot initialize %@ with `nil` text.", self.class] userInfo:nil];
        }
        self.mediaType = ATLMediaAttachmentTypeText;
        self.mediaMIMEType = ATLMIMETypeTextPlain;
        self.mediaInputStream = [NSInputStream inputStreamWithData:[text dataUsingEncoding:NSUTF8StringEncoding]];
        self.textRepresentation = text;
    }
    return self;
}

@end

@implementation ATLMediaAttachment

#pragma mark - Initializers

+ (instancetype)mediaAttachmentWithAssetURL:(NSURL *)assetURL thumbnailSize:(NSUInteger)thumbnailSize
{
    return [[ATLAssetMediaAttachment alloc] initWithAssetURL:assetURL thumbnailSize:thumbnailSize];
}

+ (instancetype)mediaAttachmentWithImage:(UIImage *)image thumbnailSize:(NSUInteger)thumbnailSize
{
    return [[ATLImageMediaAttachment alloc] initWithImage:image thumbnailSize:thumbnailSize];
}

+ (instancetype)mediaAttachmentWithText:(NSString *)text
{
    return [[ATLTextMediaAttachment alloc] initWithText:text];
}

+ (instancetype)mediaAttachmentWithLocation:(CLLocation *)location
{
    return [[ATLLocationMediaAttachment alloc] initWithLocation:location];
}

#pragma mark - NSTextAttachment Overrides

- (UIImage *)image
{
    return self.attachableThumbnailImage;
}

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer proposedLineFragment:(CGRect)lineFrag glyphPosition:(CGPoint)position characterIndex:(NSUInteger)charIndex
{
    CGRect systemImageRect = [super attachmentBoundsForTextContainer:textContainer proposedLineFragment:lineFrag glyphPosition:position characterIndex:charIndex];
    return ATLImageRectConstrainedToSize(systemImageRect.size, CGSizeMake(150, 150));
}

@end

ALAsset *ATLMediaAttachmentFromAssetURL(NSURL *assetURL, ALAssetsLibrary *assetLibrary)
{
    static dispatch_queue_t asyncQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        asyncQueue = dispatch_queue_create(ATLMediaAttachmentAsyncToBlockingQueueName, DISPATCH_QUEUE_CONCURRENT);
    });
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block ALAsset *resultAsset;
    dispatch_async(asyncQueue, ^{
        [assetLibrary assetForURL:assetURL resultBlock:^(ALAsset *asset) {
            resultAsset = asset;
            dispatch_semaphore_signal(semaphore);
        } failureBlock:^(NSError *libraryError) {
            dispatch_semaphore_signal(semaphore);
        }];
    });
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return resultAsset;
}