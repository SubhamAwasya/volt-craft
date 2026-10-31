#import "charge_control_view.h"
#import "battery_core.h"

@interface ChargeControlView ()

@property (nonatomic, strong) NSTextField *socValueLabel;
@property (nonatomic, strong) NSTextField *stateBadgeLabel;
@property (nonatomic, strong) NSTextField *limitDisplayLabel;
@property (nonatomic, strong) NSSlider *limitSlider;
@property (nonatomic, strong) NSButton *topUpBtn;
@property (nonatomic, strong) NSButton *dischargeBtn;

// Sailing Mode
@property (nonatomic, strong) NSButton *sailingSwitch;
@property (nonatomic, strong) NSSlider *sailingSlider;
@property (nonatomic, strong) NSTextField *sailingDescLabel;

// Heat Protection
@property (nonatomic, strong) NSButton *heatSwitch;
@property (nonatomic, strong) NSSlider *heatSlider;
@property (nonatomic, strong) NSTextField *heatDescLabel;

@end

@implementation ChargeControlView

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
    CGFloat y = 600;
    CGFloat w = 720;

    // Header Title & Subtitle (Consistent with other tabs)
    NSTextField *title = [[NSTextField alloc] initWithFrame:NSMakeRect(25, y, 400, 28)];
    title.stringValue = @"Charge Control";
    title.font = [NSFont boldSystemFontOfSize:22];
    title.textColor = [NSColor whiteColor];
    title.bezeled = NO; title.drawsBackground = NO; title.editable = NO;
    [self addSubview:title];

    NSTextField *subtitle = [[NSTextField alloc] initWithFrame:NSMakeRect(25, y - 25, 650, 20)];
    subtitle.stringValue = @"Configure battery charge limit, sailing mode, and thermal protection.";
    subtitle.font = [NSFont systemFontOfSize:12];
    subtitle.textColor = [NSColor colorWithCalibratedWhite:0.65 alpha:1.0];
    subtitle.bezeled = NO; subtitle.drawsBackground = NO; subtitle.editable = NO;
    [self addSubview:subtitle];

    y = 380;

    // --- Card 1: Charge Limit Slider Card (w: 690, h: 180) ---
    NSBox *limitCard = [[NSBox alloc] initWithFrame:NSMakeRect(25, y, 690, 180)];
    limitCard.title = @"";
    limitCard.boxType = NSBoxCustom;
    limitCard.cornerRadius = 14.0;
    limitCard.fillColor = [NSColor colorWithCalibratedRed:0.13 green:0.14 blue:0.16 alpha:0.95];
    limitCard.borderColor = [NSColor colorWithCalibratedRed:0.20 green:0.22 blue:0.25 alpha:1.0];
    limitCard.borderWidth = 1.0;
    [self addSubview:limitCard];

    NSTextField *cardHeader = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 145, 200, 20)];
    cardHeader.stringValue = @"Max Charge Limit";
    cardHeader.font = [NSFont boldSystemFontOfSize:14];
    cardHeader.textColor = [NSColor whiteColor];
    cardHeader.bezeled = NO; cardHeader.drawsBackground = NO; cardHeader.editable = NO;
    [limitCard addSubview:cardHeader];

    self.limitDisplayLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(550, 138, 120, 28)];
    self.limitDisplayLabel.stringValue = @"80 %";
    self.limitDisplayLabel.alignment = NSTextAlignmentRight;
    self.limitDisplayLabel.font = [NSFont boldSystemFontOfSize:22];
    self.limitDisplayLabel.textColor = [NSColor systemBlueColor];
    self.limitDisplayLabel.bezeled = NO; self.limitDisplayLabel.drawsBackground = NO; self.limitDisplayLabel.editable = NO;
    [limitCard addSubview:self.limitDisplayLabel];

    // Status Indicator inside card (replaces the awkward green banner)
    self.stateBadgeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 120, 500, 18)];
    self.stateBadgeLabel.stringValue = @"● Status: Holding at 80% • Active Power Management";
    self.stateBadgeLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.stateBadgeLabel.textColor = [NSColor colorWithCalibratedRed:0.2 green:0.85 blue:0.45 alpha:1.0];
    self.stateBadgeLabel.bezeled = NO; self.stateBadgeLabel.drawsBackground = NO; self.stateBadgeLabel.editable = NO;
    [limitCard addSubview:self.stateBadgeLabel];

    self.limitSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(20, 80, 650, 26)];
    self.limitSlider.minValue = 20.0;
    self.limitSlider.maxValue = 100.0;
    self.limitSlider.integerValue = 80;
    self.limitSlider.continuous = YES;
    self.limitSlider.target = self;
    self.limitSlider.action = @selector(onLimitSliderChanged:);
    [limitCard addSubview:self.limitSlider];

    // Presets Row
    int presets[] = {60, 70, 75, 80, 85, 90, 100};
    CGFloat pW = 80;
    for (int i = 0; i < 7; i++) {
        NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(20 + i * (pW + 12), 30, pW, 28)];
        btn.bezelStyle = NSBezelStyleRoundRect;
        btn.title = [NSString stringWithFormat:@"%d%%", presets[i]];
        btn.font = [NSFont boldSystemFontOfSize:12];
        btn.tag = presets[i];
        btn.target = self;
        btn.action = @selector(onPresetClicked:);
        [limitCard addSubview:btn];
    }

    y = 320;

    // --- Action Buttons: Top Up & Discharge ---
    self.topUpBtn = [[NSButton alloc] initWithFrame:NSMakeRect(25, y, 335, 42)];
    self.topUpBtn.bezelStyle = NSBezelStyleRoundRect;
    self.topUpBtn.title = @"Top Up to 100% (Travel Mode)";
    self.topUpBtn.font = [NSFont boldSystemFontOfSize:13];
    self.topUpBtn.target = self;
    self.topUpBtn.action = @selector(onToggleTopUpClicked:);
    [self addSubview:self.topUpBtn];

    self.dischargeBtn = [[NSButton alloc] initWithFrame:NSMakeRect(380, y, 335, 42)];
    self.dischargeBtn.bezelStyle = NSBezelStyleRoundRect;
    self.dischargeBtn.title = @"Forced Discharge (Discharge on AC)";
    self.dischargeBtn.font = [NSFont boldSystemFontOfSize:13];
    self.dischargeBtn.target = self;
    self.dischargeBtn.action = @selector(onToggleDischargeClicked:);
    [self addSubview:self.dischargeBtn];

    y = 175;

    // --- Card 2: Sailing Mode ---
    NSBox *sailingCard = [[NSBox alloc] initWithFrame:NSMakeRect(25, y, 690, 130)];
    sailingCard.title = @"";
    sailingCard.boxType = NSBoxCustom;
    sailingCard.cornerRadius = 14.0;
    sailingCard.fillColor = [NSColor colorWithCalibratedRed:0.13 green:0.14 blue:0.16 alpha:0.95];
    sailingCard.borderColor = [NSColor colorWithCalibratedRed:0.20 green:0.22 blue:0.25 alpha:1.0];
    sailingCard.borderWidth = 1.0;
    [self addSubview:sailingCard];

    self.sailingSwitch = [[NSButton alloc] initWithFrame:NSMakeRect(20, 80, 200, 24)];
    self.sailingSwitch.buttonType = NSButtonTypeSwitch;
    self.sailingSwitch.title = @"Sailing Mode";
    self.sailingSwitch.font = [NSFont boldSystemFontOfSize:13];
    self.sailingSwitch.target = self;
    self.sailingSwitch.action = @selector(onToggleSailingClicked:);
    [sailingCard addSubview:self.sailingSwitch];

    self.sailingSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(240, 80, 430, 22)];
    self.sailingSlider.minValue = 1.0;
    self.sailingSlider.maxValue = 15.0;
    self.sailingSlider.integerValue = 5;
    self.sailingSlider.continuous = YES;
    self.sailingSlider.target = self;
    self.sailingSlider.action = @selector(onSailingSliderChanged:);
    [sailingCard addSubview:self.sailingSlider];

    self.sailingDescLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 20, 650, 40)];
    self.sailingDescLabel.stringValue = @"Sailing Mode charges your battery to the limit, then allows it to discharge before recharging to reduce cycle wear.";
    self.sailingDescLabel.font = [NSFont systemFontOfSize:11];
    self.sailingDescLabel.textColor = [NSColor colorWithCalibratedWhite:0.65 alpha:1.0];
    self.sailingDescLabel.bezeled = NO; self.sailingDescLabel.drawsBackground = NO; self.sailingDescLabel.editable = NO;
    [sailingCard addSubview:self.sailingDescLabel];

    y = 25;

    // --- Card 3: Heat Protection ---
    NSBox *heatCard = [[NSBox alloc] initWithFrame:NSMakeRect(25, y, 690, 130)];
    heatCard.title = @"";
    heatCard.boxType = NSBoxCustom;
    heatCard.cornerRadius = 14.0;
    heatCard.fillColor = [NSColor colorWithCalibratedRed:0.13 green:0.14 blue:0.16 alpha:0.95];
    heatCard.borderColor = [NSColor colorWithCalibratedRed:0.20 green:0.22 blue:0.25 alpha:1.0];
    heatCard.borderWidth = 1.0;
    [self addSubview:heatCard];

    self.heatSwitch = [[NSButton alloc] initWithFrame:NSMakeRect(20, 80, 200, 24)];
    self.heatSwitch.buttonType = NSButtonTypeSwitch;
    self.heatSwitch.title = @"Heat Protection";
    self.heatSwitch.font = [NSFont boldSystemFontOfSize:13];
    self.heatSwitch.target = self;
    self.heatSwitch.action = @selector(onToggleHeatClicked:);
    [heatCard addSubview:self.heatSwitch];

    self.heatSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(240, 80, 430, 22)];
    self.heatSlider.minValue = 30.0;
    self.heatSlider.maxValue = 45.0;
    self.heatSlider.floatValue = 35.0f;
    self.heatSlider.continuous = YES;
    self.heatSlider.target = self;
    self.heatSlider.action = @selector(onHeatSliderChanged:);
    [heatCard addSubview:self.heatSlider];

    self.heatDescLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 20, 650, 40)];
    self.heatDescLabel.stringValue = @"Automatically pauses charging when the battery temperature reaches the safety cutoff threshold.";
    self.heatDescLabel.font = [NSFont systemFontOfSize:11];
    self.heatDescLabel.textColor = [NSColor colorWithCalibratedWhite:0.65 alpha:1.0];
    self.heatDescLabel.bezeled = NO; self.heatDescLabel.drawsBackground = NO; self.heatDescLabel.editable = NO;
    [heatCard addSubview:self.heatDescLabel];
}

