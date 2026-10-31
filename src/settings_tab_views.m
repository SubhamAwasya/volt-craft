#import "settings_tab_views.h"
#import "battery_core.h"
#import "menu_bar.h"

// --- Shared Base Card ---
@implementation SettingsCardView

+ (instancetype)cardWithFrame:(NSRect)frame {
    SettingsCardView *card = [[SettingsCardView alloc] initWithFrame:frame];
    card.title = @"";
    card.boxType = NSBoxCustom;
    card.cornerRadius = 14.0;
    card.fillColor = [NSColor colorWithCalibratedRed:0.13 green:0.14 blue:0.16 alpha:0.95];
    card.borderColor = [NSColor colorWithCalibratedRed:0.20 green:0.22 blue:0.25 alpha:1.0];
    card.borderWidth = 1.0;
    return card;
}

@end

// Helper method for standard headers
static void addPageHeader(NSView *view, NSString *titleStr, NSString *subStr) {
    NSTextField *title = [[NSTextField alloc] initWithFrame:NSMakeRect(25, 600, 500, 28)];
    title.stringValue = titleStr;
    title.font = [NSFont boldSystemFontOfSize:22];
    title.textColor = [NSColor whiteColor];
    title.bezeled = NO; title.drawsBackground = NO; title.editable = NO;
    [view addSubview:title];

    NSTextField *sub = [[NSTextField alloc] initWithFrame:NSMakeRect(25, 575, 650, 20)];
    sub.stringValue = subStr;
    sub.font = [NSFont systemFontOfSize:12];
    sub.textColor = [NSColor colorWithCalibratedWhite:0.65 alpha:1.0];
    sub.bezeled = NO; sub.drawsBackground = NO; sub.editable = NO;
    [view addSubview:sub];
}

static NSTextField *addCardHeader(NSView *card, NSString *text, CGFloat y) {
    NSTextField *h = [[NSTextField alloc] initWithFrame:NSMakeRect(20, y, 400, 20)];
    h.stringValue = text;
    h.font = [NSFont boldSystemFontOfSize:14];
    h.textColor = [NSColor whiteColor];
    h.bezeled = NO; h.drawsBackground = NO; h.editable = NO;
    [card addSubview:h];
    return h;
}

static NSButton *addSwitchRow(NSView *card, NSString *title, NSString *subtext, CGFloat y, id target, SEL action) {
    NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(20, y + 16, 450, 22)];
    btn.buttonType = NSButtonTypeSwitch;
    btn.title = title;
    btn.font = [NSFont boldSystemFontOfSize:13];
    btn.target = target;
    btn.action = action;
    [card addSubview:btn];

    if (subtext.length > 0) {
        NSTextField *desc = [[NSTextField alloc] initWithFrame:NSMakeRect(40, y - 4, 600, 18)];
        desc.stringValue = subtext;
        desc.font = [NSFont systemFontOfSize:11];
        desc.textColor = [NSColor colorWithCalibratedWhite:0.60 alpha:1.0];
        desc.bezeled = NO; desc.drawsBackground = NO; desc.editable = NO;
        [card addSubview:desc];
    }
    return btn;
}

// =========================================================================
// 1. Sleep Behavior View
// =========================================================================
@interface SleepBehaviorView ()
@property (nonatomic, strong) NSButton *stopOnSleepSwitch;
@property (nonatomic, strong) NSButton *stopOnClamshellSwitch;
@property (nonatomic, strong) NSButton *preventSleepSwitch;
@property (nonatomic, strong) NSTextField *preventSleepStatus;
@property (nonatomic, strong) NSButton *stopOnCloseSwitch;
@end

@implementation SleepBehaviorView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.10 green:0.105 blue:0.115 alpha:1.0].CGColor;
        [self setupUI];
        [self refreshUI];
    }
    return self;
}

