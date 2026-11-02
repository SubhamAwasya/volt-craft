#import "slider_popover.h"
#import "battery_core.h"

// Modern, symmetrically centered action pill button
@interface ActionPillButton : NSButton
@property (nonatomic, strong) NSColor *accentColor;
@property (nonatomic) BOOL isActive;
@property (nonatomic, strong) NSString *iconSymbolName;
@property (nonatomic, strong) NSString *actionTitle;
@end

@implementation ActionPillButton

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.bordered = NO;
        self.wantsLayer = YES;
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    // 1. Draw pill background and border
    NSBezierPath *bgPath = [NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:7.0 yRadius:7.0];
    if (self.isActive && self.accentColor) {
        [[self.accentColor colorWithAlphaComponent:0.25] setFill];
        [bgPath fill];
        [[self.accentColor colorWithAlphaComponent:0.85] setStroke];
        [bgPath setLineWidth:1.0];
        [bgPath stroke];
    } else {
        [[NSColor colorWithCalibratedWhite:0.20 alpha:0.45] setFill];
        [bgPath fill];
        [[NSColor colorWithCalibratedWhite:0.35 alpha:0.30] setStroke];
        [bgPath setLineWidth:0.5];
        [bgPath stroke];
    }

    if (self.cell.isHighlighted) {
        [[NSColor colorWithCalibratedWhite:1.0 alpha:0.12] setFill];
        [bgPath fill];
    }

    // 2. Measure text and icon to center them together as a unified visual block
    NSColor *textColor = (self.isActive && self.accentColor) ? self.accentColor : [NSColor colorWithCalibratedWhite:0.85 alpha:1.0];
    NSFont *font = [NSFont systemFontOfSize:10.5 weight:self.isActive ? NSFontWeightSemibold : NSFontWeightMedium];
    NSDictionary *attrs = @{
        NSFontAttributeName: font,
        NSForegroundColorAttributeName: textColor
    };
    NSSize textSize = [self.actionTitle sizeWithAttributes:attrs];

    NSImage *icon = nil;
    if (self.iconSymbolName) {
        NSImageSymbolConfiguration *pointCfg = [NSImageSymbolConfiguration configurationWithPointSize:12.0 weight:NSFontWeightMedium];
        NSImageSymbolConfiguration *colorCfg = [NSImageSymbolConfiguration configurationWithPaletteColors:@[textColor]];
        NSImageSymbolConfiguration *combined = [pointCfg configurationByApplyingConfiguration:colorCfg];
        icon = [[NSImage imageWithSystemSymbolName:self.iconSymbolName accessibilityDescription:nil] imageWithSymbolConfiguration:combined];
    }

    CGFloat iconW = icon ? icon.size.width : 0.0;
    CGFloat iconH = icon ? icon.size.height : 0.0;
    CGFloat gap = (icon && self.actionTitle.length > 0) ? 5.0 : 0.0;
    CGFloat totalW = iconW + gap + textSize.width;

    // Centered start X with identical left and right padding
    CGFloat startX = round((self.bounds.size.width - totalW) / 2.0);

    // 3. Draw Icon
    if (icon) {
        CGFloat iconY = round((self.bounds.size.height - iconH) / 2.0);
        NSRect iconRect = NSMakeRect(startX, iconY, iconW, iconH);
        [icon drawInRect:iconRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0 respectFlipped:YES hints:nil];
    }

    // 4. Draw Text
    CGFloat textX = startX + iconW + gap;
    CGFloat textY = round((self.bounds.size.height - textSize.height) / 2.0);
    [self.actionTitle drawAtPoint:NSMakePoint(textX, textY) withAttributes:attrs];
}

@end

@interface SliderPopoverViewController ()

@property (nonatomic, strong) NSTextField *pctLabel;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSTextField *limitValueLabel;
@property (nonatomic, strong) NSSlider *limitSlider;
@property (nonatomic, strong) NSMutableArray<NSButton *> *presetButtons;

@property (nonatomic, strong) ActionPillButton *stopChargeButton;
@property (nonatomic, strong) ActionPillButton *topUpButton;
@property (nonatomic, strong) ActionPillButton *dischargeButton;
@property (nonatomic, strong) NSTextField *footerLabel;

@end

@implementation SliderPopoverViewController

- (void)loadView {
    // Symmetrical 330 x 334 pt canvas
    NSRect frame = NSMakeRect(0, 0, 330, 334);
    NSView *root = [[NSView alloc] initWithFrame:frame];
    root.wantsLayer = YES;
    root.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.10 green:0.11 blue:0.13 alpha:1.0].CGColor;
    self.view = root;

    self.presetButtons = [NSMutableArray array];
    [self setupUI];
}

