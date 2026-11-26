#import <UIKit/UIKit.h>

NSMutableArray<NSDictionary *> *localVersionList, *remoteVersionList;

@interface LauncherNavigationController : UINavigationController

@property(nonatomic) UIProgressView *progressViewMain, *progressViewSub;
@property(nonatomic) UILabel* progressText;

- (void)enterModInstallerWithPath:(NSString *)path hitEnterAfterWindowShown:(BOOL)hitEnter;
- (void)enterCustomControls;
- (void)fetchLocalVersionList;
- (void)reloadProfileList;
- (void)launchMinecraft:(UIButton *)sender;
- (void)setInteractionEnabled:(BOOL)enable forDownloading:(BOOL)downloading;

@end
