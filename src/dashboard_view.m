#import "dashboard_view.h"
#import "battery_core.h"

// Reusable Card View with dark translucent style
@interface DarkCardView : NSView
@property (nonatomic, copy) NSString *cardTitle;
@property (nonatomic, copy) NSString *iconText;
@end

@implementation DarkCardView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    NSRect bounds = self.bounds;
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:14.0 yRadius:14.0];

    // Card background
    [[NSColor colorWithCalibratedRed:0.13 green:0.14 blue:0.16 alpha:0.95] setFill];
    [path fill];

    // Card border
    [[NSColor colorWithCalibratedRed:0.20 green:0.22 blue:0.25 alpha:1.0] setStroke];
    [path setLineWidth:1.0];
    [path stroke];
}

@end

// Custom Wave / Chart View
@interface MiniWaveView : NSView
@property (nonatomic, strong) NSColor *gradientStart;
@property (nonatomic, strong) NSColor *gradientEnd;
@property (nonatomic, assign) BOOL isTemperature;
@end

@implementation MiniWaveView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    NSRect b = self.bounds;
    if (b.size.width <= 0 || b.size.height <= 0) return;

    NSBezierPath *clip = [NSBezierPath bezierPathWithRoundedRect:b xRadius:10.0 yRadius:10.0];
    [clip addClip];

    // Subtle dark gradient background
    NSColor *bgTop = [NSColor colorWithCalibratedRed:0.09 green:0.10 blue:0.12 alpha:0.8];
    NSColor *bgBottom = [NSColor colorWithCalibratedRed:0.07 green:0.08 blue:0.09 alpha:0.9];
    NSGradient *bgGrad = [[NSGradient alloc] initWithStartingColor:bgTop endingColor:bgBottom];
    [bgGrad drawInRect:b angle:90.0];

    // Draw smooth aesthetic waveform
    NSBezierPath *wave = [NSBezierPath bezierPath];
    [wave moveToPoint:NSMakePoint(0, 0)];

    CGFloat points = 8;
    CGFloat step = b.size.width / (points - 1);
    for (int i = 0; i < points; i++) {
        CGFloat x = i * step;
        CGFloat waveFactor = sin(i * 0.8) * 0.3 + 0.5;
        CGFloat y = b.size.height * (0.35 + waveFactor * 0.4);
        if (i == 0) {
            [wave lineToPoint:NSMakePoint(x, y)];
        } else {
            CGFloat prevX = (i - 1) * step;
            CGFloat cp1x = prevX + step * 0.5;
            CGFloat cp2x = prevX + step * 0.5;
            [wave curveToPoint:NSMakePoint(x, y) controlPoint1:NSMakePoint(cp1x, y) controlPoint2:NSMakePoint(cp2x, y)];
        }
    }
    [wave lineToPoint:NSMakePoint(b.size.width, 0)];
    [wave closePath];

    NSColor *c1 = self.gradientStart ?: [NSColor colorWithCalibratedRed:0.1 green:0.6 blue:0.4 alpha:0.45];
    NSColor *c2 = self.gradientEnd ?: [NSColor colorWithCalibratedRed:0.1 green:0.7 blue:0.5 alpha:0.05];
    NSGradient *g = [[NSGradient alloc] initWithStartingColor:c1 endingColor:c2];
    [g drawInBezierPath:wave angle:90.0];

    // Top glow stroke
    [[c1 colorWithAlphaComponent:0.85] setStroke];
    [wave setLineWidth:1.5];
    [wave stroke];
}

@end

@interface DashboardView ()

// Card 1: Battery Specs
@property (nonatomic, strong) NSTextField *specNominalCap;
@property (nonatomic, strong) NSTextField *specVoltage;
@property (nonatomic, strong) NSTextField *specChemistry;
@property (nonatomic, strong) NSTextField *specDevice;

// Card 2: Battery Health
@property (nonatomic, strong) NSTextField *healthDesignCap;
@property (nonatomic, strong) NSTextField *healthMaxCap;
@property (nonatomic, strong) NSTextField *healthCondition;
@property (nonatomic, strong) NSTextField *healthCycles;

// Card 3: Power Adapter Specs
@property (nonatomic, strong) NSTextField *adapterName;
@property (nonatomic, strong) NSTextField *adapterWatts;
@property (nonatomic, strong) NSTextField *adapterVoltage;
@property (nonatomic, strong) NSTextField *adapterManufacturer;