- (void)setupUI {
    NSView *root = self.view;

    // --- Header Row (Grid: Left 14 pt, Right 316 pt) ---
    self.pctLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 282, 120, 34)];
    self.pctLabel.font = [NSFont systemFontOfSize:26 weight:NSFontWeightBold];
    self.pctLabel.textColor = [NSColor whiteColor];
    self.pctLabel.bezeled = NO; self.pctLabel.drawsBackground = NO; self.pctLabel.editable = NO;
    [root addSubview:self.pctLabel];

    self.statusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 262, 260, 16)];
    self.statusLabel.font = [NSFont systemFontOfSize:11.5 weight:NSFontWeightMedium];
    self.statusLabel.textColor = [NSColor colorWithCalibratedWhite:0.65 alpha:1.0];
    self.statusLabel.bezeled = NO; self.statusLabel.drawsBackground = NO; self.statusLabel.editable = NO;
    [root addSubview:self.statusLabel];

    // Settings Gear Button (Aligned at right: 290 to 316)
    NSButton *settingsBtn = [[NSButton alloc] initWithFrame:NSMakeRect(290, 286, 26, 26)];
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

    // --- Charge Limit Card (Width 302 pt, x: 14 to 316) ---
    NSBox *sliderCard = [[NSBox alloc] initWithFrame:NSMakeRect(14, 102, 302, 150)];
    sliderCard.titlePosition = NSNoTitle;
    sliderCard.boxType = NSBoxCustom;
    sliderCard.cornerRadius = 10.0;
    sliderCard.borderWidth = 1.0;
    sliderCard.borderColor = [NSColor colorWithCalibratedWhite:0.25 alpha:0.4];
    sliderCard.fillColor = [NSColor colorWithCalibratedRed:0.13 green:0.14 blue:0.17 alpha:1.0];
    [root addSubview:sliderCard];

    NSView *cardContent = sliderCard.contentView;

    NSTextField *limitTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(12, 118, 120, 18)];
    limitTitle.stringValue = @"Charge Limit";
    limitTitle.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
    limitTitle.textColor = [NSColor colorWithCalibratedWhite:0.85 alpha:1.0];
    limitTitle.bezeled = NO; limitTitle.drawsBackground = NO; limitTitle.editable = NO;
    [cardContent addSubview:limitTitle];

    self.limitValueLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(206, 118, 60, 18)];
    self.limitValueLabel.alignment = NSTextAlignmentRight;
    self.limitValueLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
    self.limitValueLabel.textColor = [NSColor colorWithCalibratedRed:0.0 green:0.82 blue:1.0 alpha:1.0];
    self.limitValueLabel.bezeled = NO; self.limitValueLabel.drawsBackground = NO; self.limitValueLabel.editable = NO;
    [cardContent addSubview:self.limitValueLabel];

    // Continuous Slider (20% to 100%)
    self.limitSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(12, 78, 278, 24)];
    self.limitSlider.minValue = 20.0;
    self.limitSlider.maxValue = 100.0;
    self.limitSlider.continuous = YES;
    self.limitSlider.target = self;
    self.limitSlider.action = @selector(onSliderChanged:);
    [cardContent addSubview:self.limitSlider];

    // --- 10 Symmetrical Presets (5x2 Grid: 50.0 x 24.0 pt pills, 7.0 pt gap) ---
    // 50% removed per user request: perfectly symmetrical 5 on top, 5 on bottom!
    NSArray *row1Presets = @[@55, @60, @65, @70, @75];
    NSArray *row2Presets = @[@80, @85, @90, @95, @100];
    CGFloat btnW = 50.0;
    CGFloat btnH = 24.0;
    CGFloat gap = 7.0;
    CGFloat startX = 12.0;

    // Row 1: 55%, 60%, 65%, 70%, 75%
    for (int i = 0; i < row1Presets.count; i++) {
        NSNumber *val = row1Presets[i];
        NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(startX + i * (btnW + gap), 42, btnW, btnH)];
        btn.tag = val.intValue;
        btn.target = self;
        btn.action = @selector(onPresetClicked:);
        [cardContent addSubview:btn];
        [self.presetButtons addObject:btn];
    }

    // Row 2: 80%, 85%, 90%, 95%, 100% (Exact column alignment with Row 1)
    for (int i = 0; i < row2Presets.count; i++) {
        NSNumber *val = row2Presets[i];
        NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(startX + i * (btnW + gap), 12, btnW, btnH)];
        btn.tag = val.intValue;
        btn.target = self;
        btn.action = @selector(onPresetClicked:);
        [cardContent addSubview:btn];
        [self.presetButtons addObject:btn];
    }

    // --- Action Buttons: 3 Equal Peers Side-by-Side (96 x 32 pt pills, 7 pt gap) ---
    CGFloat actionY = 58;
    CGFloat actW = 96.0;
    CGFloat actH = 32.0;
    CGFloat actGap = 7.0;

    // 1. Stop Charge Button (Hold at Current %)
    self.stopChargeButton = [[ActionPillButton alloc] initWithFrame:NSMakeRect(14, actionY, actW, actH)];
    self.stopChargeButton.target = self;
    self.stopChargeButton.action = @selector(onStopChargeClicked:);
    self.stopChargeButton.toolTip = @"Set charge limit to current battery percentage to stop charging and run on AC power.";
    [root addSubview:self.stopChargeButton];

    // 2. Top Up Button (Charge to 100% once)
    self.topUpButton = [[ActionPillButton alloc] initWithFrame:NSMakeRect(14 + actW + actGap, actionY, actW, actH)];
    self.topUpButton.target = self;
    self.topUpButton.action = @selector(onTopUpClicked:);
    self.topUpButton.toolTip = @"Temporarily charge battery to 100% for travel.";
    [root addSubview:self.topUpButton];

    // 3. Discharge Button (Force discharge on AC)
    self.dischargeButton = [[ActionPillButton alloc] initWithFrame:NSMakeRect(14 + (actW + actGap) * 2, actionY, actW, actH)];
    self.dischargeButton.target = self;
    self.dischargeButton.action = @selector(onDischargeClicked:);
    self.dischargeButton.toolTip = @"Discharge battery to limit while remaining plugged in.";
    [root addSubview:self.dischargeButton];

    // --- Footer Telemetry (x: 14 to 316) ---
    self.footerLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 12, 268, 34)];
    self.footerLabel.font = [NSFont systemFontOfSize:10 weight:NSFontWeightRegular];
    self.footerLabel.textColor = [NSColor colorWithCalibratedWhite:0.62 alpha:1.0];
    self.footerLabel.bezeled = NO; self.footerLabel.drawsBackground = NO; self.footerLabel.editable = NO;
    [root addSubview:self.footerLabel];

    // Quit Power Button (Cleanly aligned at 290 to 316)
    NSButton *quitBtn = [[NSButton alloc] initWithFrame:NSMakeRect(290, 16, 26, 26)];
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