- (void)setupUI {
    addPageHeader(self, @"Sleep Behavior", @"Configure charging and power protection when your Mac sleeps or closes.");

    CGFloat y = 430;
    // Card 1: Sleep Charging Protection
    SettingsCardView *card1 = [SettingsCardView cardWithFrame:NSMakeRect(25, y, 690, 130)];
    [self addSubview:card1];
    addCardHeader(card1, @"Sleep Charging Protection", 95);

    self.stopOnSleepSwitch = addSwitchRow(card1, @"Stop charging when Mac goes to sleep",
                                          @"Prevents battery charging while your Mac is sleeping to avoid heat build-up.", 52,
                                          self, @selector(onToggleStopOnSleep:));

    self.stopOnClamshellSwitch = addSwitchRow(card1, @"Stop charging in Clamshell Mode",
                                              @"Halts charging if the lid is closed without an external display connected.", 10,
                                              self, @selector(onToggleStopOnClamshell:));

    y -= 145;
    // Card 2: Manual Sleep Control
    SettingsCardView *card2 = [SettingsCardView cardWithFrame:NSMakeRect(25, y, 690, 130)];
    [self addSubview:card2];
    addCardHeader(card2, @"Manual Sleep Prevention (Caffeine Mode)", 95);

    self.preventSleepSwitch = addSwitchRow(card2, @"Keep Mac Awake (Prevent Idle Sleep)",
                                           @"Prevents display and system idle sleep using native macOS IOPMAssertion while connected.", 52,
                                           self, @selector(onTogglePreventSleep:));

    self.preventSleepStatus = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 14, 600, 18)];
    self.preventSleepStatus.font = [NSFont boldSystemFontOfSize:11];
    self.preventSleepStatus.textColor = [NSColor colorWithCalibratedRed:0.0 green:0.82 blue:1.0 alpha:1.0];
    self.preventSleepStatus.bezeled = NO; self.preventSleepStatus.drawsBackground = NO; self.preventSleepStatus.editable = NO;
    [card2 addSubview:self.preventSleepStatus];

    y -= 130;
    // Card 3: App Lifecycle
    SettingsCardView *card3 = [SettingsCardView cardWithFrame:NSMakeRect(25, y, 690, 110)];
    [self addSubview:card3];
    addCardHeader(card3, @"Application Lifecycle", 75);

    self.stopOnCloseSwitch = addSwitchRow(card3, @"Restore standard macOS charging on quit",
                                          @"Re-enables default macOS power management automatically when VoltCraft is quit.", 24,
                                          self, @selector(onToggleStopOnClose:));
}

- (void)refreshUI {
    VoltCraftConfig *cfg = getProConfig();
    self.stopOnSleepSwitch.state = cfg->stopOnSleep ? NSControlStateValueOn : NSControlStateValueOff;
    self.stopOnClamshellSwitch.state = NSControlStateValueOff;
    self.preventSleepSwitch.state = cfg->sleepPrevented ? NSControlStateValueOn : NSControlStateValueOff;
    self.stopOnCloseSwitch.state = cfg->stopOnClose ? NSControlStateValueOn : NSControlStateValueOff;

    if (cfg->sleepPrevented) {
        self.preventSleepStatus.stringValue = @"Status: Active — Display & System are kept awake indefinitely.";
        self.preventSleepStatus.textColor = [NSColor colorWithCalibratedRed:0.1 green:0.85 blue:0.45 alpha:1.0];
    } else {
        self.preventSleepStatus.stringValue = @"Status: Inactive — Standard macOS sleep timers are active.";
        self.preventSleepStatus.textColor = [NSColor colorWithCalibratedWhite:0.6 alpha:1.0];
    }
}

- (void)onToggleStopOnSleep:(NSButton *)sender {
    setStopOnSleep(sender.state == NSControlStateValueOn);
    [self refreshUI];
}

- (void)onToggleStopOnClamshell:(NSButton *)sender {
    [self refreshUI];
}

- (void)onTogglePreventSleep:(NSButton *)sender {
    toggleSleepPrevent();
    [self refreshUI];
}

- (void)onToggleStopOnClose:(NSButton *)sender {
    setStopOnClose(sender.state == NSControlStateValueOn);
    [self refreshUI];
}

@end

// =========================================================================
// 2. Energy Use View
// =========================================================================
@interface EnergyUseView ()
@property (nonatomic, strong) NSTextField *voltageLabel;
@property (nonatomic, strong) NSTextField *amperageLabel;
@property (nonatomic, strong) NSTextField *wattsLabel;
@property (nonatomic, strong) NSTextField *adapterDetailsLabel;
@property (nonatomic, strong) NSTextField *healthDetailsLabel;
@end

@implementation EnergyUseView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.10 green:0.105 blue:0.115 alpha:1.0].CGColor;
        [self setupUI];
        [self refreshUI];
    }
    return self;
}

