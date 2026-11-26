#import "authenticator/BaseAuthenticator.h"
#import "installer/modpack/ModrinthAPI.h"
#import "LauncherMenuViewController.h"
#import "LauncherNavigationController.h"
#import "LauncherNewsViewController.h"
#import "LauncherPreferences.h"
#import "PLProfiles.h"
#import "UIImageView+AFNetworking.h"
#import "utils.h"

static NSString *const kTavernPackURL = @"https://cdn.rexon-tech.cloud/cobbleverse-android.mrpack";
static NSString *const kTavernProfileName = @"TavernCraft Mobile Lite";
static NSString *const kTavernServerAddr = @"tavern.rexon-tech.cloud";

@interface LauncherNewsViewController ()
@property(nonatomic, strong) CAGradientLayer *bgGradient;
@property(nonatomic, strong) UIScrollView *scrollView;
@property(nonatomic, strong) UIControl *accountCard;
@property(nonatomic, strong) UIImageView *avatarView;
@property(nonatomic, strong) UILabel *accountTitleLabel;
@property(nonatomic, strong) UILabel *accountSubLabel;
@property(nonatomic, strong) UIButton *primaryButton;
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UILabel *ramWarnLabel;
@property(nonatomic, assign) BOOL installingPack;
@end

@implementation LauncherNewsViewController

- (id)init {
    self = [super init];
    self.title = @"TavernCraft";
    return self;
}

- (NSString *)imageName {
    return @"MenuNews";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:11/255.0 green:13/255.0 blue:19/255.0 alpha:1.0];

    self.bgGradient = [CAGradientLayer layer];
    self.bgGradient.colors = @[
        (id)[UIColor colorWithRed:21/255.0 green:27/255.0 blue:43/255.0 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:11/255.0 green:13/255.0 blue:19/255.0 alpha:1.0].CGColor
    ];
    self.bgGradient.startPoint = CGPointMake(0.5, 0.0);
    self.bgGradient.endPoint = CGPointMake(0.5, 1.0);
    [self.view.layer insertSublayer:self.bgGradient atIndex:0];

    [self setupTavernHomeUI];

    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(refreshState) name:@"TavernCraftAccountUpdated" object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handleProfileUpdated) name:@"TavernCraftProfileUpdated" object:nil];

    self.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
    self.navigationItem.rightBarButtonItem = [sidebarViewController drawAccountButton];
    self.navigationItem.leftItemsSupplementBackButton = YES;

    [self refreshState];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshState];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.bgGradient.frame = self.view.bounds;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

#pragma mark - UI Construction (Matches Android TavernCraftLauncher 1-to-1)

