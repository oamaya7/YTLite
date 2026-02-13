/* YouTube Native Share - An iOS Tweak to replace YouTube's share sheet and remove source identifiers.
 * Copyright (C) 2024 YouTube Native Share Contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

// Source code can be found here: https://github.com/jkhsjdhjs/youtube-native-share (Thanks to @jkhsjdhjs) 

#include <UIKit/UIActivityViewController.h>
#include <objc/message.h>

#import "../YouTubeHeader/YTUIUtils.h"

#import "../protobuf/objectivec/GPBDescriptor.h"
#import "../protobuf/objectivec/GPBMessage.h"
#import "../protobuf/objectivec/GPBUnknownField.h"
#if __has_include("../protobuf/objectivec/GPBUnknownFieldSet.h")
#import "../protobuf/objectivec/GPBUnknownFieldSet.h"
#else
#import "../protobuf/objectivec/GPBUnknownFields.h"
#endif

#define ytlBool(key)  [[[NSUserDefaults alloc] initWithSuiteName:@"com.dvntm.ytlite"] boolForKey:key]

@interface CustomGPBMessage : GPBMessage
+ (instancetype)deserializeFromString:(NSString *)string;
@end

@interface YTICommand : GPBMessage
@end

@interface ELMPBCommand : GPBMessage
@end

@interface ELMPBShowActionSheetCommand : GPBMessage
@property (nonatomic, strong, readwrite) ELMPBCommand *onAppear;
@property (nonatomic, assign, readwrite) BOOL hasOnAppear;
@end

@interface YTIUpdateShareSheetCommand
@property (nonatomic, assign, readwrite) BOOL hasSerializedShareEntity;
@property (nonatomic, copy, readwrite) NSString *serializedShareEntity;
+ (GPBExtensionDescriptor*)updateShareSheetCommand;
@end

@interface YTIInnertubeCommandExtensionRoot
+ (GPBExtensionDescriptor*)innertubeCommand;
@end

typedef NS_ENUM(NSInteger, ShareEntityType) {
    ShareEntityFieldVideo = 1,
    ShareEntityFieldPlaylist = 2,
    ShareEntityFieldChannel = 3,
    ShareEntityFieldClip = 8
};

static inline id ytlUnknownFieldsForMessage(GPBMessage *message) {
    if (!message) return nil;

    @try {
        id unknownFields = [message valueForKey:@"unknownFields"];
        if (unknownFields) return unknownFields;
    } @catch (...) {}

    Class unknownFieldsClass = NSClassFromString(@"GPBUnknownFields");
    if (unknownFieldsClass && [unknownFieldsClass instancesRespondToSelector:@selector(initFromMessage:)]) {
        return [[unknownFieldsClass alloc] initFromMessage:message];
    }

    return nil;
}

static inline NSData *ytlFirstLengthDelimited(id fields, NSInteger fieldNumber) {
    if (!fields) return nil;

    if ([fields respondsToSelector:@selector(hasField:)] && [fields respondsToSelector:@selector(getField:)]) {
        BOOL hasField = ((BOOL (*)(id, SEL, NSInteger))objc_msgSend)(fields, @selector(hasField:), fieldNumber);
        if (!hasField) return nil;

        id unknownField = ((id (*)(id, SEL, NSInteger))objc_msgSend)(fields, @selector(getField:), fieldNumber);
        NSArray *payloads = [unknownField valueForKey:@"lengthDelimitedList"];
        if (![payloads isKindOfClass:[NSArray class]] || payloads.count != 1) return nil;

        id payload = payloads.firstObject;
        return [payload isKindOfClass:[NSData class]] ? (NSData *)payload : nil;
    }

    if ([fields respondsToSelector:@selector(fields:)]) {
        NSArray *matchedFields = ((id (*)(id, SEL, int32_t))objc_msgSend)(fields, @selector(fields:), (int32_t)fieldNumber);
        if (![matchedFields isKindOfClass:[NSArray class]] || matchedFields.count != 1) return nil;

        id unknownField = matchedFields.firstObject;
        id payload = nil;
        @try {
            payload = [unknownField valueForKey:@"lengthDelimited"];
        } @catch (...) {
            payload = nil;
        }

        return [payload isKindOfClass:[NSData class]] ? (NSData *)payload : nil;
    }

    return nil;
}

static inline NSString* extractIdWithFormat(id fields, NSInteger fieldNumber, NSString *format) {
    NSData *payload = ytlFirstLengthDelimited(fields, fieldNumber);
    if (!payload) return nil;

    NSString *id = [[NSString alloc] initWithData:payload encoding:NSUTF8StringEncoding];
    return [NSString stringWithFormat:format, id];
}

%hook ELMPBShowActionSheetCommand
- (void)executeWithCommandContext:(id)_context handler:(id)_handler {
    if (!ytlBool(@"nativeShare"))
        return %orig;

    if (!self.hasOnAppear)
        return %orig;
    GPBExtensionDescriptor *innertubeCommandDescriptor = [%c(YTIInnertubeCommandExtensionRoot) innertubeCommand];
    if (![self.onAppear hasExtension:innertubeCommandDescriptor])
        return %orig;
    YTICommand *innertubeCommand = [self.onAppear getExtension:innertubeCommandDescriptor];
    GPBExtensionDescriptor *updateShareSheetCommandDescriptor = [%c(YTIUpdateShareSheetCommand) updateShareSheetCommand];
    if(![innertubeCommand hasExtension:updateShareSheetCommandDescriptor])
        return %orig;
    YTIUpdateShareSheetCommand *updateShareSheetCommand = [innertubeCommand getExtension:updateShareSheetCommandDescriptor];
    if (!updateShareSheetCommand.hasSerializedShareEntity)
        return %orig;

    GPBMessage *shareEntity = [%c(GPBMessage) deserializeFromString:updateShareSheetCommand.serializedShareEntity];
    id fields = ytlUnknownFieldsForMessage(shareEntity);
    if (!fields) return %orig;

    NSString *shareUrl;

    NSData *clipPayload = ytlFirstLengthDelimited(fields, ShareEntityFieldClip);
    if (clipPayload) {
        GPBMessage *clipMessage = [%c(GPBMessage) parseFromData:clipPayload error:nil];
        id clipFields = ytlUnknownFieldsForMessage(clipMessage);
        shareUrl = extractIdWithFormat(clipFields, 1, @"https://youtube.com/clip/%@");
    }

    if (!shareUrl)
        shareUrl = extractIdWithFormat(fields, ShareEntityFieldChannel, @"https://youtube.com/channel/%@");

    if (!shareUrl) {
        shareUrl = extractIdWithFormat(fields, ShareEntityFieldPlaylist, @"%@");
        if (shareUrl) {
            if (![shareUrl hasPrefix:@"PL"] && ![shareUrl hasPrefix:@"FL"])
                shareUrl = [shareUrl stringByAppendingString:@"&playnext=1"];
            shareUrl = [@"https://youtube.com/playlist?list=" stringByAppendingString:shareUrl];
        }
    }

    if (!shareUrl)
        shareUrl = extractIdWithFormat(fields, ShareEntityFieldVideo, @"https://youtube.com/watch?v=%@");

    if (!shareUrl)
        return %orig;

    UIActivityViewController *activityViewController = [[UIActivityViewController alloc]initWithActivityItems:@[shareUrl] applicationActivities:nil];
    [[%c(YTUIUtils) topViewControllerForPresenting] presentViewController:activityViewController animated:YES completion:^{}];
}
%end