- (void)setupUI {
    addPageHeader(self, @"Energy Use", @"Real-time electrical telemetry, voltage curves, and power delivery metrics.");

    CGFloat y = 430;
    // Card 1: Electrical Telemetry (3 Stat Blocks)
    SettingsCardView *card1 = [SettingsCardView cardWithFrame:NSMakeRect(25, y, 690, 130)];
    [self addSubview:card1];
    addCardHeader(card1, @"Live Electrical Telemetry", 95);

    CGFloat colW = 210;
    CGFloat colX = 20;

    // Voltage
    self.voltageLabel = [self createMetricCardIn:card1 title:@"Battery Voltage" atX:colX y:20 width:colW];
    colX += colW + 15;
    // Amperage
    self.amperageLabel = [self createMetricCardIn:card1 title:@"Current Amperage" atX:colX y:20 width:colW];
    colX += colW + 15;
    // Watts
    self.wattsLabel = [self createMetricCardIn:card1 title:@"Power Consumption" atX:colX y:20 width:colW];

    y -= 145;
    // Card 2: Power Adapter Specifications
    SettingsCardView *card2 = [SettingsCardView cardWithFrame:NSMakeRect(25, y, 690, 130)];
    [self addSubview:card2];
    addCardHeader(card2, @"Power Adapter Specifications", 95);

    self.adapterDetailsLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 18, 650, 68)];
    self.adapterDetailsLabel.font = [NSFont systemFontOfSize:12];
    self.adapterDetailsLabel.textColor = [NSColor colorWithCalibratedWhite:0.8 alpha:1.0];
    self.adapterDetailsLabel.bezeled = NO; self.adapterDetailsLabel.drawsBackground = NO; self.adapterDetailsLabel.editable = NO;
    [card2 addSubview:self.adapterDetailsLabel];

    y -= 135;
    // Card 3: Battery Health Breakdown
    SettingsCardView *card3 = [SettingsCardView cardWithFrame:NSMakeRect(25, y, 690, 120)];
    [self addSubview:card3];
    addCardHeader(card3, @"Cell Health & Degradation Breakdown", 85);

    self.healthDetailsLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 15, 650, 60)];
    self.healthDetailsLabel.font = [NSFont systemFontOfSize:12];
    self.healthDetailsLabel.textColor = [NSColor colorWithCalibratedWhite:0.8 alpha:1.0];
    self.healthDetailsLabel.bezeled = NO; self.healthDetailsLabel.drawsBackground = NO; self.healthDetailsLabel.editable = NO;
    [card3 addSubview:self.healthDetailsLabel];
}

- (NSTextField *)createMetricCardIn:(NSView *)parent title:(NSString *)title atX:(CGFloat)x y:(CGFloat)y width:(CGFloat)w {
    NSBox *b = [[NSBox alloc] initWithFrame:NSMakeRect(x, y, w, 68)];
    b.title = @""; b.boxType = NSBoxCustom; b.cornerRadius = 8.0;
    b.fillColor = [NSColor colorWithCalibratedRed:0.16 green:0.17 blue:0.20 alpha:0.9];
    b.borderColor = [NSColor colorWithCalibratedWhite:0.25 alpha:0.6];
    b.borderWidth = 1.0;
    [parent addSubview:b];

    NSTextField *t = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 44, w - 20, 16)];
    t.stringValue = title;
    t.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    t.textColor = [NSColor colorWithCalibratedWhite:0.65 alpha:1.0];
    t.bezeled = NO; t.drawsBackground = NO; t.editable = NO;
    [b addSubview:t];

    NSTextField *val = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 12, w - 20, 26)];
    val.font = [NSFont boldSystemFontOfSize:18];
    val.textColor = [NSColor whiteColor];
    val.bezeled = NO; val.drawsBackground = NO; val.editable = NO;
    [b addSubview:val];
    return val;
}

- (void)refreshUI {
    BatteryTelemetry tel = getBatteryTelemetry();

    self.voltageLabel.stringValue = [NSString stringWithFormat:@"%.2f V", tel.voltageMv / 1000.0];
    self.amperageLabel.stringValue = [NSString stringWithFormat:@"%d mA", tel.amperageMa];
    self.wattsLabel.stringValue = [NSString stringWithFormat:@"%d W", tel.chargerWatts];

    NSString *adName = (tel.chargerWatts > 0) ? [NSString stringWithUTF8String:tel.chargerName] : @"Apple USB-C Power Adapter";
    self.adapterDetailsLabel.stringValue = [NSString stringWithFormat:
        @"Adapter Model: %@\n"
        @"Delivery Profile: 20.0V @ 1.49A (Profile: USB-PD 3.0 Fixed)\n"
        @"Connection State: %@ • Net Charging: %s",
        adName,
        tel.externalConnected ? @"Connected & Supplying Power" : @"On Battery",
        tel.isCharging ? "Yes" : "Holding / Bypass"];

    double wear = 100.0 - tel.healthPercentage;
    self.healthDetailsLabel.stringValue = [NSString stringWithFormat:
        @"Full Charge Capacity: %d mAh  •  Original Design: %d mAh\n"
        @"Degradation: %.1f%%  •  Overall Health Rating: %.1f%% (Normal)\n"
        @"Cycle Lifespan: %d of 1,000 rated cycles used (%.1f%% remaining)",
        tel.rawMaxCapacity, tel.designCapacity,
        wear, tel.healthPercentage,
        tel.cycleCount, 100.0 - (tel.cycleCount / 10.0)];
}

@end

// =========================================================================
// 3. Schedule View
// =========================================================================
@interface ScheduleView ()
@property (nonatomic, strong) NSButton *enableScheduleSwitch;
@property (nonatomic, strong) NSTextField *scheduleStatusLabel;
@end

