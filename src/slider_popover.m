#import "slider_popover.h"
#import "battery_core.h"

@interface SliderPopoverViewController ()

@property (nonatomic, strong) NSTextField *pctLabel;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSTextField *limitValueLabel;
@property (nonatomic, strong) NSSlider *limitSlider;
@property (nonatomic, strong) NSMutableArray<NSButton *> *presetButtons;

@property (nonatomic, strong) NSButton *topUpButton;
@property (nonatomic, strong) NSButton *dischargeButton;
@property (nonatomic, strong) NSButton *sailingButton;
@property (nonatomic, strong) NSButton *heatButton;
@property (nonatomic, strong) NSTextField *footerLabel;

@end

@implementation SliderPopoverViewController

- (void)loadView {
    NSRect frame = NSMakeRect(0, 0, 310, 310);
    NSView *root = [[NSView alloc] initWithFrame:frame];
    root.wantsLayer = YES;
    root.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.10 green:0.11 blue:0.13 alpha:1.0].CGColor;
    self.view = root;

    self.presetButtons = [NSMutableArray array];
    [self setupUI];
}

- (void)setupUI {
    NSView *root = self.view;

    // --- Header Row ---
    // Battery Percentage Large
    self.pctLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 266, 90, 32)];
    self.pctLabel.font = [NSFont systemFontOfSize:24 weight:NSFontWeightBold];
    self.pctLabel.textColor = [NSColor whiteColor];
    self.pctLabel.bezeled = NO; self.pctLabel.drawsBackground = NO; self.pctLabel.editable = NO;
    [root addSubview:self.pctLabel];

    // Status Sublabel (Charging, Holding limit, etc.)
    self.statusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 248, 220, 16)];
    self.statusLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    self.statusLabel.textColor = [NSColor colorWithCalibratedWhite:0.65 alpha:1.0];
    self.statusLabel.bezeled = NO; self.statusLabel.drawsBackground = NO; self.statusLabel.editable = NO;
    [root addSubview:self.statusLabel];

    // Settings Gear Button in Top-Right
    NSButton *settingsBtn = [[NSButton alloc] initWithFrame:NSMakeRect(268, 264, 28, 28)];
    settingsBtn.bezelStyle = NSBezelStyleCircular;
    settingsBtn.image = [NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:@"Settings"];
    settingsBtn.imagePosition = NSImageOnly;
    settingsBtn.target = self;
    settingsBtn.action = @selector(onSettingsClicked:);
    settingsBtn.toolTip = @"Open Dashboard & Settings";
    [root addSubview:settingsBtn];

    // --- Charge Limit Card ---
    NSBox *sliderCard = [[NSBox alloc] initWithFrame:NSMakeRect(12, 126, 286, 114)];
    sliderCard.titlePosition = NSNoTitle;
    sliderCard.boxType = NSBoxCustom;
    sliderCard.cornerRadius = 8.0;
    sliderCard.borderWidth = 1.0;
    sliderCard.borderColor = [NSColor colorWithCalibratedWhite:0.25 alpha:0.6];
    sliderCard.fillColor = [NSColor colorWithCalibratedRed:0.14 green:0.15 blue:0.18 alpha:1.0];
    [root addSubview:sliderCard];

    NSView *cardContent = sliderCard.contentView;

    NSTextField *limitTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 86, 120, 18)];
    limitTitle.stringValue = @"Charge Limit";
    limitTitle.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
    limitTitle.textColor = [NSColor colorWithCalibratedWhite:0.85 alpha:1.0];
    limitTitle.bezeled = NO; limitTitle.drawsBackground = NO; limitTitle.editable = NO;
    [cardContent addSubview:limitTitle];

    self.limitValueLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(200, 86, 76, 18)];
    self.limitValueLabel.alignment = NSTextAlignmentRight;
    self.limitValueLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
    self.limitValueLabel.textColor = [NSColor colorWithCalibratedRed:0.0 green:0.82 blue:1.0 alpha:1.0];
    self.limitValueLabel.bezeled = NO; self.limitValueLabel.drawsBackground = NO; self.limitValueLabel.editable = NO;
    [cardContent addSubview:self.limitValueLabel];

    // Continuous Slider (20% to 100%)
    self.limitSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(10, 52, 266, 24)];
    self.limitSlider.minValue = 20.0;
    self.limitSlider.maxValue = 100.0;
    self.limitSlider.continuous = YES;
    self.limitSlider.target = self;
    self.limitSlider.action = @selector(onSliderChanged:);
    [cardContent addSubview:self.limitSlider];

    // Preset buttons: 60%, 70%, 80%, 90%, 100%
    NSArray *presets = @[@60, @70, @80, @90, @100];
    CGFloat btnW = 48.0;
    CGFloat btnSpacing = 6.0;
    CGFloat startX = 10.0;

    for (int i = 0; i < presets.count; i++) {
        NSNumber *val = presets[i];
        NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(startX + i * (btnW + btnSpacing), 12, btnW, 24)];
        btn.bezelStyle = NSBezelStyleRoundRect;
        btn.title = [NSString stringWithFormat:@"%d%%", val.intValue];
        btn.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
        btn.tag = val.intValue;
        btn.target = self;
        btn.action = @selector(onPresetClicked:);
        [cardContent addSubview:btn];
        [self.presetButtons addObject:btn];
    }

    // --- Quick Action Toggles (Native SF Symbols) ---
    CGFloat actionY = 82;
    CGFloat halfW = 138;

    // Top Up Button
    self.topUpButton = [[NSButton alloc] initWithFrame:NSMakeRect(12, actionY, halfW, 30)];
    self.topUpButton.bezelStyle = NSBezelStyleRoundRect;
    self.topUpButton.image = [NSImage imageWithSystemSymbolName:@"bolt.fill" accessibilityDescription:nil];
    self.topUpButton.imagePosition = NSImageLeft;
    self.topUpButton.title = @" Top Up (100%)";
    self.topUpButton.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    self.topUpButton.target = self;
    self.topUpButton.action = @selector(onTopUpClicked:);
    [root addSubview:self.topUpButton];

    // Discharge Button
    self.dischargeButton = [[NSButton alloc] initWithFrame:NSMakeRect(160, actionY, halfW, 30)];
    self.dischargeButton.bezelStyle = NSBezelStyleRoundRect;
    self.dischargeButton.image = [NSImage imageWithSystemSymbolName:@"arrow.down.circle" accessibilityDescription:nil];
    self.dischargeButton.imagePosition = NSImageLeft;
    self.dischargeButton.title = @" Discharge";
    self.dischargeButton.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    self.dischargeButton.target = self;
    self.dischargeButton.action = @selector(onDischargeClicked:);
    [root addSubview:self.dischargeButton];

    actionY -= 32;

    // Sailing Mode Button
    self.sailingButton = [[NSButton alloc] initWithFrame:NSMakeRect(12, actionY, halfW, 26)];
    self.sailingButton.bezelStyle = NSBezelStyleRoundRect;
    self.sailingButton.image = [NSImage imageWithSystemSymbolName:@"wind" accessibilityDescription:nil];
    self.sailingButton.imagePosition = NSImageLeft;
    self.sailingButton.title = @" Sailing Mode";
    self.sailingButton.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightRegular];
    self.sailingButton.target = self;
    self.sailingButton.action = @selector(onSailingClicked:);
    [root addSubview:self.sailingButton];

    // Heat Protection Button
    self.heatButton = [[NSButton alloc] initWithFrame:NSMakeRect(160, actionY, halfW, 26)];
    self.heatButton.bezelStyle = NSBezelStyleRoundRect;
    self.heatButton.image = [NSImage imageWithSystemSymbolName:@"thermometer.medium" accessibilityDescription:nil];
    self.heatButton.imagePosition = NSImageLeft;
    self.heatButton.title = @" Heat Guard";
    self.heatButton.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightRegular];
    self.heatButton.target = self;
    self.heatButton.action = @selector(onHeatClicked:);
    [root addSubview:self.heatButton];

    // --- Footer Telemetry ---
    self.footerLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 8, 250, 32)];
    self.footerLabel.font = [NSFont systemFontOfSize:10 weight:NSFontWeightRegular];
    self.footerLabel.textColor = [NSColor colorWithCalibratedWhite:0.55 alpha:1.0];
    self.footerLabel.bezeled = NO; self.footerLabel.drawsBackground = NO; self.footerLabel.editable = NO;
    [root addSubview:self.footerLabel];

    // Power / Quit Button
    NSButton *quitBtn = [[NSButton alloc] initWithFrame:NSMakeRect(272, 10, 24, 24)];
    quitBtn.bezelStyle = NSBezelStyleCircular;
    quitBtn.image = [NSImage imageWithSystemSymbolName:@"power" accessibilityDescription:@"Quit"];
    quitBtn.imagePosition = NSImageOnly;
    quitBtn.target = self;
    quitBtn.action = @selector(onQuitClicked:);
    quitBtn.toolTip = @"Quit VoltCraft";
    [root addSubview:quitBtn];

    [self refreshUI];
}

