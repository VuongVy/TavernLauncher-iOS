#import <UIKit/UIKit.h>
#include <dlfcn.h>

#define realUIIdiom UIDevice.currentDevice.userInterfaceIdiom
extern NSNotificationName UIPresentationControllerPresentationTransitionWillBeginNotification;

@interface UIDevice(hook)
- (NSString *)completeOSVersion;
@end

@interface UIImageView(hook)
@property(nonatomic) BOOL isSizeFixed;
@end

@interface UIImage(hook)
- (UIImage *)hook_imageWithSize:(CGSize)size;
@end

@interface UIBarButtonItem(addition)
- (UIView *)buttonGlassView;
@end

// private functions (resolved dynamically so it links cleanly on iOS 18.5 SDK & works on iOS 26)
static inline BOOL PLIsSolariumEnabled(void) {
    static BOOL (*fn)(void) = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fn = (BOOL (*)(void))dlsym(RTLD_DEFAULT, "_UISolariumEnabled");
    });
    return fn ? fn() : NO;
}

@interface UIBarButtonItem(private)
- (UIView *)view;
@end

@interface UIContextMenuInteraction(private)
- (void)_presentMenuAtLocation:(CGPoint)location;
@end
@interface _UIContextMenuStyle : NSObject <NSCopying>
@property(nonatomic) NSInteger preferredLayout;
+ (instancetype)defaultStyle;
@end

@interface UIDevice(private)
- (NSString *)buildVersion;
- (void)_setActiveUserInterfaceIdiom:(NSInteger)idiom;
@end

@interface UIImage(private)
- (UIImage *)_imageWithSize:(CGSize)size;
@end

@interface UIScreen(private)
- (void)_setUserInterfaceIdiom:(NSInteger)idiom;
@end

@interface UISegmentedControl(private)
- (NSArray *)_uiktest_labelsWithState:(NSUInteger)state;
@end

@interface UITextField(private)
@property(assign, nonatomic) NSInteger nonEditingLinebreakMode;
@end

@interface UIWindow(global)
+ (UIWindow *)mainWindow;
+ (UIWindow *)externalWindow;
@end

@protocol _UIPointerInteractionDriver<NSObject>
@property (assign, nonatomic) UIView *view;
@end

@interface UIPointerInteraction(private)
- (NSArray <id<_UIPointerInteractionDriver>> *)drivers;
- (id<_UIPointerInteractionDriver>)driver;
@end

@interface UIPopoverPresentationController(private)
- (BOOL)_isDismissing;
@end

/*
@interface WFTextTokenTextView : UITextField
@property(nonatomic) NSString* placeholder
@end
*/