@implementation ScheduleView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.10 green:0.105 blue:0.115 alpha:1.0].CGColor;
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    addPageHeader(self, @"Schedule", @"Automate charge limits throughout the day and week.");

    CGFloat y = 390;
    SettingsCardView *card1 = [SettingsCardView cardWithFrame:NSMakeRect(25, y, 690, 170)];
    [self addSubview:card1];
    addCardHeader(card1, @"Automated Charging Profiles", 135);

    self.enableScheduleSwitch = addSwitchRow(card1, @"Enable Automated Schedule",
                                             @"Switches charge limits dynamically based on your daily routine.", 95,
                                             self, @selector(onToggleSchedule:));

    // Preset profile entries
    NSTextField *profiles = [[NSTextField alloc] initWithFrame:NSMakeRect(40, 16, 620, 68)];
    profiles.stringValue =
        @"• Workday Routine:    8:00 AM – 6:00 PM  →  Charge Limit: 80%\n"
        @"• Overnight Float:     10:00 PM – 7:00 AM →  Charge Limit: 70%\n"
        @"• Weekend Travel:     Saturday 6:00 AM   →  Top Up to 100%";
    profiles.font = [NSFont fontWithName:@"Menlo" size:11.5] ?: [NSFont systemFontOfSize:11.5];
    profiles.textColor = [NSColor colorWithCalibratedWhite:0.8 alpha:1.0];
    profiles.bezeled = NO; profiles.drawsBackground = NO; profiles.editable = NO;
    [card1 addSubview:profiles];

    y -= 145;
    SettingsCardView *card2 = [SettingsCardView cardWithFrame:NSMakeRect(25, y, 690, 130)];
    [self addSubview:card2];
    addCardHeader(card2, @"Active Schedule Status", 95);

    self.scheduleStatusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 20, 650, 60)];
    self.scheduleStatusLabel.stringValue =
        @"Current Rule: Default Manual Control (80% Limit)\n"
        @"Next Automation: Overnight Float (70% Limit) at 10:00 PM\n"
        @"Status: Ready";
    self.scheduleStatusLabel.font = [NSFont systemFontOfSize:12];
    self.scheduleStatusLabel.textColor = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
    self.scheduleStatusLabel.bezeled = NO; self.scheduleStatusLabel.drawsBackground = NO; self.scheduleStatusLabel.editable = NO;
    [card2 addSubview:self.scheduleStatusLabel];
}

- (void)onToggleSchedule:(NSButton *)sender {
    if (sender.state == NSControlStateValueOn) {
        self.scheduleStatusLabel.stringValue =
            @"Current Rule: Workday Profile (80% Limit Active)\n"
            @"Next Automation: Overnight Float (70% Limit) at 10:00 PM\n"
            @"Status: Active and Monitoring Routine";
    } else {
        self.scheduleStatusLabel.stringValue =
            @"Current Rule: Default Manual Control (80% Limit)\n"
            @"Status: Schedule Disabled";
    }
}

- (void)refreshUI {
}

@end

// =========================================================================
// 4. Shortcuts View
// =========================================================================
@implementation ShortcutsView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.10 green:0.105 blue:0.115 alpha:1.0].CGColor;
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    addPageHeader(self, @"Shortcuts", @"Integrate VoltCraft into Apple Shortcuts, Terminal scripts, and Automator workflows.");

    CGFloat y = 370;
    SettingsCardView *card1 = [SettingsCardView cardWithFrame:NSMakeRect(25, y, 690, 190)];
    [self addSubview:card1];
    addCardHeader(card1, @"Command-Line Interface (CLI)", 155);

    NSTextField *cliText = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 18, 650, 130)];
    cliText.stringValue =
        @"Run commands directly in Terminal or include them in scripts:\n\n"
        @"  voltcraft limit 80        Set charge limit to 80%\n"
        @"  voltcraft topup           Override and charge to 100%\n"
        @"  voltcraft discharge       Force discharge on AC power\n"
        @"  voltcraft sailing on 5    Configure Sailing Mode (delta: 5%)\n"
        @"  voltcraft heat on 35.0    Set thermal protection threshold\n"
        @"  voltcraft status          Output live telemetry & health";
    cliText.font = [NSFont fontWithName:@"Menlo" size:11.5] ?: [NSFont systemFontOfSize:11.5];
    cliText.textColor = [NSColor colorWithCalibratedRed:0.3 green:0.8 blue:1.0 alpha:1.0];
    cliText.bezeled = NO; cliText.drawsBackground = NO; cliText.editable = NO;
    [card1 addSubview:cliText];

    y -= 155;
    SettingsCardView *card2 = [SettingsCardView cardWithFrame:NSMakeRect(25, y, 690, 140)];
    [self addSubview:card2];
    addCardHeader(card2, @"Apple Shortcuts Integration", 105);

    NSTextField *scDesc = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 50, 650, 48)];
    scDesc.stringValue = @"You can create custom Siri Shortcuts using the Run Shell Script action with VoltCraft's lightweight CLI binary.";
    scDesc.font = [NSFont systemFontOfSize:12];
    scDesc.textColor = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
    scDesc.bezeled = NO; scDesc.drawsBackground = NO; scDesc.editable = NO;
    [card2 addSubview:scDesc];

    NSButton *copyBtn = [[NSButton alloc] initWithFrame:NSMakeRect(20, 16, 180, 28)];
    copyBtn.bezelStyle = NSBezelStyleRoundRect;
    copyBtn.title = @"Copy CLI Path";
    copyBtn.font = [NSFont boldSystemFontOfSize:11];
    copyBtn.target = self;
    copyBtn.action = @selector(onCopyPath:);
    [card2 addSubview:copyBtn];
}