// Card 4: Battery Level
@property (nonatomic, strong) NSTextField *levelPercentage;
@property (nonatomic, strong) NSTextField *levelTime;

// Card 5: Battery Cycles
@property (nonatomic, strong) NSTextField *cycleCountLabel;
@property (nonatomic, strong) NSTextField *cycleHealthLabel;

// Card 6: Right Column Actions
@property (nonatomic, strong) NSTextField *energyAppsLabel;
@property (nonatomic, strong) NSButton *calibrationBtn;
@property (nonatomic, strong) NSButton *sleepPreventBtn;

// Card 7: Temperature
@property (nonatomic, strong) NSTextField *tempValueLabel;

// Card 8: Power Consumption
@property (nonatomic, strong) NSTextField *powerWattsLabel;
@property (nonatomic, strong) NSTextField *powerTimeLabel;

@end

@implementation DashboardView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.10 green:0.105 blue:0.115 alpha:1.0].CGColor;
        [self setupDashboardCards];
        [self refreshTelemetry];
    }
    return self;
}

- (void)setupDashboardCards {
    CGFloat cardW = 230;
    CGFloat gap = 14;
    CGFloat startX = 20;

    // ==========================================
    // TOP ROW: Y = 500, Height = 140
    // ==========================================
    CGFloat rowTopY = 500;
    CGFloat rowTopH = 140;

    // --- Card 1: Battery Specs (Top Left) ---
    DarkCardView *card1 = [[DarkCardView alloc] initWithFrame:NSMakeRect(startX, rowTopY, cardW, rowTopH)];
    [self addSubview:card1];

    NSTextField *t1 = [self createHeader:@"Battery Specs" inView:card1 atY:110];

    self.specDevice = [self createLabel:@"Device: Apple Silicon Battery" inView:card1 atX:14 atY:82 isSecondary:NO];
    self.specNominalCap = [self createLabel:@"Nominal: 4398 mAh" inView:card1 atX:14 atY:60 isSecondary:YES];
    self.specVoltage = [self createLabel:@"Voltage: 12.82 V" inView:card1 atX:14 atY:38 isSecondary:YES];
    self.specChemistry = [self createLabel:@"Chemistry: Li-ion Polymer" inView:card1 atX:14 atY:16 isSecondary:YES];

    // --- Card 2: Battery Health (Top Middle) ---
    DarkCardView *card2 = [[DarkCardView alloc] initWithFrame:NSMakeRect(startX + (cardW + gap), rowTopY, cardW, rowTopH)];
    [self addSubview:card2];

    NSTextField *t2 = [self createHeader:@"Battery Health" inView:card2 atY:110];

    self.healthDesignCap = [self createRowWithTitle:@"Design Capacity:" value:@"4563 mAh  100%" inView:card2 atY:82];
    self.healthMaxCap = [self createRowWithTitle:@"Maximum Capacity:" value:@"4262 mAh   93%" inView:card2 atY:60];
    self.healthCondition = [self createRowWithTitle:@"macOS Condition:" value:@"Normal" inView:card2 atY:38];
    self.healthCycles = [self createRowWithTitle:@"Cycle Count:" value:@"81" inView:card2 atY:16];

    // --- Card 3: Power Adapter Specs (Top Right) ---
    DarkCardView *card3 = [[DarkCardView alloc] initWithFrame:NSMakeRect(startX + (cardW + gap) * 2, rowTopY, cardW, rowTopH)];
    [self addSubview:card3];

    NSTextField *t3 = [self createHeader:@"Power Adapter Specs" inView:card3 atY:110];
    [self createBadge:@"CONNECTED" inView:card3 atX:145 atY:112];

    self.adapterName = [self createLabel:@"30W USB-C Power Adapter" inView:card3 atX:14 atY:82 isSecondary:NO];
    self.adapterWatts = [self createLabel:@"Power Tier: 30W (PD 3.0)" inView:card3 atX:14 atY:60 isSecondary:YES];
    self.adapterVoltage = [self createLabel:@"Voltage: 20V  •  Current: 1.49A" inView:card3 atX:14 atY:38 isSecondary:YES];
    self.adapterManufacturer = [self createLabel:@"Manufacturer: Apple Inc." inView:card3 atX:14 atY:16 isSecondary:YES];

    // ==========================================
    // MIDDLE ROW: Y = 310, Height = 175
    // ==========================================
    CGFloat rowMidY = 310;
    CGFloat rowMidH = 175;

    // --- Card 4: Battery Level & Time Remaining (Middle Left) ---
    DarkCardView *card4 = [[DarkCardView alloc] initWithFrame:NSMakeRect(startX, rowMidY, cardW, rowMidH)];
    [self addSubview:card4];

    [self createHeaderLabel:@"Battery Level" inView:card4 atX:14 atY:148];
    [self createHeaderLabel:@"Time Remaining" inView:card4 atX:115 atY:148];

    self.levelPercentage = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 118, 90, 26)];
    self.levelPercentage.stringValue = @"89 %";
    self.levelPercentage.font = [NSFont boldSystemFontOfSize:20];
    self.levelPercentage.textColor = [NSColor whiteColor];
    self.levelPercentage.bezeled = NO; self.levelPercentage.drawsBackground = NO; self.levelPercentage.editable = NO;
    [card4 addSubview:self.levelPercentage];

    self.levelTime = [[NSTextField alloc] initWithFrame:NSMakeRect(115, 118, 105, 26)];
    self.levelTime.stringValue = @"Connected";
    self.levelTime.font = [NSFont boldSystemFontOfSize:13];
    self.levelTime.textColor = [NSColor colorWithCalibratedRed:0.2 green:0.8 blue:0.4 alpha:1.0];
    self.levelTime.bezeled = NO; self.levelTime.drawsBackground = NO; self.levelTime.editable = NO;
    [card4 addSubview:self.levelTime];

    MiniWaveView *wave1 = [[MiniWaveView alloc] initWithFrame:NSMakeRect(12, 12, cardW - 24, 100)];
    wave1.gradientStart = [NSColor colorWithCalibratedRed:0.1 green:0.7 blue:0.45 alpha:0.5];
    wave1.gradientEnd = [NSColor colorWithCalibratedRed:0.05 green:0.35 blue:0.25 alpha:0.05];
    [card4 addSubview:wave1];

    // --- Card 5: Battery Cycles (Middle Center) ---
    DarkCardView *card5 = [[DarkCardView alloc] initWithFrame:NSMakeRect(startX + (cardW + gap), rowMidY, cardW, rowMidH)];
    [self addSubview:card5];

    [self createHeaderLabel:@"Battery Cycles" inView:card5 atX:14 atY:148];

    self.cycleCountLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 118, 140, 26)];
    self.cycleCountLabel.stringValue = @"81 Cycles";
    self.cycleCountLabel.font = [NSFont boldSystemFontOfSize:18];
    self.cycleCountLabel.textColor = [NSColor whiteColor];
    self.cycleCountLabel.bezeled = NO; self.cycleCountLabel.drawsBackground = NO; self.cycleCountLabel.editable = NO;
    [card5 addSubview:self.cycleCountLabel];

    MiniWaveView *waveCycles = [[MiniWaveView alloc] initWithFrame:NSMakeRect(12, 12, cardW - 24, 100)];
    waveCycles.gradientStart = [NSColor colorWithCalibratedRed:0.85 green:0.35 blue:0.3 alpha:0.45];
    waveCycles.gradientEnd = [NSColor colorWithCalibratedRed:0.45 green:0.15 blue:0.15 alpha:0.05];
    [card5 addSubview:waveCycles];

    // Cycle diagnostics overlay
    NSTextField *cycleInfo = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 42, cardW - 40, 40)];
    cycleInfo.stringValue = @"8.1% of 1,000 rated cycles used\n91.9% lifespan remaining";
    cycleInfo.font = [NSFont systemFontOfSize:10 weight:NSFontWeightMedium];
    cycleInfo.alignment = NSTextAlignmentCenter;
    cycleInfo.textColor = [NSColor whiteColor];
    cycleInfo.bezeled = NO; cycleInfo.drawsBackground = NO; cycleInfo.editable = NO;
    [card5 addSubview:cycleInfo];

    // --- Right Column Action Cards: Y = 310 to 480 ---
    // Card 6A: Apps Using Significant Energy (y: 430, h: 55)
    DarkCardView *card6A = [[DarkCardView alloc] initWithFrame:NSMakeRect(startX + (cardW + gap) * 2, 430, cardW, 55)];
    [self addSubview:card6A];
    [self createHeaderLabel:@"Apps Using Significant Energy" inView:card6A atX:12 atY:32];
    self.energyAppsLabel = [self createLabel:@"None (Normal Energy Consumption)" inView:card6A atX:12 atY:10 isSecondary:YES];

    // Card 6B: Calibration (y: 368, h: 54)
    DarkCardView *card6B = [[DarkCardView alloc] initWithFrame:NSMakeRect(startX + (cardW + gap) * 2, 368, cardW, 54)];
    [self addSubview:card6B];
    [self createHeaderLabel:@"Last Calibration: Recent" inView:card6B atX:12 atY:32];

    self.calibrationBtn = [[NSButton alloc] initWithFrame:NSMakeRect(10, 8, cardW - 20, 26)];
    self.calibrationBtn.bezelStyle = NSBezelStyleRoundRect;
    self.calibrationBtn.title = @"Recalibrate Battery";
    self.calibrationBtn.font = [NSFont boldSystemFontOfSize:11];
    self.calibrationBtn.target = self;
    self.calibrationBtn.action = @selector(onStartCalibrationClicked:);
    [card6B addSubview:self.calibrationBtn];

    // Card 6C: Manual Sleep Control (y: 308, h: 52)
    DarkCardView *card6C = [[DarkCardView alloc] initWithFrame:NSMakeRect(startX + (cardW + gap) * 2, 308, cardW, 52)];
    [self addSubview:card6C];

    NSTextField *sleepIcon = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 16, 100, 20)];
    sleepIcon.stringValue = @"Sleep Control";
    sleepIcon.font = [NSFont boldSystemFontOfSize:12];
    sleepIcon.textColor = [NSColor whiteColor];
    sleepIcon.bezeled = NO; sleepIcon.drawsBackground = NO; sleepIcon.editable = NO;
    [card6C addSubview:sleepIcon];

    self.sleepPreventBtn = [[NSButton alloc] initWithFrame:NSMakeRect(cardW - 85, 12, 75, 28)];
    self.sleepPreventBtn.bezelStyle = NSBezelStyleRoundRect;
    self.sleepPreventBtn.title = @"Prevent";
    self.sleepPreventBtn.font = [NSFont boldSystemFontOfSize:11];
    self.sleepPreventBtn.target = self;
    self.sleepPreventBtn.action = @selector(onSleepPreventClicked:);
    [card6C addSubview:self.sleepPreventBtn];

    // ==========================================
    // BOTTOM ROW: Y = 115, Height = 175
    // ==========================================
    CGFloat rowBotY = 115;
    CGFloat rowBotH = 175;

    // --- Card 7: Battery Temperature (Bottom Left) ---
    DarkCardView *card7 = [[DarkCardView alloc] initWithFrame:NSMakeRect(startX, rowBotY, cardW, rowBotH)];
    [self addSubview:card7];

    [self createHeaderLabel:@"Battery Temperature" inView:card7 atX:14 atY:148];

    self.tempValueLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 118, 140, 26)];
    self.tempValueLabel.stringValue = @"30.2 °C";
    self.tempValueLabel.font = [NSFont boldSystemFontOfSize:20];
    self.tempValueLabel.textColor = [NSColor whiteColor];
    self.tempValueLabel.bezeled = NO; self.tempValueLabel.drawsBackground = NO; self.tempValueLabel.editable = NO;
    [card7 addSubview:self.tempValueLabel];

    MiniWaveView *waveTemp = [[MiniWaveView alloc] initWithFrame:NSMakeRect(12, 12, cardW - 24, 100)];
    waveTemp.gradientStart = [NSColor colorWithCalibratedRed:0.2 green:0.6 blue:0.9 alpha:0.45];
    waveTemp.gradientEnd = [NSColor colorWithCalibratedRed:0.1 green:0.25 blue:0.5 alpha:0.05];
    [card7 addSubview:waveTemp];

    // --- Card 8: Power Consumption (Bottom Middle) ---
    DarkCardView *card8 = [[DarkCardView alloc] initWithFrame:NSMakeRect(startX + (cardW + gap), rowBotY, cardW, rowBotH)];
    [self addSubview:card8];

    [self createHeaderLabel:@"Power Consumption" inView:card8 atX:14 atY:148];
    [self createHeaderLabel:@"Time Remaining" inView:card8 atX:115 atY:148];

    self.powerWattsLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(14, 118, 90, 26)];
    self.powerWattsLabel.stringValue = @"30 W";
    self.powerWattsLabel.font = [NSFont boldSystemFontOfSize:20];
    self.powerWattsLabel.textColor = [NSColor whiteColor];
    self.powerWattsLabel.bezeled = NO; self.powerWattsLabel.drawsBackground = NO; self.powerWattsLabel.editable = NO;
    [card8 addSubview:self.powerWattsLabel];

    self.powerTimeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(115, 118, 105, 26)];
    self.powerTimeLabel.stringValue = @"15 m";
    self.powerTimeLabel.font = [NSFont boldSystemFontOfSize:12];
    self.powerTimeLabel.textColor = [NSColor secondaryLabelColor];
    self.powerTimeLabel.bezeled = NO; self.powerTimeLabel.drawsBackground = NO; self.powerTimeLabel.editable = NO;
    [card8 addSubview:self.powerTimeLabel];

    MiniWaveView *wavePower = [[MiniWaveView alloc] initWithFrame:NSMakeRect(12, 12, cardW - 24, 100)];
    wavePower.gradientStart = [NSColor colorWithCalibratedRed:0.5 green:0.3 blue:0.8 alpha:0.45];
    wavePower.gradientEnd = [NSColor colorWithCalibratedRed:0.2 green:0.1 blue:0.4 alpha:0.05];
    [card8 addSubview:wavePower];

}