- (void)refreshUI {
    VoltCraftConfig *cfg = getProConfig();
    BatteryTelemetry tel = getBatteryTelemetry();

    self.limitSlider.integerValue = cfg->chargeLimit;
    self.limitDisplayLabel.stringValue = [NSString stringWithFormat:@"%d %%", cfg->chargeLimit];

    ChargeState state = getOverallChargeState();
    NSString *stateDesc = getChargeStateDescription(state);
    self.stateBadgeLabel.stringValue = [NSString stringWithFormat:@"● Status: %@ (Active Power Management)", stateDesc];
    if (state == ChargeStateHeatPaused) {
        self.stateBadgeLabel.textColor = [NSColor systemOrangeColor];
    } else if (state == ChargeStateHoldingLimit || state == ChargeStateNormalCharging || state == ChargeStateTopUp) {
        self.stateBadgeLabel.textColor = [NSColor colorWithCalibratedRed:0.2 green:0.85 blue:0.45 alpha:1.0];
    } else {
        self.stateBadgeLabel.textColor = [NSColor colorWithCalibratedRed:0.3 green:0.7 blue:1.0 alpha:1.0];
    }

    self.topUpBtn.state = cfg->isTopUpActive ? NSControlStateValueOn : NSControlStateValueOff;
    self.dischargeBtn.state = cfg->isDischarging ? NSControlStateValueOn : NSControlStateValueOff;

    self.sailingSwitch.state = cfg->sailingEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.sailingSlider.integerValue = cfg->sailingDifference;
    int floor = MAX(20, cfg->chargeLimit - cfg->sailingDifference);
    if (cfg->sailingEnabled) {
        self.sailingDescLabel.stringValue = [NSString stringWithFormat:@"Sailing Active: Charges up to %d%%, then lets battery discharge naturally to %d%% before re-engaging.", cfg->chargeLimit, floor];
    } else {
        self.sailingDescLabel.stringValue = @"Sailing Mode is off (recharges immediately upon minor drop).";
    }

    self.heatSwitch.state = cfg->heatProtectionEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.heatSlider.floatValue = cfg->maxTemperatureC;
    self.heatDescLabel.stringValue = [NSString stringWithFormat:@"Threshold: %.1f °C  •  Current Temperature: %.1f °C (%@)",
                                      cfg->maxTemperatureC,
                                      tel.temperatureC,
                                      cfg->isHeatPaused ? @"Charging Paused (Thermal Limit)" : @"Safe Threshold"];
}

- (void)onLimitSliderChanged:(NSSlider *)sender {
    int limit = (int)round(sender.doubleValue);
    setChargeLimit(limit, nil);
    [self refreshUI];
}

- (void)onPresetClicked:(NSButton *)sender {
    setChargeLimit((int)sender.tag, nil);
    [self refreshUI];
}

- (void)onToggleTopUpClicked:(id)sender {
    toggleTopUp();
    [self refreshUI];
}

- (void)onToggleDischargeClicked:(id)sender {
    toggleDischarge();
    [self refreshUI];
}

- (void)onToggleSailingClicked:(NSButton *)sender {
    setSailingModeEnabled(sender.state == NSControlStateValueOn);
    [self refreshUI];
}

- (void)onSailingSliderChanged:(NSSlider *)sender {
    setSailingDifference((int)round(sender.doubleValue));
    [self refreshUI];
}

- (void)onToggleHeatClicked:(NSButton *)sender {
    setHeatProtectionEnabled(sender.state == NSControlStateValueOn);
    [self refreshUI];
}

- (void)onHeatSliderChanged:(NSSlider *)sender {
    setMaxTemperature((float)sender.doubleValue);
    [self refreshUI];
}

@end
