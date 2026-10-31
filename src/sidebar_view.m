#import "sidebar_view.h"

@interface SidebarItemButton : NSButton
@property (nonatomic, assign) SidebarSection section;
@property (nonatomic, assign) BOOL isItemSelected;
@property (nonatomic, strong) NSImage *systemIcon;
@property (nonatomic, copy) NSString *itemTitle;
@end

@implementation SidebarItemButton

- (void)drawRect:(NSRect)dirtyRect {
    NSRect b = self.bounds;

    if (self.isItemSelected) {
        NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(b, 4, 1) xRadius:7.0 yRadius:7.0];
        [[NSColor colorWithCalibratedRed:0.12 green:0.22 blue:0.36 alpha:1.0] setFill];
        [p fill];
    }

    // SF Symbol Icon
    if (self.systemIcon) {
        NSColor *tintColor = self.isItemSelected ? [NSColor colorWithCalibratedRed:0.28 green:0.68 blue:1.0 alpha:1.0] : [NSColor colorWithCalibratedWhite:0.62 alpha:1.0];
        NSImageSymbolConfiguration *sizeCfg = [NSImageSymbolConfiguration configurationWithPointSize:13 weight:NSFontWeightMedium];
        NSImageSymbolConfiguration *colCfg = [NSImageSymbolConfiguration configurationWithHierarchicalColor:tintColor];
        NSImageSymbolConfiguration *combined = [sizeCfg configurationByApplyingConfiguration:colCfg];
        NSImage *icon = [self.systemIcon imageWithSymbolConfiguration:combined];
        if (icon) {
            NSRect iconRect = NSMakeRect(16, (b.size.height - 16) / 2, 16, 16);
            [icon drawInRect:iconRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
        }
    }

    // Title
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = NSTextAlignmentLeft;

    NSDictionary *titleAttrs = @{
        NSFontAttributeName: self.isItemSelected ? [NSFont boldSystemFontOfSize:13] : [NSFont systemFontOfSize:13],
        NSForegroundColorAttributeName: self.isItemSelected ? [NSColor colorWithCalibratedRed:0.35 green:0.72 blue:1.0 alpha:1.0] : [NSColor colorWithCalibratedWhite:0.85 alpha:1.0],
        NSParagraphStyleAttributeName: style
    };
    [self.itemTitle drawInRect:NSMakeRect(42, (b.size.height - 17) / 2, b.size.width - 50, 18) withAttributes:titleAttrs];
}

@end

@interface SidebarView ()
@property (nonatomic, strong) NSMutableArray<SidebarItemButton *> *buttons;
@end

@implementation SidebarView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.08 green:0.085 blue:0.095 alpha:1.0].CGColor;
        self.buttons = [NSMutableArray array];
        self.selectedSection = SidebarSectionDashboard;
        [self setupSidebarUI];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];

    // Right border separator
    NSRect r = self.bounds;
    [[NSColor colorWithCalibratedRed:0.15 green:0.16 blue:0.18 alpha:1.0] setStroke];
    [NSBezierPath strokeLineFromPoint:NSMakePoint(r.size.width - 0.5, 0)
                              toPoint:NSMakePoint(r.size.width - 0.5, r.size.height)];
}