// --- Helper UI Builders ---

- (NSTextField *)createHeader:(NSString *)title inView:(NSView *)view atY:(CGFloat)y {
    NSTextField *f = [[NSTextField alloc] initWithFrame:NSMakeRect(14, y, 140, 20)];
    f.stringValue = title;
    f.font = [NSFont boldSystemFontOfSize:13];
    f.textColor = [NSColor colorWithCalibratedWhite:0.95 alpha:1.0];
    f.bezeled = NO; f.drawsBackground = NO; f.editable = NO;
    [view addSubview:f];
    return f;
}

- (void)createBadge:(NSString *)text inView:(NSView *)view atX:(CGFloat)x atY:(CGFloat)y {
    NSTextField *b = [[NSTextField alloc] initWithFrame:NSMakeRect(x, y, 68, 16)];
    b.stringValue = text;
    b.font = [NSFont boldSystemFontOfSize:9];
    b.alignment = NSTextAlignmentCenter;
    b.textColor = [NSColor colorWithCalibratedRed:0.2 green:0.8 blue:0.4 alpha:1.0];
    b.bezeled = NO; b.drawsBackground = YES;
    b.backgroundColor = [NSColor colorWithCalibratedRed:0.1 green:0.5 blue:0.25 alpha:0.25];
    b.wantsLayer = YES; b.layer.cornerRadius = 4.0;
    b.editable = NO;
    [view addSubview:b];
}