- (void)refreshUI {
    loadProConfig();
    BatteryTelemetry tel = getBatteryTelemetry();
    VoltCraftConfig *cfg = getProConfig();
    ChargeState state = getOverallChargeState();

    self.pctLabel.stringValue = [NSString stringWithFormat:@"%d%%", tel.currentCapacity];
    self.statusLabel.stringValue = [NSString stringWithFormat:@"%@ • %@",
                                    getChargeStateDescription(state),
                                    tel.externalConnected ? @"Plugged In" : @"On Battery"];

    // Dynamic Status Color
    if (state == ChargeStateDischarging) {
        self.statusLabel.textColor = [NSColor systemOrangeColor];
    } else if (state == ChargeStateNormalCharging || state == ChargeStateTopUp) {
        self.statusLabel.textColor = [NSColor colorWithCalibratedRed:0.20 green:0.85 blue:0.40 alpha:1.0];
    } else {
        self.statusLabel.textColor = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
    }

    self.limitValueLabel.stringValue = [NSString stringWithFormat:@"%d%%", cfg->chargeLimit];
    self.limitSlider.integerValue = cfg->chargeLimit;

    // Highlight active preset
    for (NSButton *btn in self.presetButtons) {
        if (btn.tag == cfg->chargeLimit) {
            btn.contentTintColor = [NSColor colorWithCalibratedRed:0.0 green:0.82 blue:1.0 alpha:1.0];
        } else {
            btn.contentTintColor = [NSColor labelColor];
        }
    }

    // Top Up State
    if (cfg->isTopUpActive) {
        self.topUpButton.title = @" Top-Up Active";
        self.topUpButton.contentTintColor = [NSColor colorWithCalibratedRed:0.1 green:0.9 blue:0.5 alpha:1.0];
    } else {
        self.topUpButton.title = @" Top Up (100%)";
        self.topUpButton.contentTintColor = [NSColor labelColor];
    }

    // Discharge State
    if (cfg->isDischarging || state == ChargeStateDischarging) {
        self.dischargeButton.title = @" Discharging";
        self.dischargeButton.contentTintColor = [NSColor systemOrangeColor];
    } else {
        self.dischargeButton.title = @" Discharge";
        self.dischargeButton.contentTintColor = [NSColor labelColor];
    }

    // Sailing State
    if (cfg->sailingEnabled) {
        self.sailingButton.title = [NSString stringWithFormat:@" Sailing: %d%%", cfg->sailingDifference];
        self.sailingButton.contentTintColor = [NSColor colorWithCalibratedRed:0.2 green:0.8 blue:0.9 alpha:1.0];
    } else {
        self.sailingButton.title = @" Sailing: Off";
        self.sailingButton.contentTintColor = [NSColor secondaryLabelColor];
    }

    // Heat Guard State
    if (cfg->heatProtectionEnabled) {
        self.heatButton.title = [NSString stringWithFormat:@" Heat: %.0f°C", cfg->maxTemperatureC];
        self.heatButton.contentTintColor = (tel.temperatureC >= cfg->maxTemperatureC) ? [NSColor systemOrangeColor] : [NSColor labelColor];
    } else {
        self.heatButton.title = @" Heat: Off";
        self.heatButton.contentTintColor = [NSColor secondaryLabelColor];
    }

    // Footer Info
    BOOL helperActive = isHelperInstalledAndRunning();
    NSString *helperStatus = helperActive ? @"Hardware SMC Active" : @"Helper: Run install_helper.sh";
    NSString *chargerStr = (tel.chargerWatts > 0) ? [NSString stringWithUTF8String:tel.chargerName] : @"On Battery";
    self.footerLabel.stringValue = [NSString stringWithFormat:@"Temp: %.1f °C  •  Health: %.1f%% (%@)\nPower: %dW (%@)",
                                    tel.temperatureC, tel.healthPercentage, helperStatus,
                                    tel.chargerWatts, chargerStr];
}