- (void)setupSidebarUI {
    CGFloat y = 605;

    // --- 1. Dashboard Item ---
    [self addSidebarItem:@"Dashboard" symbol:@"square.grid.2x2" section:SidebarSectionDashboard atY:y];
    y -= 52;

    // --- 2. Battery Care Section ---
    [self addSectionHeader:@"Battery Care" atY:y];
    y -= 26;
    [self addSidebarItem:@"Charge Control" symbol:@"battery.100" section:SidebarSectionChargeControl atY:y];
    y -= 34;
    [self addSidebarItem:@"Sleep Behavior" symbol:@"moon.fill" section:SidebarSectionSleepBehavior atY:y];
    y -= 34;
    [self addSidebarItem:@"Energy Use" symbol:@"bolt.fill" section:SidebarSectionEnergyUse atY:y];
    y -= 48;

    // --- 3. Automations Section ---
    [self addSectionHeader:@"Automations" atY:y];
    y -= 26;
    [self addSidebarItem:@"Schedule" symbol:@"calendar" section:SidebarSectionSchedule atY:y];
    y -= 34;
    [self addSidebarItem:@"Shortcuts" symbol:@"command" section:SidebarSectionShortcuts atY:y];
    y -= 48;

    // --- 4. Appearance Section ---
    [self addSectionHeader:@"Appearance" atY:y];
    y -= 26;
    [self addSidebarItem:@"Popover" symbol:@"rectangle.topthird.inset.filled" section:SidebarSectionPopover atY:y];
    y -= 34;
    [self addSidebarItem:@"Menu Bar" symbol:@"menubar.dock.rectangle" section:SidebarSectionMenuBar atY:y];
    y -= 34;
    [self addSidebarItem:@"Other" symbol:@"gearshape" section:SidebarSectionOther atY:y];

    // --- Bottom Section: Utility Buttons (Power, Help, Settings) ---
    NSButton *powerBtn = [self createCircleButtonWithSymbol:@"power" action:@selector(onPowerClicked:) atX:16 atY:18];
    powerBtn.toolTip = @"Quit VoltCraft";
    [self addSubview:powerBtn];

    NSButton *helpBtn = [self createCircleButtonWithSymbol:@"questionmark" action:@selector(onHelpClicked:) atX:120 atY:18];
    helpBtn.toolTip = @"Help & Hardware Info";
    [self addSubview:helpBtn];

    NSButton *gearBtn = [self createCircleButtonWithSymbol:@"gearshape" action:@selector(onGearClicked:) atX:165 atY:18];
    gearBtn.toolTip = @"Settings";
    [self addSubview:gearBtn];

    [self updateSelection];
}

- (void)addSectionHeader:(NSString *)title atY:(CGFloat)y {
    NSTextField *lbl = [[NSTextField alloc] initWithFrame:NSMakeRect(16, y, 180, 16)];
    lbl.stringValue = title;
    lbl.font = [NSFont boldSystemFontOfSize:11];
    lbl.textColor = [NSColor colorWithCalibratedWhite:0.45 alpha:1.0];
    lbl.bezeled = NO; lbl.drawsBackground = NO; lbl.editable = NO;
    [self addSubview:lbl];
}

- (void)addSidebarItem:(NSString *)title symbol:(NSString *)symbol section:(SidebarSection)sec atY:(CGFloat)y {
    SidebarItemButton *btn = [[SidebarItemButton alloc] initWithFrame:NSMakeRect(10, y, 190, 32)];
    btn.section = sec;
    btn.itemTitle = title;
    btn.systemIcon = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
    btn.target = self;
    btn.action = @selector(onItemClicked:);
    [self.buttons addObject:btn];
    [self addSubview:btn];
}

- (NSButton *)createCircleButtonWithSymbol:(NSString *)symbol action:(SEL)action atX:(CGFloat)x atY:(CGFloat)y {
    NSButton *b = [[NSButton alloc] initWithFrame:NSMakeRect(x, y, 28, 28)];
    b.bezelStyle = NSBezelStyleCircular;
    b.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
    b.imagePosition = NSImageOnly;
    b.target = self;
    b.action = action;
    return b;
}

- (void)onItemClicked:(SidebarItemButton *)sender {
    [self selectSection:sender.section];
    if ([self.delegate respondsToSelector:@selector(sidebarDidSelectSection:)]) {
        [self.delegate sidebarDidSelectSection:sender.section];
    }
}

- (void)selectSection:(SidebarSection)section {
    self.selectedSection = section;
    [self updateSelection];
}

- (void)updateSelection {
    for (SidebarItemButton *b in self.buttons) {
        b.isItemSelected = (b.section == self.selectedSection);
        [b setNeedsDisplay:YES];
    }
}

- (void)onPowerClicked:(id)sender {
    if ([self.delegate respondsToSelector:@selector(sidebarDidClickPower)]) {
        [self.delegate sidebarDidClickPower];
    } else {
        [NSApp terminate:nil];
    }
}

- (void)onHelpClicked:(id)sender {
    if ([self.delegate respondsToSelector:@selector(sidebarDidClickHelp)]) {
        [self.delegate sidebarDidClickHelp];
    }
}

- (void)onGearClicked:(id)sender {
    if ([self.delegate respondsToSelector:@selector(sidebarDidClickSettings)]) {
        [self.delegate sidebarDidClickSettings];
    }
}

@end
