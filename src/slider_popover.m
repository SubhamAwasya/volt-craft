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
    // Symmetrical, compact 310 x 330 pt canvas
    NSRect frame = NSMakeRect(0, 0, 310, 330);
    NSView *root = [[NSView alloc] initWithFrame:frame];
    root.wantsLayer = YES;
    root.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.10 green:0.11 blue:0.13 alpha:1.0].CGColor;
    self.view = root;

    self.presetButtons = [NSMutableArray array];
    [self setupUI];
}

- (void)setupUI {
    NSView *root = self.view;

    // --- Header Row (Grid: Left 14 pt, Right 296 pt) ---
    self.pctLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 278, 120, 34)];
    self.pctLabel.font = [NSFont systemFontOfSize:26 weight:NSFontWeightBold];
    self.pctLabel.textColor = [NSColor whiteColor];
    self.pctLabel.bezeled = NO; self.pctLabel.drawsBackground = NO; self.pctLabel.editable = NO;
    [root addSubview:self.pctLabel];

    self.statusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 258, 248, 16)];
    self.statusLabel.font = [NSFont systemFontOfSize:11.5 weight:NSFontWeightMedium];
    self.statusLabel.textColor = [NSColor colorWithCalibratedWhite:0.65 alpha:1.0];
    self.statusLabel.bezeled = NO; self.statusLabel.drawsBackground = NO; self.statusLabel.editable = NO;
    [root addSubview:self.statusLabel];

    // Settings Gear Button
    NSButton *settingsBtn = [[NSButton alloc] initWithFrame:NSMakeRect(270, 282, 26, 26)];
    settingsBtn.bordered = NO;
    settingsBtn.wantsLayer = YES;
    settingsBtn.layer.cornerRadius = 13.0;
    settingsBtn.layer.backgroundColor = [NSColor colorWithCalibratedWhite:0.20 alpha:0.4].CGColor;
    settingsBtn.image = [NSImage imageWithSystemSymbolName:@"gearshape" accessibilityDescription:@"Settings"];
    settingsBtn.imagePosition = NSImageOnly;
    settingsBtn.contentTintColor = [NSColor colorWithCalibratedWhite:0.85 alpha:1.0];
    settingsBtn.target = self;
    settingsBtn.action = @selector(onSettingsClicked:);
    settingsBtn.toolTip = @"Open Dashboard & Settings";
    [root addSubview:settingsBtn];

    // --- Charge Limit Card (Width 282 pt, x: 14 to 296) ---
    NSBox *sliderCard = [[NSBox alloc] initWithFrame:NSMakeRect(14, 102, 282, 146)];
    sliderCard.titlePosition = NSNoTitle;
    sliderCard.boxType = NSBoxCustom;
    sliderCard.cornerRadius = 10.0;
    sliderCard.borderWidth = 1.0;
    sliderCard.borderColor = [NSColor colorWithCalibratedWhite:0.25 alpha:0.4];
    sliderCard.fillColor = [NSColor colorWithCalibratedRed:0.13 green:0.14 blue:0.17 alpha:1.0];
    [root addSubview:sliderCard];

    NSView *cardContent = sliderCard.contentView;

    NSTextField *limitTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(12, 114, 120, 18)];
    limitTitle.stringValue = @"Charge Limit";
    limitTitle.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
    limitTitle.textColor = [NSColor colorWithCalibratedWhite:0.85 alpha:1.0];
    limitTitle.bezeled = NO; limitTitle.drawsBackground = NO; limitTitle.editable = NO;
    [cardContent addSubview:limitTitle];

    self.limitValueLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(186, 114, 60, 18)];
    self.limitValueLabel.alignment = NSTextAlignmentRight;
    self.limitValueLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
    self.limitValueLabel.textColor = [NSColor colorWithCalibratedRed:0.0 green:0.82 blue:1.0 alpha:1.0];
    self.limitValueLabel.bezeled = NO; self.limitValueLabel.drawsBackground = NO; self.limitValueLabel.editable = NO;
    [cardContent addSubview:self.limitValueLabel];

    // Continuous Slider (20% to 100%)
    self.limitSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(12, 74, 258, 24)];
    self.limitSlider.minValue = 20.0;
    self.limitSlider.maxValue = 100.0;
    self.limitSlider.continuous = YES;
    self.limitSlider.target = self;
    self.limitSlider.action = @selector(onSliderChanged:);
    [cardContent addSubview:self.limitSlider];

    // --- 11 Symmetrical Presets (38 x 22 pt pills, 6 pt gap) ---
    // Row 1: 50%, 55%, 60%, 65%, 70%, 75% (Full Width: 6 * 38 + 5 * 6 = 258 pt)
    NSArray *row1Presets = @[@50, @55, @60, @65, @70, @75];
    CGFloat btnW = 38.0;
    CGFloat btnH = 22.0;
    CGFloat gap = 6.0;
    CGFloat startX = 12.0;

    for (int i = 0; i < row1Presets.count; i++) {
        NSNumber *val = row1Presets[i];
        NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(startX + i * (btnW + gap), 40, btnW, btnH)];
        btn.tag = val.intValue;
        btn.target = self;
        btn.action = @selector(onPresetClicked:);
        [cardContent addSubview:btn];
        [self.presetButtons addObject:btn];
    }

    // Row 2: 80%, 85%, 90%, 95%, 100% (Centered: 5 * 38 + 4 * 6 = 214 pt, margin: 22 pt)
    NSArray *row2Presets = @[@80, @85, @90, @95, @100];
    CGFloat row2StartX = startX + 22.0;

    for (int i = 0; i < row2Presets.count; i++) {
        NSNumber *val = row2Presets[i];
        NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(row2StartX + i * (btnW + gap), 12, btnW, btnH)];
        btn.tag = val.intValue;
        btn.target = self;
        btn.action = @selector(onPresetClicked:);
        [cardContent addSubview:btn];
        [self.presetButtons addObject:btn];
    }

    // --- Action Buttons: 3 Equal Peers Side-by-Side (88 x 32 pt pills, 9 pt gap) ---
    CGFloat actionY = 58;
    CGFloat actW = 88.0;
    CGFloat actH = 32.0;
    CGFloat actGap = 9.0;

    // 1. Stop Charge Button (Hold at Current %)
    self.stopChargeButton = [[NSButton alloc] initWithFrame:NSMakeRect(14, actionY, actW, actH)];
    self.stopChargeButton.target = self;
    self.stopChargeButton.action = @selector(onStopChargeClicked:);
    self.stopChargeButton.toolTip = @"Set charge limit to current battery percentage to stop charging and run on AC power.";
    [root addSubview:self.stopChargeButton];

    // 2. Top Up Button (Charge to 100% once)
    self.topUpButton = [[NSButton alloc] initWithFrame:NSMakeRect(14 + actW + actGap, actionY, actW, actH)];
    self.topUpButton.target = self;
    self.topUpButton.action = @selector(onTopUpClicked:);
    self.topUpButton.toolTip = @"Temporarily charge battery to 100% for travel.";
    [root addSubview:self.topUpButton];

    // 3. Discharge Button (Force discharge on AC)
    self.dischargeButton = [[NSButton alloc] initWithFrame:NSMakeRect(14 + (actW + actGap) * 2, actionY, actW, actH)];
    self.dischargeButton.target = self;
    self.dischargeButton.action = @selector(onDischargeClicked:);
    self.dischargeButton.toolTip = @"Discharge battery to limit while remaining plugged in.";
    [root addSubview:self.dischargeButton];

    // --- Footer Telemetry (x: 14 to 296) ---
    self.footerLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 12, 248, 34)];
    self.footerLabel.font = [NSFont systemFontOfSize:10 weight:NSFontWeightRegular];
    self.footerLabel.textColor = [NSColor colorWithCalibratedWhite:0.62 alpha:1.0];
    self.footerLabel.bezeled = NO; self.footerLabel.drawsBackground = NO; self.footerLabel.editable = NO;
    [root addSubview:self.footerLabel];

    // Quit Power Button (Cleanly aligned at 270)
    NSButton *quitBtn = [[NSButton alloc] initWithFrame:NSMakeRect(270, 16, 26, 26)];
    quitBtn.bordered = NO;
    quitBtn.wantsLayer = YES;
    quitBtn.layer.cornerRadius = 13.0;
    quitBtn.layer.backgroundColor = [NSColor colorWithCalibratedWhite:0.20 alpha:0.4].CGColor;
    quitBtn.image = [NSImage imageWithSystemSymbolName:@"power" accessibilityDescription:@"Quit"];
    quitBtn.imagePosition = NSImageOnly;
    quitBtn.contentTintColor = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
    quitBtn.target = self;
    quitBtn.action = @selector(onQuitClicked:);
    quitBtn.toolTip = @"Quit VoltCraft";
    [root addSubview:quitBtn];

    [self refreshUI];
}