- (NSTextField *)createHeaderLabel:(NSString *)text inView:(NSView *)view atX:(CGFloat)x atY:(CGFloat)y {
    NSTextField *f = [[NSTextField alloc] initWithFrame:NSMakeRect(x, y, 100, 16)];
    f.stringValue = text;
    f.font = [NSFont systemFontOfSize:10 weight:NSFontWeightMedium];
    f.textColor = [NSColor colorWithCalibratedWhite:0.65 alpha:1.0];
    f.bezeled = NO; f.drawsBackground = NO; f.editable = NO;
    [view addSubview:f];
    return f;
}

- (NSTextField *)createLabel:(NSString *)text inView:(NSView *)view atX:(CGFloat)x atY:(CGFloat)y isSecondary:(BOOL)sec {
    NSTextField *f = [[NSTextField alloc] initWithFrame:NSMakeRect(x, y, 202, 18)];
    f.stringValue = text;
    f.font = sec ? [NSFont systemFontOfSize:11] : [NSFont boldSystemFontOfSize:11];
    f.textColor = sec ? [NSColor colorWithCalibratedWhite:0.65 alpha:1.0] : [NSColor whiteColor];
    f.bezeled = NO; f.drawsBackground = NO; f.editable = NO;
    [view addSubview:f];
    return f;
}

