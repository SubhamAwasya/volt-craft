#import "slider_popover.h"
#import "battery_core.h"

@interface SliderPopoverViewController ()

@property (nonatomic, strong) NSTextField *pctLabel;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSTextField *limitValueLabel;
@property (nonatomic, strong) NSSlider *limitSlider;
@property (nonatomic, strong) NSMutableArray<NSButton *> *presetButtons;

@property (nonatomic, strong) NSButton *stopChargeButton;
@property (nonatomic, strong) NSButton *topUpButton;
@property (nonatomic, strong) NSButton *dischargeButton;
@property (nonatomic, strong) NSTextField *footerLabel;

@end

@implementation SliderPopoverViewController

- (void)loadView {
    NSRect frame = NSMakeRect(0, 0, 310, 350);
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
    self.pctLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 304, 100, 34)];
    self.pctLabel.font = [NSFont systemFontOfSize:26 weight:NSFontWeightBold];
    self.pctLabel.textColor = [NSColor whiteColor];
    self.pctLabel.bezeled = NO; self.pctLabel.drawsBackground = NO; self.pctLabel.editable = NO;
    [root addSubview:self.pctLabel];

    // Status Sublabel (Charging, Holding limit, etc.)
    self.statusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(16, 286, 235, 16)];
    self.statusLabel.font = [NSFont systemFontOfSize:11.5 weight:NSFontWeightMedium];
    self.statusLabel.textColor = [NSColor colorWithCalibratedWhite:0.65 alpha:1.0];
    self.statusLabel.bezeled = NO; self.statusLabel.drawsBackground = NO; self.statusLabel.editable = NO;
    [root addSubview:self.statusLabel];

    // Settings Gear Button in Top-Right
    NSButton *settingsBtn = [[NSButton alloc] initWithFrame:NSMakeRect(268, 306, 28, 28)];
    settingsBtn.bezelStyle = NSBezelStyleCircular;
    settingsBtn.image = [NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:@"Settings"];
    settingsBtn.imagePosition = NSImageOnly;
    settingsBtn.target = self;
    settingsBtn.action = @selector(onSettingsClicked:);
    settingsBtn.toolTip = @"Open Dashboard & Settings";
    [root addSubview:settingsBtn];

    // --- Charge Limit Card ---
    NSBox *sliderCard = [[NSBox alloc] initWithFrame:NSMakeRect(12, 142, 286, 136)];
    sliderCard.titlePosition = NSNoTitle;
    sliderCard.boxType = NSBoxCustom;
    sliderCard.cornerRadius = 8.0;
    sliderCard.borderWidth = 1.0;
    sliderCard.borderColor = [NSColor colorWithCalibratedWhite:0.25 alpha:0.6];
    sliderCard.fillColor = [NSColor colorWithCalibratedRed:0.14 green:0.15 blue:0.18 alpha:1.0];
    [root addSubview:sliderCard];

    NSView *cardContent = sliderCard.contentView;

    NSTextField *limitTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(10, 106, 120, 18)];
    limitTitle.stringValue = @"Charge Limit";
    limitTitle.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
    limitTitle.textColor = [NSColor colorWithCalibratedWhite:0.85 alpha:1.0];
    limitTitle.bezeled = NO; limitTitle.drawsBackground = NO; limitTitle.editable = NO;
    [cardContent addSubview:limitTitle];

    self.limitValueLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(200, 106, 76, 18)];
    self.limitValueLabel.alignment = NSTextAlignmentRight;
    self.limitValueLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
    self.limitValueLabel.textColor = [NSColor colorWithCalibratedRed:0.0 green:0.82 blue:1.0 alpha:1.0];
    self.limitValueLabel.bezeled = NO; self.limitValueLabel.drawsBackground = NO; self.limitValueLabel.editable = NO;
    [cardContent addSubview:self.limitValueLabel];

    // Continuous Slider (20% to 100%)
    self.limitSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(10, 72, 266, 24)];
    self.limitSlider.minValue = 20.0;
    self.limitSlider.maxValue = 100.0;
    self.limitSlider.continuous = YES;
    self.limitSlider.target = self;
    self.limitSlider.action = @selector(onSliderChanged:);
    [cardContent addSubview:self.limitSlider];

    // Presets Row 1: 50%, 55%, 60%, 65%, 70%, 75% (6 buttons)
    NSArray *row1Presets = @[@50, @55, @60, @65, @70, @75];
    CGFloat row1BtnW = 40.0;
    CGFloat row1Gap = 5.2;
    CGFloat startX = 10.0;
    for (int i = 0; i < row1Presets.count; i++) {
        NSNumber *val = row1Presets[i];
        NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(startX + i * (row1BtnW + row1Gap), 38, row1BtnW, 22)];
        btn.bezelStyle = NSBezelStyleRoundRect;
        btn.title = [NSString stringWithFormat:@"%d%%", val.intValue];
        btn.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightMedium];
        btn.tag = val.intValue;
        btn.target = self;
        btn.action = @selector(onPresetClicked:);
        [cardContent addSubview:btn];
        [self.presetButtons addObject:btn];
    }

    // Presets Row 2: 80%, 85%, 90%, 95%, 100% (5 buttons)
    NSArray *row2Presets = @[@80, @85, @90, @95, @100];
    CGFloat row2BtnW = 48.0;
    CGFloat row2Gap = 6.5;
    for (int i = 0; i < row2Presets.count; i++) {
        NSNumber *val = row2Presets[i];
        NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(startX + i * (row2BtnW + row2Gap), 10, row2BtnW, 22)];
        btn.bezelStyle = NSBezelStyleRoundRect;
        btn.title = [NSString stringWithFormat:@"%d%%", val.intValue];
        btn.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightMedium];
        btn.tag = val.intValue;
        btn.target = self;
        btn.action = @selector(onPresetClicked:);
        [cardContent addSubview:btn];
        [self.presetButtons addObject:btn];
    }

    // --- Action Buttons ---
    // Stop Charge Button (Hero Full-Width Action)
    self.stopChargeButton = [[NSButton alloc] initWithFrame:NSMakeRect(12, 102, 286, 30)];
    self.stopChargeButton.bezelStyle = NSBezelStyleRoundRect;
    self.stopChargeButton.image = [NSImage imageWithSystemSymbolName:@"bolt.slash.fill" accessibilityDescription:nil];
    self.stopChargeButton.imagePosition = NSImageLeft;
    self.stopChargeButton.title = @" Stop Charge (Run on Charger)";
    self.stopChargeButton.font = [NSFont systemFontOfSize:11.5 weight:NSFontWeightSemibold];
    self.stopChargeButton.target = self;
    self.stopChargeButton.action = @selector(onStopChargeClicked:);
    self.stopChargeButton.toolTip = @"Set limit to current battery percentage to halt charging and run on AC adapter.";
    [root addSubview:self.stopChargeButton];

    // Secondary Action Row: Top Up & Discharge
    CGFloat halfW = 138;
    self.topUpButton = [[NSButton alloc] initWithFrame:NSMakeRect(12, 66, halfW, 28)];
    self.topUpButton.bezelStyle = NSBezelStyleRoundRect;
    self.topUpButton.image = [NSImage imageWithSystemSymbolName:@"bolt.fill" accessibilityDescription:nil];
    self.topUpButton.imagePosition = NSImageLeft;
    self.topUpButton.title = @" Top Up (100%)";
    self.topUpButton.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    self.topUpButton.target = self;
    self.topUpButton.action = @selector(onTopUpClicked:);
    [root addSubview:self.topUpButton];

    self.dischargeButton = [[NSButton alloc] initWithFrame:NSMakeRect(160, 66, halfW, 28)];
    self.dischargeButton.bezelStyle = NSBezelStyleRoundRect;
    self.dischargeButton.image = [NSImage imageWithSystemSymbolName:@"arrow.down.circle" accessibilityDescription:nil];
    self.dischargeButton.imagePosition = NSImageLeft;
    self.dischargeButton.title = @" Discharge";
    self.dischargeButton.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    self.dischargeButton.target = self;
    self.dischargeButton.action = @selector(onDischargeClicked:);
    [root addSubview:self.dischargeButton];

    // --- Footer Telemetry ---
    self.footerLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 10, 252, 46)];
    self.footerLabel.font = [NSFont systemFontOfSize:10 weight:NSFontWeightRegular];
    self.footerLabel.textColor = [NSColor colorWithCalibratedWhite:0.6 alpha:1.0];
    self.footerLabel.bezeled = NO; self.footerLabel.drawsBackground = NO; self.footerLabel.editable = NO;
    [root addSubview:self.footerLabel];

    // Power / Quit Button
    NSButton *quitBtn = [[NSButton alloc] initWithFrame:NSMakeRect(272, 18, 24, 24)];
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
    } else if (state == ChargeStateHoldingLimit) {
        self.statusLabel.textColor = [NSColor colorWithCalibratedRed:0.0 green:0.82 blue:1.0 alpha:1.0];
    } else {
        self.statusLabel.textColor = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
    }

    self.limitValueLabel.stringValue = [NSString stringWithFormat:@"%d%%", cfg->chargeLimit];
    self.limitSlider.integerValue = cfg->chargeLimit;

    // Highlight active preset button
    for (NSButton *btn in self.presetButtons) {
        if (btn.tag == cfg->chargeLimit) {
            btn.contentTintColor = [NSColor colorWithCalibratedRed:0.0 green:0.82 blue:1.0 alpha:1.0];
        } else {
            btn.contentTintColor = [NSColor labelColor];
        }
    }

    // Stop Charge Button State
    BOOL isHoldingCurrent = tel.externalConnected && (cfg->chargeLimit == tel.currentCapacity || state == ChargeStateHoldingLimit);
    if (isHoldingCurrent && !cfg->isDischarging && !cfg->isTopUpActive) {
        self.stopChargeButton.title = [NSString stringWithFormat:@" Charge Stopped (Holding at %d%%)", tel.currentCapacity];
        self.stopChargeButton.contentTintColor = [NSColor colorWithCalibratedRed:0.0 green:0.82 blue:1.0 alpha:1.0];
    } else {
        if (tel.externalConnected) {
            self.stopChargeButton.title = [NSString stringWithFormat:@" Stop Charge (Hold at %d%%)", tel.currentCapacity];
        } else {
            self.stopChargeButton.title = @" Stop Charge (Set to Current)";
        }
        self.stopChargeButton.contentTintColor = [NSColor labelColor];
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

    // --- Footer Telemetry: Voltage & Power Consumption ---
    double volts = tel.voltageMv / 1000.0;
    double battWatts = (tel.voltageMv * (double)tel.amperageMa) / 1000000.0;

    NSString *powerStr;
    if (tel.externalConnected) {
        if (fabs(battWatts) < 0.2) {
            powerStr = @"Power: 0.0W (Bypass)";
        } else if (battWatts > 0) {
            powerStr = [NSString stringWithFormat:@"Power: +%.1fW", battWatts];
        } else {
            powerStr = [NSString stringWithFormat:@"Power: %.1fW", battWatts];
        }
    } else {
        powerStr = [NSString stringWithFormat:@"Power: %.1fW", battWatts];
    }

    NSString *chargerInfo = (tel.chargerWatts > 0) ? [NSString stringWithFormat:@"%dW Charger", tel.chargerWatts]
                                                   : (tel.externalConnected ? @"Connected" : @"On Battery");

    self.footerLabel.stringValue = [NSString stringWithFormat:@"Voltage: %.2fV  •  %@\nTemp: %.1f °C  •  Health: %.1f%%  •  %@",
                                    volts, powerStr,
                                    tel.temperatureC, tel.healthPercentage, chargerInfo];
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

- (void)onStopChargeClicked:(id)sender {
    stopChargingAtCurrentLevel();
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