// Helper to style preset pill buttons with consistent state highlighting
- (void)updatePresetButton:(NSButton *)btn isSelected:(BOOL)selected {
    btn.bordered = NO;
    btn.wantsLayer = YES;
    btn.layer.cornerRadius = 6.0;

    NSString *titleStr = [NSString stringWithFormat:@"%ld%%", (long)btn.tag];

    if (selected) {
        btn.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.0 green:0.75 blue:1.0 alpha:0.32].CGColor;
        btn.layer.borderColor = [NSColor colorWithCalibratedRed:0.0 green:0.85 blue:1.0 alpha:0.9].CGColor;
        btn.layer.borderWidth = 1.0;

        NSDictionary *attrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:10.5 weight:NSFontWeightBold],
            NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:0.0 green:0.90 blue:1.0 alpha:1.0]
        };
        btn.attributedTitle = [[NSAttributedString alloc] initWithString:titleStr attributes:attrs];
    } else {
        btn.layer.backgroundColor = [NSColor colorWithCalibratedWhite:0.20 alpha:0.45].CGColor;
        btn.layer.borderColor = [NSColor colorWithCalibratedWhite:0.35 alpha:0.30].CGColor;
        btn.layer.borderWidth = 0.5;

        NSDictionary *attrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:10.5 weight:NSFontWeightMedium],
            NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.80 alpha:1.0]
        };
        btn.attributedTitle = [[NSAttributedString alloc] initWithString:titleStr attributes:attrs];
    }
}