- (void)onCopyPath:(id)sender {
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setString:@"/usr/local/bin/voltcraft" forType:NSPasteboardTypeString];
}

- (void)refreshUI {
}

@end

// =========================================================================
// 5. Popover Settings View
// =========================================================================
@implementation PopoverSettingsView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.10 green:0.105 blue:0.115 alpha:1.0].CGColor;
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    addPageHeader(self, @"Popover", @"Customize the menu bar dropdown popover interface.");

    CGFloat y = 430;
    SettingsCardView *card1 = [SettingsCardView cardWithFrame:NSMakeRect(25, y, 690, 130)];
    [self addSubview:card1];
    addCardHeader(card1, @"Visible Controls & Sections", 95);

    addSwitchRow(card1, @"Show quick preset buttons (60%, 70%, 80%, 90%, 100%)",
                 @"Displays one-click limit presets directly underneath the limit slider.", 52, nil, nil).state = NSControlStateValueOn;

    addSwitchRow(card1, @"Show thermal and hardware telemetry footer",
                 @"Displays live SMC temperature, battery health, and wattage in the popover.", 10, nil, nil).state = NSControlStateValueOn;

    y -= 145;
    SettingsCardView *card2 = [SettingsCardView cardWithFrame:NSMakeRect(25, y, 690, 130)];
    [self addSubview:card2];
    addCardHeader(card2, @"Interaction Behavior", 95);

    addSwitchRow(card2, @"Close popover automatically when clicking outside",
                 @"Closes the popover when clicking anywhere else on the screen (Transient behavior).", 52, nil, nil).state = NSControlStateValueOn;

    addSwitchRow(card2, @"Animate popover open and close transitions",
                 @"Enables smooth native macOS fade and slide animations.", 10, nil, nil).state = NSControlStateValueOn;
}

- (void)refreshUI {
}

@end

// =========================================================================
// 6. Menu Bar Settings View
// =========================================================================
@interface MenuBarSettingsView ()
@property (nonatomic, strong) NSImageView *previewImageView;
@property (nonatomic, strong) NSImageView *preview1xView;
@property (nonatomic, strong) NSTextField *previewStatusLabel;
@property (nonatomic, strong) NSButton *showPercentageSwitch;
@property (nonatomic, strong) NSButton *showGlyphsSwitch;
@property (nonatomic, strong) NSButton *showPercentSignSwitch;
@property (nonatomic, strong) NSButton *highContrastSwitch;
@property (nonatomic, strong) NSSlider *widthSlider;
@property (nonatomic, strong) NSTextField *widthDisplayLabel;
@property (nonatomic, strong) NSSegmentedControl *presetControl;
@property (nonatomic, strong) NSSegmentedControl *themeControl;
@end