- (void)setupTavernHomeUI {
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];

    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:container];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 14.0;
    [container addSubview:stack];

    // 1. TavernCraft Logo (210 x 105)
    UIImage *logoImg = [UIImage imageNamed:@"taverncraft_logo.png"] ?: [UIImage imageNamed:@"AppLogo"];
    UIImageView *logoView = [[UIImageView alloc] initWithImage:logoImg];
    logoView.translatesAutoresizingMaskIntoConstraints = NO;
    logoView.contentMode = UIViewContentModeScaleAspectFit;
    [NSLayoutConstraint activateConstraints:@[
        [logoView.widthAnchor constraintEqualToConstant:210],
        [logoView.heightAnchor constraintEqualToConstant:105],
    ]];
    [stack addArrangedSubview:logoView];

    // 2. Subtitle
    UILabel *subLabel = [[UILabel alloc] init];
    subLabel.text = @"MINECRAFT 1.21.1 • FABRIC • iOS";
    subLabel.textColor = [UIColor colorWithRed:139/255.0 green:149/255.0 blue:173/255.0 alpha:1.0];
    subLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    [stack addArrangedSubview:subLabel];

    // 3. Account Selector Card
    self.accountCard = [[UIControl alloc] init];
    self.accountCard.translatesAutoresizingMaskIntoConstraints = NO;
    self.accountCard.backgroundColor = [UIColor colorWithRed:20/255.0 green:24/255.0 blue:36/255.0 alpha:1.0];
    self.accountCard.layer.cornerRadius = 12.0;
    self.accountCard.layer.borderWidth = 1.0;
    self.accountCard.layer.borderColor = [UIColor colorWithRed:40/255.0 green:50/255.0 blue:74/255.0 alpha:1.0].CGColor;
    [self.accountCard addTarget:self action:@selector(onTapAccountCard:) forControlEvents:UIControlEventTouchUpInside];

    self.avatarView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"DefaultAccount"]];
    self.avatarView.translatesAutoresizingMaskIntoConstraints = NO;
    self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarView.clipsToBounds = YES;
    self.avatarView.layer.cornerRadius = 6.0;
    [self.accountCard addSubview:self.avatarView];

    UIStackView *accTextStack = [[UIStackView alloc] init];
    accTextStack.translatesAutoresizingMaskIntoConstraints = NO;
    accTextStack.axis = UILayoutConstraintAxisVertical;
    accTextStack.spacing = 2.0;
    accTextStack.userInteractionEnabled = NO;

    self.accountTitleLabel = [[UILabel alloc] init];
    self.accountTitleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    [accTextStack addArrangedSubview:self.accountTitleLabel];

    self.accountSubLabel = [[UILabel alloc] init];
    self.accountSubLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    self.accountSubLabel.textColor = [UIColor colorWithRed:139/255.0 green:149/255.0 blue:173/255.0 alpha:1.0];
    self.accountSubLabel.numberOfLines = 1;
    [accTextStack addArrangedSubview:self.accountSubLabel];
    [self.accountCard addSubview:accTextStack];

    UILabel *changeLbl = [[UILabel alloc] init];
    changeLbl.translatesAutoresizingMaskIntoConstraints = NO;
    changeLbl.text = @"Đổi";
    changeLbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    changeLbl.textColor = [UIColor colorWithRed:148/255.0 green:163/255.0 blue:184/255.0 alpha:1.0];
    changeLbl.userInteractionEnabled = NO;
    [self.accountCard addSubview:changeLbl];

    [NSLayoutConstraint activateConstraints:@[
        [self.avatarView.leadingAnchor constraintEqualToAnchor:self.accountCard.leadingAnchor constant:14],
        [self.avatarView.centerYAnchor constraintEqualToAnchor:self.accountCard.centerYAnchor],
        [self.avatarView.widthAnchor constraintEqualToConstant:30],
        [self.avatarView.heightAnchor constraintEqualToConstant:30],

        [accTextStack.leadingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor constant:10],
        [accTextStack.centerYAnchor constraintEqualToAnchor:self.accountCard.centerYAnchor],
        [accTextStack.trailingAnchor constraintLessThanOrEqualToAnchor:changeLbl.leadingAnchor constant:-8],

        [changeLbl.trailingAnchor constraintEqualToAnchor:self.accountCard.trailingAnchor constant:-14],
        [changeLbl.centerYAnchor constraintEqualToAnchor:self.accountCard.centerYAnchor],

        [self.accountCard.heightAnchor constraintEqualToConstant:58],
    ]];
    [stack addArrangedSubview:self.accountCard];

    // 4. Primary INSTALL / PLAY Button
    self.primaryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.primaryButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.primaryButton.layer.cornerRadius = 12.0;
    self.primaryButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightHeavy];
    [self.primaryButton setTitleColor:[UIColor colorWithRed:11/255.0 green:13/255.0 blue:19/255.0 alpha:1.0] forState:UIControlStateNormal];
    [self.primaryButton addTarget:self action:@selector(onTapPrimary:) forControlEvents:UIControlEventTouchUpInside];
    [self.primaryButton.heightAnchor constraintEqualToConstant:50].active = YES;
    [stack addArrangedSubview:self.primaryButton];

    // 5. Secondary Quick Actions Row: [Bố cục phím] [Cập nhật gói]
    UIStackView *secRow = [[UIStackView alloc] init];
    secRow.translatesAutoresizingMaskIntoConstraints = NO;
    secRow.axis = UILayoutConstraintAxisHorizontal;
    secRow.distribution = UIStackViewDistributionFillEqually;
    secRow.spacing = 10.0;

    UIButton *ctrlBtn = [self makeSecondaryButton:@"Bố cục phím" action:@selector(onTapControls)];
    UIButton *syncBtn = [self makeSecondaryButton:@"Cập nhật gói" action:@selector(onTapUpdatePack)];
    [secRow addArrangedSubview:ctrlBtn];
    [secRow addArrangedSubview:syncBtn];
    [secRow.heightAnchor constraintEqualToConstant:38].active = YES;
    [stack addArrangedSubview:secRow];

    // 6. Status Label
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.statusLabel.textColor = [UIColor colorWithRed:148/255.0 green:163/255.0 blue:184/255.0 alpha:1.0];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 2;
    [stack addArrangedSubview:self.statusLabel];

    // 7. RAM Warning (for < 5GB devices)
    self.ramWarnLabel = [[UILabel alloc] init];
    self.ramWarnLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    self.ramWarnLabel.textColor = [UIColor colorWithRed:245/255.0 green:185/255.0 blue:66/255.0 alpha:1.0];
    self.ramWarnLabel.textAlignment = NSTextAlignmentCenter;
    self.ramWarnLabel.numberOfLines = 2;
    double physGB = (double)NSProcessInfo.processInfo.physicalMemory / (1024.0 * 1024.0 * 1024.0);
    if (physGB < 5.2) {
        self.ramWarnLabel.text = [NSString stringWithFormat:@"⚠ Máy bạn có %.1fGB RAM (khuyến nghị 6GB+ & bật Increased Memory Limit)", physGB];
        self.ramWarnLabel.hidden = NO;
    } else {
        self.ramWarnLabel.hidden = YES;
    }
    [stack addArrangedSubview:self.ramWarnLabel];

    // 8. Network Footer
    UILabel *footer = [[UILabel alloc] init];
    footer.text = @"TAVERNCRAFT NETWORK • tavern.rexon-tech.cloud";
    footer.font = [UIFont systemFontOfSize:10 weight:UIFontWeightMedium];
    footer.textColor = [UIColor colorWithRed:71/255.0 green:85/255.0 blue:105/255.0 alpha:1.0];
    [stack addArrangedSubview:footer];

    // Constraints (max 380pt wide, centered vertically & horizontally)
    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    NSLayoutConstraint *maxW = [stack.widthAnchor constraintLessThanOrEqualToConstant:380];
    NSLayoutConstraint *prefW = [stack.widthAnchor constraintEqualToAnchor:container.widthAnchor constant:-40];
    prefW.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],

        [container.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [container.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [container.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [container.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [container.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],
        [container.heightAnchor constraintGreaterThanOrEqualToAnchor:self.scrollView.frameLayoutGuide.heightAnchor],

        [stack.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [stack.topAnchor constraintGreaterThanOrEqualToAnchor:container.topAnchor constant:20],
        [stack.bottomAnchor constraintLessThanOrEqualToAnchor:container.bottomAnchor constant:-20],
        maxW,
        prefW,

        [self.accountCard.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [self.primaryButton.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
        [secRow.widthAnchor constraintEqualToAnchor:stack.widthAnchor],
    ]];
}

- (UIButton *)makeSecondaryButton:(NSString *)title action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.backgroundColor = [UIColor colorWithRed:20/255.0 green:27/255.0 blue:44/255.0 alpha:1.0];
    btn.layer.cornerRadius = 10.0;
    btn.layer.borderWidth = 1.0;
    btn.layer.borderColor = [UIColor colorWithRed:40/255.0 green:50/255.0 blue:74/255.0 alpha:1.0].CGColor;
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor colorWithRed:203/255.0 green:213/255.0 blue:225/255.0 alpha:1.0] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

#pragma mark - State & Actions

- (NSString *)installedTavernProfileName {
    NSDictionary *profiles = PLProfiles.current.profiles;
    if (profiles[kTavernProfileName]) {
        NSString *verId = profiles[kTavernProfileName][@"lastVersionId"];
        NSString *jsonPath = [NSString stringWithFormat:@"%s/versions/%@/%@.json", getenv("GAME_DIR"), verId, verId];
        if ([NSFileManager.defaultManager fileExistsAtPath:jsonPath]) {
            return kTavernProfileName;
        }
    }
    return nil;
}

- (void)handleProfileUpdated {
    self.installingPack = NO;
    [self refreshState];
}

- (void)refreshState {
    NSDictionary *auth = BaseAuthenticator.current.authData;
    if (auth != nil && [auth[@"username"] length] > 0) {
        NSString *uname = auth[@"username"];
        if ([uname hasPrefix:@"Demo."]) uname = [uname substringFromIndex:5];
        self.accountTitleLabel.text = uname;
        self.accountTitleLabel.textColor = UIColor.whiteColor;
        self.accountSubLabel.text = auth[@"xboxGamertag"] ? @"Tài khoản Microsoft" : @"Tài khoản Offline (EasyAuth)";
        NSString *pic = [auth[@"profilePicURL"] stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
        if (pic.length > 0) {
            [self.avatarView setImageWithURL:[NSURL URLWithString:pic] placeholderImage:[UIImage imageNamed:@"DefaultAccount"]];
        } else {
            self.avatarView.image = [UIImage imageNamed:@"DefaultAccount"];
        }
    } else {
        self.accountTitleLabel.text = @"Chưa có tài khoản";
        self.accountTitleLabel.textColor = [UIColor colorWithRed:245/255.0 green:185/255.0 blue:66/255.0 alpha:1.0];
        self.accountSubLabel.text = @"Chạm để nhập tên hoặc đăng nhập Microsoft";
        self.avatarView.image = [UIImage imageNamed:@"DefaultAccount"];
    }

    BOOL installed = ([self installedTavernProfileName] != nil);
    if (self.installingPack) {
        [self.primaryButton setTitle:@"ĐANG TẢI..." forState:UIControlStateNormal];
        self.primaryButton.backgroundColor = [UIColor colorWithRed:56/255.0 green:193/255.0 blue:114/255.0 alpha:0.7];
        self.primaryButton.enabled = NO;
        self.statusLabel.text = @"Đang tải gói cài đặt TavernCraft từ CDN (xem tiến độ ở thanh dưới)...";
    } else if (installed) {
        [self.primaryButton setTitle:@"PLAY" forState:UIControlStateNormal];
        self.primaryButton.backgroundColor = UIColor.whiteColor;
        self.primaryButton.enabled = YES;
        self.statusLabel.text = [NSString stringWithFormat:@"✓ Sẵn sàng vào %@ (tự động nối máy chủ)", kTavernServerAddr];
    } else {
        [self.primaryButton setTitle:@"INSTALL" forState:UIControlStateNormal];
        self.primaryButton.backgroundColor = [UIColor colorWithRed:56/255.0 green:193/255.0 blue:114/255.0 alpha:1.0];
        self.primaryButton.enabled = YES;
        self.statusLabel.text = @"Chạm INSTALL để tự tải Cobbleverse Mobile Lite (75 mods)";
    }
}

- (void)onTapAccountCard:(UIControl *)sender {
    [sidebarViewController selectAccount:(UIButton *)sender];
}

- (void)onTapPrimary:(UIButton *)sender {
    if (BaseAuthenticator.current == nil) {
        [sidebarViewController selectAccount:sender];
        return;
    }

    LauncherNavigationController *nav = (LauncherNavigationController *)self.navigationController;
    NSString *profileName = [self installedTavernProfileName];
    if (profileName != nil) {
        PLProfiles.current.selectedProfileName = profileName;
        [PLProfiles.current save];
        [nav reloadProfileList];
        [nav launchMinecraft:sender];
    } else {
        [self startModpackInstall];
    }
}

- (void)onTapControls {
    LauncherNavigationController *nav = (LauncherNavigationController *)self.navigationController;
    [nav enterCustomControls];
}

- (void)onTapUpdatePack {
    if (BaseAuthenticator.current == nil) {
        [sidebarViewController selectAccount:self.primaryButton];
        return;
    }
    [self startModpackInstall];
}

- (void)startModpackInstall {
    if (self.installingPack) return;
    self.installingPack = YES;
    [self refreshState];

    ModrinthAPI *api = [[ModrinthAPI alloc] init];
    NSDictionary *detail = @{
        @"title": kTavernProfileName,
        @"versionUrls": @[kTavernPackURL],
        @"versionSizes": @[@(0)],
        @"versionHashes": @[@""],
    };
    [NSNotificationCenter.defaultCenter postNotificationName:@"InstallModpack"
                                                      object:api
                                                    userInfo:@{@"detail": detail, @"index": @(0)}];
}

@end