// Helper to style preset pill buttons with active accent glow
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
            NSFontAttributeName: [NSFont systemFontOfSize:11.0 weight:NSFontWeightBold],
            NSForegroundColorAttributeName: [NSColor colorWithCalibratedRed:0.0 green:0.90 blue:1.0 alpha:1.0]
        };
        btn.attributedTitle = [[NSAttributedString alloc] initWithString:titleStr attributes:attrs];
    } else {
        btn.layer.backgroundColor = [NSColor colorWithCalibratedWhite:0.20 alpha:0.45].CGColor;
        btn.layer.borderColor = [NSColor colorWithCalibratedWhite:0.35 alpha:0.30].CGColor;
        btn.layer.borderWidth = 0.5;

        NSDictionary *attrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:11.0 weight:NSFontWeightMedium],
            NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.80 alpha:1.0]
        };
        btn.attributedTitle = [[NSAttributedString alloc] initWithString:titleStr attributes:attrs];
    }
}

// Helper to style action pill buttons with perfectly centered icon + label and balanced padding
- (void)styleActionButton:(ActionPillButton *)btn
                   active:(BOOL)active
              accentColor:(NSColor *)accentColor
                    title:(NSString *)title
                 iconName:(NSString *)iconName {
    btn.isActive = active;
    btn.accentColor = accentColor;
    btn.actionTitle = title;
    btn.iconSymbolName = iconName;
    [btn setNeedsDisplay:YES];
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

    // Refresh all 10 presets (55% to 100%)
    for (NSButton *btn in self.presetButtons) {
        BOOL isMatch = (btn.tag == cfg->chargeLimit);
        [self updatePresetButton:btn isSelected:isMatch];
    }

    // Refresh Action Button 1: Stop Charge (Cyan when holding/active)
    BOOL isHolding = tel.externalConnected && (cfg->chargeLimit == tel.currentCapacity || state == ChargeStateHoldingLimit);
    BOOL stopActive = isHolding && !cfg->isDischarging && !cfg->isTopUpActive;
    NSColor *cyanColor = [NSColor colorWithCalibratedRed:0.0 green:0.82 blue:1.0 alpha:1.0];
    NSString *stopTitle = stopActive ? @"Holding" : @"Stop Charge";
    [self styleActionButton:self.stopChargeButton
                     active:stopActive
                accentColor:cyanColor
                      title:stopTitle
                   iconName:@"bolt.slash.fill"];

    // Refresh Action Button 2: Top Up (Green when active)
    NSColor *greenColor = [NSColor colorWithCalibratedRed:0.20 green:0.85 blue:0.40 alpha:1.0];
    NSString *topUpTitle = cfg->isTopUpActive ? @"Active" : @"Top Up";
    [self styleActionButton:self.topUpButton
                     active:cfg->isTopUpActive
                accentColor:greenColor
                      title:topUpTitle
                   iconName:@"bolt.fill"];

    // Refresh Action Button 3: Discharge (Orange when active)
    BOOL dischActive = (cfg->isDischarging || state == ChargeStateDischarging);
    NSColor *orangeColor = [NSColor systemOrangeColor];
    NSString *dischTitle = dischActive ? @"Discharging" : @"Discharge";
    [self styleActionButton:self.dischargeButton
                     active:dischActive
                accentColor:orangeColor
                      title:dischTitle
                   iconName:@"arrow.down"];

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