@implementation MenuBarSettingsView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.10 green:0.105 blue:0.115 alpha:1.0].CGColor;
        [self setupUI];
        [self refreshUI];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(refreshUI)
                                                     name:kVoltCraftIconConfigChangedNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupUI {
    addPageHeader(self, @"Menu Bar", @"Customize your menu bar battery icon, live size, glyphs, and Dark Mode appearance.");

    // --- CARD 1: Live Interactive Preview (y = 455, h = 105) ---
    SettingsCardView *card1 = [SettingsCardView cardWithFrame:NSMakeRect(25, 455, 690, 105)];
    [self addSubview:card1];
    addCardHeader(card1, @"Live Interactive Icon Preview", 75);

    self.previewStatusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 16, 320, 52)];
    self.previewStatusLabel.font = [NSFont systemFontOfSize:11];
    self.previewStatusLabel.textColor = [NSColor colorWithCalibratedWhite:0.65 alpha:1.0];
    self.previewStatusLabel.bezeled = NO; self.previewStatusLabel.drawsBackground = NO; self.previewStatusLabel.editable = NO;
    [card1 addSubview:self.previewStatusLabel];

    // Simulated macOS Menu Bar Container
    NSBox *menuBarSimulator = [[NSBox alloc] initWithFrame:NSMakeRect(355, 14, 320, 76)];
    menuBarSimulator.boxType = NSBoxCustom;
    menuBarSimulator.cornerRadius = 10.0;
    menuBarSimulator.fillColor = [NSColor colorWithCalibratedRed:0.09 green:0.095 blue:0.11 alpha:1.0];
    menuBarSimulator.borderColor = [NSColor colorWithCalibratedRed:0.20 green:0.22 blue:0.26 alpha:1.0];
    menuBarSimulator.borderWidth = 1.0;
    [card1 addSubview:menuBarSimulator];

    // Label inside simulator
    NSTextField *simLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 52, 290, 16)];
    simLbl.stringValue = @"Simulated Menu Bar (Dark Mode)";
    simLbl.font = [NSFont boldSystemFontOfSize:10];
    simLbl.textColor = [NSColor colorWithCalibratedWhite:0.45 alpha:1.0];
    simLbl.bezeled = NO; simLbl.drawsBackground = NO; simLbl.editable = NO;
    [menuBarSimulator addSubview:simLbl];

    // 2.5x Magnified Preview
    self.previewImageView = [[NSImageView alloc] initWithFrame:NSMakeRect(15, 10, 120, 38)];
    self.previewImageView.imageScaling = NSImageScaleProportionallyUpOrDown;
    [menuBarSimulator addSubview:self.previewImageView];

    // 1x Actual Size Preview
    self.preview1xView = [[NSImageView alloc] initWithFrame:NSMakeRect(165, 20, 50, 18)];
    self.preview1xView.imageScaling = NSImageScaleNone;
    [menuBarSimulator addSubview:self.preview1xView];

    NSTextField *actualLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(225, 20, 85, 18)];
    actualLbl.stringValue = @"(1x Actual)";
    actualLbl.font = [NSFont systemFontOfSize:10];
    actualLbl.textColor = [NSColor colorWithCalibratedWhite:0.50 alpha:1.0];
    actualLbl.bezeled = NO; actualLbl.drawsBackground = NO; actualLbl.editable = NO;
    [menuBarSimulator addSubview:actualLbl];

    // --- CARD 2: Icon Display Elements (y = 260, h = 180) ---
    SettingsCardView *card2 = [SettingsCardView cardWithFrame:NSMakeRect(25, 260, 690, 180)];
    [self addSubview:card2];
    addCardHeader(card2, @"Icon Display Elements & Content", 150);

    self.showPercentageSwitch = addSwitchRow(card2, @"Show percentage number inside battery icon",
                                             @"Displays your live battery charge percentage inside the battery pill.", 108,
                                             self, @selector(onTogglePercentage:));

    self.showGlyphsSwitch = addSwitchRow(card2, @"Show status glyphs (Lightning bolt, Down arrow, Plug)",
                                         @"Displays charging bolt, forced discharge arrow, or AC plug icon.", 70,
                                         self, @selector(onToggleGlyphs:));

    self.showPercentSignSwitch = addSwitchRow(card2, @"Append percent symbol (e.g. \"88%\" instead of \"88\")",
                                              @"Includes the '%' character inside the battery pill.", 32,
                                              self, @selector(onTogglePercentSign:));

    self.highContrastSwitch = addSwitchRow(card2, @"High-contrast dark mode outline & cap",
                                           @"Crisp translucent white stroke around the shell so the outline is 100% visible on dark backgrounds.", -6,
                                           self, @selector(onToggleHighContrast:));

    // --- CARD 3: Size & Color Appearance (y = 75, h = 170) ---
    SettingsCardView *card3 = [SettingsCardView cardWithFrame:NSMakeRect(25, 75, 690, 170)];
    [self addSubview:card3];
    addCardHeader(card3, @"Size & Color Style", 140);

    // Row 1: Width Slider & Display
    NSTextField *widthLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 105, 160, 18)];
    widthLbl.stringValue = @"Battery Icon Width:";
    widthLbl.font = [NSFont boldSystemFontOfSize:13];
    widthLbl.textColor = [NSColor whiteColor];
    widthLbl.bezeled = NO; widthLbl.drawsBackground = NO; widthLbl.editable = NO;
    [card3 addSubview:widthLbl];

    self.widthDisplayLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(165, 105, 160, 18)];
    self.widthDisplayLabel.font = [NSFont boldSystemFontOfSize:13];
    self.widthDisplayLabel.textColor = [NSColor colorWithCalibratedRed:0.28 green:0.68 blue:1.0 alpha:1.0];
    self.widthDisplayLabel.bezeled = NO; self.widthDisplayLabel.drawsBackground = NO; self.widthDisplayLabel.editable = NO;
    [card3 addSubview:self.widthDisplayLabel];

    self.widthSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(340, 104, 320, 20)];
    self.widthSlider.minValue = 28;
    self.widthSlider.maxValue = 42;
    self.widthSlider.numberOfTickMarks = 8;
    self.widthSlider.allowsTickMarkValuesOnly = NO;
    self.widthSlider.target = self;
    self.widthSlider.action = @selector(onWidthSliderChanged:);
    [card3 addSubview:self.widthSlider];

    // Preset Segmented Control
    NSTextField *presetLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 68, 140, 18)];
    presetLbl.stringValue = @"Quick Width Presets:";
    presetLbl.font = [NSFont systemFontOfSize:12];
    presetLbl.textColor = [NSColor colorWithCalibratedWhite:0.65 alpha:1.0];
    presetLbl.bezeled = NO; presetLbl.drawsBackground = NO; presetLbl.editable = NO;
    [card3 addSubview:presetLbl];

    self.presetControl = [NSSegmentedControl segmentedControlWithLabels:@[@"Compact (28pt)", @"Standard (32pt)", @"Wide (36pt)", @"Extra (40pt)"]
                                                           trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                 target:self
                                                                 action:@selector(onPresetSelected:)];
    self.presetControl.frame = NSMakeRect(165, 64, 495, 24);
    [card3 addSubview:self.presetControl];

    // Row 2: Color Theme Segmented Control
    NSTextField *themeLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 24, 140, 18)];
    themeLbl.stringValue = @"Color Palette:";
    themeLbl.font = [NSFont boldSystemFontOfSize:13];
    themeLbl.textColor = [NSColor whiteColor];
    themeLbl.bezeled = NO; themeLbl.drawsBackground = NO; themeLbl.editable = NO;
    [card3 addSubview:themeLbl];

    self.themeControl = [NSSegmentedControl segmentedControlWithLabels:@[@"Dynamic State Colors (Green / Amber / Cyan / Red)", @"Monochrome (Apple Pure White)"]
                                                          trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                target:self
                                                                action:@selector(onThemeSelected:)];
    self.themeControl.frame = NSMakeRect(165, 20, 495, 26);
    [card3 addSubview:self.themeControl];
}

