#import "main_window.h"
#import "battery_core.h"

@implementation MainWindowController

+ (instancetype)sharedController {
    static MainWindowController *sController = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sController = [[MainWindowController alloc] init];
    });
    return sController;
}

- (instancetype)init {
    NSRect frame = NSMakeRect(100, 100, 960, 680);
    NSWindow *win = [[NSWindow alloc] initWithContentRect:frame
                                                styleMask:(NSWindowStyleMaskTitled |
                                                           NSWindowStyleMaskClosable |
                                                           NSWindowStyleMaskMiniaturizable |
                                                           NSWindowStyleMaskFullSizeContentView)
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
    win.title = @"VoltCraft";
    win.titleVisibility = NSWindowTitleHidden;
    win.titlebarAppearsTransparent = YES;
    win.movableByWindowBackground = YES;
    win.backgroundColor = [NSColor colorWithCalibratedRed:0.08 green:0.085 blue:0.095 alpha:1.0];
    [win setReleasedWhenClosed:NO];
    [win center];

    self = [super initWithWindow:win];
    if (self) {
        [self setupWindowLayout];
    }
    return self;
}

- (void)setupWindowLayout {
    NSWindow *win = self.window;
    NSView *root = win.contentView;
    NSRect bounds = root.bounds;

    CGFloat sidebarW = 210;

    // Sidebar on Left
    self.sidebarView = [[SidebarView alloc] initWithFrame:NSMakeRect(0, 0, sidebarW, bounds.size.height)];
    self.sidebarView.delegate = self;
    self.sidebarView.autoresizingMask = NSViewHeightSizable | NSViewMaxXMargin;
    [root addSubview:self.sidebarView];

    // Content Container on Right
    self.contentContainer = [[NSView alloc] initWithFrame:NSMakeRect(sidebarW, 0, bounds.size.width - sidebarW, bounds.size.height)];
    self.contentContainer.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [root addSubview:self.contentContainer];

    // Initialize All Subviews
    NSRect contentBounds = self.contentContainer.bounds;

    self.dashboardView = [[DashboardView alloc] initWithFrame:contentBounds];
    self.dashboardView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    self.chargeControlView = [[ChargeControlView alloc] initWithFrame:contentBounds];
    self.chargeControlView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    self.sleepBehaviorView = [[SleepBehaviorView alloc] initWithFrame:contentBounds];
    self.sleepBehaviorView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    self.energyUseView = [[EnergyUseView alloc] initWithFrame:contentBounds];
    self.energyUseView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    self.scheduleView = [[ScheduleView alloc] initWithFrame:contentBounds];
    self.scheduleView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    self.shortcutsView = [[ShortcutsView alloc] initWithFrame:contentBounds];
    self.shortcutsView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    self.popoverSettingsView = [[PopoverSettingsView alloc] initWithFrame:contentBounds];
    self.popoverSettingsView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    self.menuBarSettingsView = [[MenuBarSettingsView alloc] initWithFrame:contentBounds];
    self.menuBarSettingsView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    self.otherSettingsView = [[OtherSettingsView alloc] initWithFrame:contentBounds];
    self.otherSettingsView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    // Default to Dashboard
    [self.contentContainer addSubview:self.dashboardView];

    // Background timer to refresh views
    [NSTimer scheduledTimerWithTimeInterval:2.0
                                     target:self
                                   selector:@selector(onTimerTick)
                                   userInfo:nil
                                    repeats:YES];
}

- (void)onTimerTick {
    runEngineCycle();
    if (self.dashboardView.superview) {
        [self.dashboardView refreshTelemetry];
    } else if (self.chargeControlView.superview) {
        [self.chargeControlView refreshUI];
    } else if (self.sleepBehaviorView.superview) {
        [self.sleepBehaviorView refreshUI];
    } else if (self.energyUseView.superview) {
        [self.energyUseView refreshUI];
    }
}

- (void)showDashboard {
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    if (self.dashboardView.superview) {
        [self.dashboardView refreshTelemetry];
    }
}

// --- SidebarViewDelegate ---

- (void)sidebarDidSelectSection:(SidebarSection)section {
    // Remove all current content subviews
    for (NSView *v in [self.contentContainer.subviews copy]) {
        [v removeFromSuperview];
    }

    NSRect contentBounds = self.contentContainer.bounds;

    switch (section) {
        case SidebarSectionDashboard:
            self.dashboardView.frame = contentBounds;
            [self.dashboardView refreshTelemetry];
            [self.contentContainer addSubview:self.dashboardView];
            break;

        case SidebarSectionChargeControl:
            self.chargeControlView.frame = contentBounds;
            [self.chargeControlView refreshUI];
            [self.contentContainer addSubview:self.chargeControlView];
            break;

        case SidebarSectionSleepBehavior:
            self.sleepBehaviorView.frame = contentBounds;
            [self.sleepBehaviorView refreshUI];
            [self.contentContainer addSubview:self.sleepBehaviorView];
            break;

        case SidebarSectionEnergyUse:
            self.energyUseView.frame = contentBounds;
            [self.energyUseView refreshUI];
            [self.contentContainer addSubview:self.energyUseView];
            break;

        case SidebarSectionSchedule:
            self.scheduleView.frame = contentBounds;
            [self.scheduleView refreshUI];
            [self.contentContainer addSubview:self.scheduleView];
            break;

        case SidebarSectionShortcuts:
            self.shortcutsView.frame = contentBounds;
            [self.shortcutsView refreshUI];
            [self.contentContainer addSubview:self.shortcutsView];
            break;

        case SidebarSectionPopover:
            self.popoverSettingsView.frame = contentBounds;
            [self.popoverSettingsView refreshUI];
            [self.contentContainer addSubview:self.popoverSettingsView];
            break;

        case SidebarSectionMenuBar:
            self.menuBarSettingsView.frame = contentBounds;
            [self.menuBarSettingsView refreshUI];
            [self.contentContainer addSubview:self.menuBarSettingsView];
            break;

        case SidebarSectionOther:
            self.otherSettingsView.frame = contentBounds;
            [self.otherSettingsView refreshUI];
            [self.contentContainer addSubview:self.otherSettingsView];
            break;
    }
}

- (void)sidebarDidClickPower {
    [NSApp terminate:nil];
}

- (void)sidebarDidClickHelp {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"VoltCraft";
    alert.informativeText = @"VoltCraft is a native macOS battery charge limiter and hardware health analyzer.\n\nDesigned with zero dependencies using native Apple PowerUI and AppleSMC interfaces.";
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)sidebarDidClickSettings {
    [self.sidebarView selectSection:SidebarSectionOther];
    [self sidebarDidSelectSection:SidebarSectionOther];
}

@end