- (NSTextField *)createRowWithTitle:(NSString *)title value:(NSString *)value inView:(NSView *)view atY:(CGFloat)y {
    NSTextField *t = [[NSTextField alloc] initWithFrame:NSMakeRect(14, y, 110, 18)];
    t.stringValue = title;
    t.font = [NSFont systemFontOfSize:11];
    t.textColor = [NSColor colorWithCalibratedWhite:0.65 alpha:1.0];
    t.bezeled = NO; t.drawsBackground = NO; t.editable = NO;
    [view addSubview:t];

    NSTextField *v = [[NSTextField alloc] initWithFrame:NSMakeRect(120, y, 98, 18)];
    v.stringValue = value;
    v.alignment = NSTextAlignmentRight;
    v.font = [NSFont boldSystemFontOfSize:11];
    v.textColor = [NSColor colorWithCalibratedWhite:0.95 alpha:1.0];
    v.bezeled = NO; v.drawsBackground = NO; v.editable = NO;
    [view addSubview:v];
    return v;
}

// --- Refresh Telemetry ---

- (void)refreshTelemetry {
    BatteryTelemetry tel = getBatteryTelemetry();
    VoltCraftConfig *cfg = getProConfig();

    // Top Card 1
    self.specNominalCap.stringValue = [NSString stringWithFormat:@"Nominal: %d mAh", (tel.designCapacity > 0 ? (int)(tel.designCapacity * 0.96) : 4398)];
    self.specVoltage.stringValue = [NSString stringWithFormat:@"Voltage: %.2f V", tel.voltageMv / 1000.0];

    // Top Card 2
    self.healthDesignCap.stringValue = [NSString stringWithFormat:@"%d mAh  100%%", tel.designCapacity];
    self.healthMaxCap.stringValue = [NSString stringWithFormat:@"%d mAh   %.0f%%", tel.rawMaxCapacity, tel.healthPercentage];
    self.healthCycles.stringValue = [NSString stringWithFormat:@"%d", tel.cycleCount];

    // Top Card 3
    if (tel.chargerWatts > 0) {
        self.adapterName.stringValue = [NSString stringWithUTF8String:tel.chargerName];
        self.adapterWatts.stringValue = [NSString stringWithFormat:@"Power Tier: %dW (PD 3.0)", tel.chargerWatts];
    } else {
        self.adapterName.stringValue = @"Disconnected";
        self.adapterWatts.stringValue = @"Running on Battery";
    }

    // Mid Card 4
    self.levelPercentage.stringValue = [NSString stringWithFormat:@"%d %%", tel.currentCapacity];
    if (tel.externalConnected) {
        if (tel.isCharging) {
            self.levelTime.stringValue = @"Charging";
            self.levelTime.textColor = [NSColor systemYellowColor];
        } else {
            self.levelTime.stringValue = [NSString stringWithFormat:@"Hold at %d%%", cfg->chargeLimit];
            self.levelTime.textColor = [NSColor systemGreenColor];
        }
    } else {
        self.levelTime.stringValue = @"On Battery";
        self.levelTime.textColor = [NSColor systemBlueColor];
    }

    // Mid Card 5
    self.cycleCountLabel.stringValue = [NSString stringWithFormat:@"%d Cycles", tel.cycleCount];

    // Bottom Card 7
    self.tempValueLabel.stringValue = [NSString stringWithFormat:@"%.1f °C", tel.temperatureC];

    // Bottom Card 8
    self.powerWattsLabel.stringValue = [NSString stringWithFormat:@"%d W", tel.chargerWatts];

    // Action Card Sleep Control
    if (cfg->sleepPrevented) {
        self.sleepPreventBtn.title = @"Allow";
        self.sleepPreventBtn.wantsLayer = YES;
        self.sleepPreventBtn.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.8 green:0.3 blue:0.2 alpha:1.0].CGColor;
    } else {
        self.sleepPreventBtn.title = @"Prevent";
        self.sleepPreventBtn.wantsLayer = YES;
        self.sleepPreventBtn.layer.backgroundColor = [NSColor colorWithCalibratedWhite:0.25 alpha:1.0].CGColor;
    }
}

- (void)onStartCalibrationClicked:(id)sender {
    VoltCraftConfig *cfg = getProConfig();
    if (cfg->calibrationPhase == CalibrationPhaseIdle) {
        startCalibration();
        self.calibrationBtn.title = @"Stop Calibration";
    } else {
        stopCalibration();
        self.calibrationBtn.title = @"Start Calibration";
    }
    [self refreshTelemetry];
}

- (void)onSleepPreventClicked:(id)sender {
    toggleSleepPrevent();
    [self refreshTelemetry];
}

@end