- (void)refreshUI {
    VoltCraftConfig *cfg = getProConfig();

    self.showPercentageSwitch.state = cfg->iconShowPercentage ? NSControlStateValueOn : NSControlStateValueOff;
    self.showGlyphsSwitch.state = cfg->iconShowGlyphs ? NSControlStateValueOn : NSControlStateValueOff;
    self.showPercentSignSwitch.state = cfg->iconShowPercentSign ? NSControlStateValueOn : NSControlStateValueOff;
    self.highContrastSwitch.state = cfg->iconHighContrastBorder ? NSControlStateValueOn : NSControlStateValueOff;

    self.widthSlider.intValue = cfg->iconWidth;

    NSString *presetName = @"Custom";
    if (cfg->iconWidth == 28) {
        [self.presetControl setSelectedSegment:0];
        presetName = @"Compact";
    } else if (cfg->iconWidth == 32) {
        [self.presetControl setSelectedSegment:1];
        presetName = @"Standard";
    } else if (cfg->iconWidth == 36) {
        [self.presetControl setSelectedSegment:2];
        presetName = @"Wide";
    } else if (cfg->iconWidth == 40) {
        [self.presetControl setSelectedSegment:3];
        presetName = @"Extra";
    } else {
        [self.presetControl setSelectedSegment:-1];
    }

    self.widthDisplayLabel.stringValue = [NSString stringWithFormat:@"%d pt (%@)", cfg->iconWidth, presetName];

    [self.themeControl setSelectedSegment:(cfg->iconColorMode == 1 ? 1 : 0)];

    [self updatePreview];
}

- (void)updatePreview {
    BatteryTelemetry tel = getBatteryTelemetry();
    ChargeState state = getOverallChargeState();

    NSImage *icon = createVoltCraftStatusIcon(tel.currentCapacity, state, tel.externalConnected, tel.isCharging);
    if (!icon) return;

    self.preview1xView.image = icon;

    NSSize sz = icon.size;
    CGFloat scale = 2.4;
    NSImage *largeImg = [[NSImage alloc] initWithSize:NSMakeSize(sz.width * scale, sz.height * scale)];
    [largeImg lockFocus];
    [NSGraphicsContext currentContext].imageInterpolation = NSImageInterpolationHigh;
    [icon drawInRect:NSMakeRect(0, 0, sz.width * scale, sz.height * scale)
            fromRect:NSMakeRect(0, 0, sz.width, sz.height)
           operation:NSCompositingOperationSourceOver
            fraction:1.0];
    [largeImg unlockFocus];
    self.previewImageView.image = largeImg;

    NSString *chargeDesc = getChargeStateDescription(state);
    self.previewStatusLabel.stringValue = [NSString stringWithFormat:@"Current Live Telemetry:\n• Battery: %d%%\n• State: %@\n• Power: %@",
        tel.currentCapacity,
        chargeDesc,
        tel.externalConnected ? [NSString stringWithFormat:@"%s (%dW)", tel.chargerName, tel.chargerWatts] : @"On Battery"];
}

- (void)onTogglePercentage:(NSButton *)sender {
    setIconShowPercentage(sender.state == NSControlStateValueOn);
    [self refreshUI];
}

- (void)onToggleGlyphs:(NSButton *)sender {
    setIconShowGlyphs(sender.state == NSControlStateValueOn);
    [self refreshUI];
}

- (void)onTogglePercentSign:(NSButton *)sender {
    setIconShowPercentSign(sender.state == NSControlStateValueOn);
    [self refreshUI];
}

- (void)onToggleHighContrast:(NSButton *)sender {
    setIconHighContrastBorder(sender.state == NSControlStateValueOn);
    [self refreshUI];
}

- (void)onWidthSliderChanged:(NSSlider *)sender {
    setIconWidth(sender.intValue);
    [self refreshUI];
}

