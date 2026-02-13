#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <objc/message.h>

@interface YTMainAppVideoPlayerOverlayView : UIView
@end

@interface YTPivotBarItemView : UIView
@end

static NSInteger YTLSettingsFixSpeedIndex(void) {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.dvntm.ytlite"];
    return [defaults integerForKey:@"speedIndex"];
}

static NSString *YTLSettingsFixGestureActionName(UIGestureRecognizer *gesture) {
    @try {
        NSArray *targets = [gesture valueForKey:@"_targets"];
        for (id targetAction in targets) {
            id actionValue = nil;
            @try {
                actionValue = [targetAction valueForKey:@"_action"];
            } @catch (...) {
                actionValue = nil;
            }

            if ([actionValue isKindOfClass:[NSValue class]]) {
                SEL action = ((SEL (*)(id, SEL))objc_msgSend)(actionValue, @selector(pointerValue));
                if (action != NULL) {
                    return NSStringFromSelector(action);
                }
            }
        }
    } @catch (...) {
    }

    return nil;
}

static BOOL YTLSettingsFixLooksLikeSpeedmasterGesture(UILongPressGestureRecognizer *gesture) {
    NSString *actionName = YTLSettingsFixGestureActionName(gesture);
    if ([actionName isEqualToString:@"speedmasterYtLite:"]) {
        return YES;
    }

    return (gesture.numberOfTouchesRequired == 1 && gesture.minimumPressDuration >= 0.29 && gesture.minimumPressDuration <= 0.31);
}

static BOOL YTLSettingsFixLooksLikeManageTabGesture(UILongPressGestureRecognizer *gesture) {
    NSString *actionName = YTLSettingsFixGestureActionName(gesture);
    if ([actionName isEqualToString:@"manageTab:"]) {
        return YES;
    }

    return (gesture.numberOfTouchesRequired == 1 && gesture.minimumPressDuration >= 0.29 && gesture.minimumPressDuration <= 0.31);
}

%hook YTMainAppVideoPlayerOverlayView
- (void)setSeekAnywherePanGestureRecognizer:(id)recognizer {
    %orig;

    NSMutableArray<UILongPressGestureRecognizer *> *speedmasterGestures = [NSMutableArray array];

    for (UIGestureRecognizer *gesture in [self.gestureRecognizers copy]) {
        if (![gesture isKindOfClass:[UILongPressGestureRecognizer class]]) {
            continue;
        }

        UILongPressGestureRecognizer *longPress = (UILongPressGestureRecognizer *)gesture;
        if (YTLSettingsFixLooksLikeSpeedmasterGesture(longPress)) {
            [speedmasterGestures addObject:longPress];
        }
    }

    if (speedmasterGestures.count == 0) {
        return;
    }

    if (YTLSettingsFixSpeedIndex() == 0) {
        for (UILongPressGestureRecognizer *gesture in speedmasterGestures) {
            [self removeGestureRecognizer:gesture];
        }
        return;
    }

    for (NSUInteger i = 1; i < speedmasterGestures.count; i++) {
        [self removeGestureRecognizer:speedmasterGestures[i]];
    }
}
%end

%hook YTPivotBarItemView
- (void)setRenderer:(id)renderer {
    %orig;

    NSString *pivotIdentifier = nil;
    @try {
        id currentRenderer = [self valueForKey:@"renderer"];
        pivotIdentifier = [currentRenderer valueForKey:@"pivotIdentifier"];
    } @catch (...) {
        pivotIdentifier = nil;
    }

    if (![pivotIdentifier isKindOfClass:[NSString class]] || ![pivotIdentifier isEqualToString:@"FEwhat_to_watch"]) {
        return;
    }

    NSMutableArray<UILongPressGestureRecognizer *> *manageTabGestures = [NSMutableArray array];

    for (UIGestureRecognizer *gesture in [self.gestureRecognizers copy]) {
        if (![gesture isKindOfClass:[UILongPressGestureRecognizer class]]) {
            continue;
        }

        UILongPressGestureRecognizer *longPress = (UILongPressGestureRecognizer *)gesture;
        if (YTLSettingsFixLooksLikeManageTabGesture(longPress)) {
            [manageTabGestures addObject:longPress];
        }
    }

    for (NSUInteger i = 1; i < manageTabGestures.count; i++) {
        [self removeGestureRecognizer:manageTabGestures[i]];
    }
}
%end