- (void)onSliderChanged:(NSSlider *)sender {
    int limit = (int)sender.integerValue;
    self.limitValueLabel.stringValue = [NSString stringWithFormat:@"%d%%", limit];
    setChargeLimit(limit, NULL);
    [self refreshUI];
    if ([self.delegate respondsToSelector:@selector(popoverDidChangeChargeLimit)]) {
        [self.delegate popoverDidChangeChargeLimit];
    }
}

- (void)onPresetClicked:(NSButton *)sender {
    int limit = (int)sender.tag;
    setChargeLimit(limit, NULL);
    [self refreshUI];
    if ([self.delegate respondsToSelector:@selector(popoverDidChangeChargeLimit)]) {
        [self.delegate popoverDidChangeChargeLimit];
    }
}

- (void)onTopUpClicked:(id)sender {
    toggleTopUp();
    [self refreshUI];
    if ([self.delegate respondsToSelector:@selector(popoverDidChangeChargeLimit)]) {
        [self.delegate popoverDidChangeChargeLimit];
    }
}

- (void)onDischargeClicked:(id)sender {
    toggleDischarge();
    [self refreshUI];
    if ([self.delegate respondsToSelector:@selector(popoverDidChangeChargeLimit)]) {
        [self.delegate popoverDidChangeChargeLimit];
    }
}

- (void)onSailingClicked:(id)sender {
    VoltCraftConfig *cfg = getProConfig();
    setSailingModeEnabled(!cfg->sailingEnabled);
    [self refreshUI];
}

- (void)onHeatClicked:(id)sender {
    VoltCraftConfig *cfg = getProConfig();
    setHeatProtectionEnabled(!cfg->heatProtectionEnabled);
    [self refreshUI];
}

- (void)onSettingsClicked:(id)sender {
    if ([self.delegate respondsToSelector:@selector(popoverDidRequestOpenSettings)]) {
        [self.delegate popoverDidRequestOpenSettings];
    }
}

- (void)onQuitClicked:(id)sender {
    if ([self.delegate respondsToSelector:@selector(popoverDidRequestQuit)]) {
        [self.delegate popoverDidRequestQuit];
    }
}

@end