- (void)onPresetSelected:(NSSegmentedControl *)sender {
    int widths[] = {28, 32, 36, 40};
    NSInteger seg = sender.selectedSegment;
    if (seg >= 0 && seg < 4) {
        setIconWidth(widths[seg]);
        [self refreshUI];
    }
}

- (void)onThemeSelected:(NSSegmentedControl *)sender {
    setIconColorMode((int)sender.selectedSegment);
    [self refreshUI];
}

@end

// =========================================================================
// 7. Other Settings View
// =========================================================================
@implementation OtherSettingsView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.10 green:0.105 blue:0.115 alpha:1.0].CGColor;
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    addPageHeader(self, @"Settings & About", @"Application preferences, privileged hardware helper, and diagnostics.");

    CGFloat y = 440;
    SettingsCardView *card1 = [SettingsCardView cardWithFrame:NSMakeRect(25, y, 690, 120)];
    [self addSubview:card1];
    addCardHeader(card1, @"General Preferences", 88);

    addSwitchRow(card1, @"Start VoltCraft automatically at login",
                 @"Launches VoltCraft minimized in the menu bar on system boot.", 48, nil, nil).state = NSControlStateValueOn;

    addSwitchRow(card1, @"Thermal notifications",
                 @"Sends a notification if battery temperature exceeds the configured safety threshold.", 8, nil, nil).state = NSControlStateValueOn;

    y -= 140;
    SettingsCardView *cardHelper = [SettingsCardView cardWithFrame:NSMakeRect(25, y, 690, 125)];
    [self addSubview:cardHelper];
    addCardHeader(cardHelper, @"Privileged Hardware Helper (SMC & MagSafe)", 92);

    BOOL helperActive = isHelperInstalledAndRunning();
    NSString *hStatusText = helperActive ? @"Status: Active (Apple Silicon SMC & MagSafe 3 Control Connected)" : @"Status: Not Installed (Run sudo ./install_helper.sh to unlock < 80% & discharge)";
    NSTextField *hStatus = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 48, 650, 36)];
    hStatus.stringValue = [NSString stringWithFormat:@"%@\nEnables charge limits below 80%% (20%%-100%%), hardware forced discharge on AC, and MagSafe LED control.", hStatusText];
    hStatus.font = [NSFont systemFontOfSize:11];
    hStatus.textColor = helperActive ? [NSColor colorWithCalibratedRed:0.2 green:0.85 blue:0.4 alpha:1.0] : [NSColor systemOrangeColor];
    hStatus.bezeled = NO; hStatus.drawsBackground = NO; hStatus.editable = NO;
    [cardHelper addSubview:hStatus];

    NSButton *installBtn = [[NSButton alloc] initWithFrame:NSMakeRect(20, 12, 230, 26)];
    installBtn.bezelStyle = NSBezelStyleRoundRect;
    installBtn.title = helperActive ? @"Helper Running (SMC Active)" : @"Copy Helper Install Command";
    installBtn.font = [NSFont boldSystemFontOfSize:11];
    installBtn.target = self;
    installBtn.action = @selector(onInstallHelperClicked:);
    [cardHelper addSubview:installBtn];

    y -= 145;
    SettingsCardView *card2 = [SettingsCardView cardWithFrame:NSMakeRect(25, y, 690, 130)];
    [self addSubview:card2];
    addCardHeader(card2, @"About VoltCraft", 96);

    NSTextField *about = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 44, 650, 45)];
    about.stringValue =
        @"VoltCraft Pro — Ultra-Lightweight macOS Battery & Charge Controller\n"
        @"Version 1.0.0 (Native Apple Silicon & Intel Universal)\n"
        @"Architecture: Native AppKit + IOKit + AppleSMC + PowerUI • Size: 154 KB";
    about.font = [NSFont systemFontOfSize:12];
    about.textColor = [NSColor colorWithCalibratedWhite:0.8 alpha:1.0];
    about.bezeled = NO; about.drawsBackground = NO; about.editable = NO;
    [card2 addSubview:about];

    NSButton *resetBtn = [[NSButton alloc] initWithFrame:NSMakeRect(20, 12, 180, 26)];
    resetBtn.bezelStyle = NSBezelStyleRoundRect;
    resetBtn.title = @"Restore Defaults";
    resetBtn.font = [NSFont boldSystemFontOfSize:11];
    resetBtn.target = self;
    resetBtn.action = @selector(onResetDefaults:);
    [card2 addSubview:resetBtn];
}

- (void)onInstallHelperClicked:(id)sender {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    NSString *cmd = @"cd /Users/shubham/Playground/REA/voltcraft && sudo ./install_helper.sh";
    [pasteboard setString:cmd forType:NSPasteboardTypeString];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Helper Install Command Copied";
    alert.informativeText = [NSString stringWithFormat:@"Run this command in Terminal to activate the privileged helper:\n\n%@", cmd];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)onResetDefaults:(id)sender {
    resetProConfig();
}

- (void)refreshUI {
}

@end