// Helper to style action pill buttons with consistent state highlighting
- (void)styleActionButton:(NSButton *)btn
                   active:(BOOL)active
              accentColor:(NSColor *)accentColor
                    title:(NSString *)title
                 iconName:(NSString *)iconName {
    btn.bordered = NO;
    btn.wantsLayer = YES;
    btn.layer.cornerRadius = 7.0;
    btn.image = [NSImage imageWithSystemSymbolName:iconName accessibilityDescription:nil];
    btn.imagePosition = NSImageLeft;

    if (active) {
        btn.layer.backgroundColor = [accentColor colorWithAlphaComponent:0.25].CGColor;
        btn.layer.borderColor = [accentColor colorWithAlphaComponent:0.85].CGColor;
        btn.layer.borderWidth = 1.0;
        btn.contentTintColor = accentColor;

        NSDictionary *attrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:10.5 weight:NSFontWeightSemibold],
            NSForegroundColorAttributeName: accentColor
        };
        btn.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:attrs];
    } else {
        btn.layer.backgroundColor = [NSColor colorWithCalibratedWhite:0.20 alpha:0.45].CGColor;
        btn.layer.borderColor = [NSColor colorWithCalibratedWhite:0.35 alpha:0.30].CGColor;
        btn.layer.borderWidth = 0.5;
        btn.contentTintColor = [NSColor colorWithCalibratedWhite:0.82 alpha:1.0];

        NSDictionary *attrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:10.5 weight:NSFontWeightMedium],
            NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.82 alpha:1.0]
        };
        btn.attributedTitle = [[NSAttributedString alloc] initWithString:title attributes:attrs];
    }
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

    // Dynamic Status Subtitle Color
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

    // Refresh all 11 presets with matching active highlight
    for (NSButton *btn in self.presetButtons) {
        BOOL isMatch = (btn.tag == cfg->chargeLimit);
        [self updatePresetButton:btn isSelected:isMatch];
    }

    // Refresh Action Button 1: Stop Charge (Cyan when holding/active)
    BOOL isHolding = tel.externalConnected && (cfg->chargeLimit == tel.currentCapacity || state == ChargeStateHoldingLimit);
    BOOL stopActive = isHolding && !cfg->isDischarging && !cfg->isTopUpActive;
    NSColor *cyanColor = [NSColor colorWithCalibratedRed:0.0 green:0.82 blue:1.0 alpha:1.0];
    NSString *stopTitle = stopActive ? @" Holding" : @" Stop Charge";
    [self styleActionButton:self.stopChargeButton
                     active:stopActive
                accentColor:cyanColor
                      title:stopTitle
                   iconName:@"bolt.slash.fill"];

    // Refresh Action Button 2: Top Up (Green when active)
    NSColor *greenColor = [NSColor colorWithCalibratedRed:0.20 green:0.85 blue:0.40 alpha:1.0];
    NSString *topUpTitle = cfg->isTopUpActive ? @" Active" : @" Top Up";
    [self styleActionButton:self.topUpButton
                     active:cfg->isTopUpActive
                accentColor:greenColor
                      title:topUpTitle
                   iconName:@"bolt.fill"];

    // Refresh Action Button 3: Discharge (Orange when active)
    BOOL dischActive = (cfg->isDischarging || state == ChargeStateDischarging);
    NSColor *orangeColor = [NSColor systemOrangeColor];
    NSString *dischTitle = dischActive ? @" Discharging" : @" Discharge";
    [self styleActionButton:self.dischargeButton
                     active:dischActive
                accentColor:orangeColor
                      title:dischTitle
                   iconName:@"arrow.down.circle"];

    // Footer Telemetry: Voltage & Live Power Flow
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
