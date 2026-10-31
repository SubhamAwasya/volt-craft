#import "menu_bar.h"
#import "battery_core.h"
#import "slider_popover.h"

// Retina-sharp vector battery icon reacting dynamically to all hardware conditions
static NSImage *createVoltCraftStatusIcon(int percentage, ChargeState state, BOOL externalConnected, BOOL isCharging) {
    NSSize size = NSMakeSize(29.0, 14.5);

    return [NSImage imageWithSize:size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        CGFloat bodyX = 0.5;
        CGFloat bodyY = 1.0;
        CGFloat bodyW = 23.0;
        CGFloat bodyH = 12.5;
        CGFloat cornerR = 3.4;

        NSRect bodyRect = NSMakeRect(bodyX, bodyY, bodyW, bodyH);
        NSBezierPath *body = [NSBezierPath bezierPathWithRoundedRect:bodyRect xRadius:cornerR yRadius:cornerR];

        // Terminal Cap on Right
        CGFloat capX = bodyX + bodyW + 0.6;
        CGFloat capY = bodyY + 3.4;
        CGFloat capW = 1.8;
        CGFloat capH = 5.7;
        NSRect capRect = NSMakeRect(capX, capY, capW, capH);
        NSBezierPath *cap = [NSBezierPath bezierPathWithRoundedRect:capRect xRadius:0.9 yRadius:0.9];

        // 1. Unfilled Background Shell
        NSColor *unfilledColor = [NSColor colorWithCalibratedWhite:0.35 alpha:0.55];
        [unfilledColor setFill];
        [body fill];
        [cap fill];

        // 2. Fill Level (Clipped to body)
        [NSGraphicsContext saveGraphicsState];
        [body addClip];

        CGFloat fillPct = MAX(0.06, MIN(percentage / 100.0, 1.0));
        CGFloat fillW = bodyW * fillPct;
        NSRect fillRect = NSMakeRect(bodyX, bodyY, fillW, bodyH);

        // Determine Pill Fill Color & Text Color based on live charge state
        NSColor *fillColor = [NSColor colorWithCalibratedWhite:0.94 alpha:1.0];
        NSColor *textColor = [NSColor colorWithCalibratedWhite:0.12 alpha:1.0];

        if (state == ChargeStateNormalCharging || state == ChargeStateTopUp) {
            // Charging: Vibrant Apple Green
            fillColor = [NSColor colorWithCalibratedRed:0.20 green:0.80 blue:0.38 alpha:1.0];
            textColor = [NSColor colorWithCalibratedWhite:0.06 alpha:1.0];
        } else if (state == ChargeStateDischarging) {
            // Forced Discharge: Active Alert Amber/Orange
            fillColor = [NSColor colorWithCalibratedRed:1.0 green:0.62 blue:0.12 alpha:1.0];
            textColor = [NSColor colorWithCalibratedWhite:0.06 alpha:1.0];
        } else if (state == ChargeStateHeatPaused) {
            // Thermal Guard: Red Warning
            fillColor = [NSColor colorWithCalibratedRed:1.0 green:0.32 blue:0.25 alpha:1.0];
            textColor = [NSColor whiteColor];
        } else if (state == ChargeStateSailing) {
            // Sailing Mode: Sea Cyan
            fillColor = [NSColor colorWithCalibratedRed:0.22 green:0.75 blue:0.95 alpha:1.0];
            textColor = [NSColor colorWithCalibratedWhite:0.06 alpha:1.0];
        } else if (!externalConnected && percentage <= 20) {
            // Low Battery on Unplugged: Warning Red
            fillColor = [NSColor colorWithCalibratedRed:1.0 green:0.25 blue:0.25 alpha:1.0];
            textColor = [NSColor whiteColor];
        } else {
            // Holding at limit on AC, or on battery > 20%: Clean crisp white/silver
            fillColor = [NSColor colorWithCalibratedWhite:0.94 alpha:1.0];
            textColor = [NSColor colorWithCalibratedWhite:0.12 alpha:1.0];
        }

        [fillColor setFill];
        NSRectFill(fillRect);

        // 3. Text and Glyphs inside the battery (prominent, legible font size)
        NSString *pctStr = [NSString stringWithFormat:@"%d", percentage];
        CGFloat fontSize = (percentage >= 100) ? 8.2 : 9.8;
        NSFont *font = [NSFont systemFontOfSize:fontSize weight:NSFontWeightBold];
        NSDictionary *attrs = @{
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: textColor
        };
        NSSize textSize = [pctStr sizeWithAttributes:attrs];

        if (externalConnected) {
            if (state == ChargeStateDischarging) {
                // --- STATE A: FORCED DISCHARGE ON AC (Down Arrow) ---
                CGFloat arrW = 4.0;
                CGFloat arrH = 7.4;
                CGFloat spacing = 0.8;
                CGFloat totalW = textSize.width + spacing + arrW;
                CGFloat startX = bodyX + (bodyW - totalW) / 2.0;
                CGFloat textY = bodyY + (bodyH - textSize.height) / 2.0 - 0.2;

                [pctStr drawAtPoint:NSMakePoint(startX, textY) withAttributes:attrs];

                CGFloat ax = startX + textSize.width + spacing;
                CGFloat ay = bodyY + (bodyH - arrH) / 2.0;

                NSBezierPath *arr = [NSBezierPath bezierPath];
                [arr moveToPoint:NSMakePoint(ax + arrW / 2.0, ay + arrH)];
                [arr lineToPoint:NSMakePoint(ax + arrW / 2.0, ay + 0.5)];
                [arr moveToPoint:NSMakePoint(ax + 0.2, ay + 3.2)];
                [arr lineToPoint:NSMakePoint(ax + arrW / 2.0, ay + 0.5)];
                [arr lineToPoint:NSMakePoint(ax + arrW - 0.2, ay + 3.2)];
                [arr setLineWidth:1.2];
                [textColor setStroke];
                [arr stroke];

            } else if (state == ChargeStateNormalCharging || state == ChargeStateTopUp || (isCharging && state != ChargeStateHoldingLimit)) {
                // --- STATE B: CHARGING (Sharp Lightning Bolt) ---
                CGFloat boltW = 4.2;
                CGFloat boltH = 8.6;
                CGFloat spacing = 0.8;
                CGFloat totalW = textSize.width + spacing + boltW;
                CGFloat startX = bodyX + (bodyW - totalW) / 2.0;
                CGFloat textY = bodyY + (bodyH - textSize.height) / 2.0 - 0.2;

                [pctStr drawAtPoint:NSMakePoint(startX, textY) withAttributes:attrs];

                CGFloat bx = startX + textSize.width + spacing;
                CGFloat by = bodyY + (bodyH - boltH) / 2.0;

                NSBezierPath *bolt = [NSBezierPath bezierPath];
                [bolt moveToPoint:NSMakePoint(bx + 2.5, by + boltH)];
                [bolt lineToPoint:NSMakePoint(bx + 0.2, by + 3.8)];
                [bolt lineToPoint:NSMakePoint(bx + 2.2, by + 3.8)];
                [bolt lineToPoint:NSMakePoint(bx + 1.7, by + 0.0)];
                [bolt lineToPoint:NSMakePoint(bx + 4.2, by + 4.8)];
                [bolt lineToPoint:NSMakePoint(bx + 2.2, by + 4.8)];
                [bolt closePath];
                [textColor setFill];
                [bolt fill];

            } else if (state == ChargeStateHeatPaused) {
                // --- STATE C: HEAT PAUSED (Pause Bars) ---
                CGFloat barW = 1.4;
                CGFloat barH = 6.0;
                CGFloat spacing = 1.0;
                CGFloat totalW = textSize.width + spacing + (barW * 2 + 1.2);
                CGFloat startX = bodyX + (bodyW - totalW) / 2.0;
                CGFloat textY = bodyY + (bodyH - textSize.height) / 2.0 - 0.2;

                [pctStr drawAtPoint:NSMakePoint(startX, textY) withAttributes:attrs];

                CGFloat px = startX + textSize.width + spacing;
                CGFloat py = bodyY + (bodyH - barH) / 2.0;

                [textColor setFill];
                NSRectFill(NSMakeRect(px, py, barW, barH));
                NSRectFill(NSMakeRect(px + barW + 1.2, py, barW, barH));

            } else if (state == ChargeStateSailing) {
                // --- STATE D: SAILING MODE (Gentle Wave) ---
                CGFloat waveW = 4.8;
                CGFloat waveH = 3.0;
                CGFloat spacing = 0.8;
                CGFloat totalW = textSize.width + spacing + waveW;
                CGFloat startX = bodyX + (bodyW - totalW) / 2.0;
                CGFloat textY = bodyY + (bodyH - textSize.height) / 2.0 - 0.2;

                [pctStr drawAtPoint:NSMakePoint(startX, textY) withAttributes:attrs];

                CGFloat wx = startX + textSize.width + spacing;
                CGFloat wy = bodyY + (bodyH - waveH) / 2.0;

                NSBezierPath *wave = [NSBezierPath bezierPath];
                [wave moveToPoint:NSMakePoint(wx, wy + 1.5)];
                [wave curveToPoint:NSMakePoint(wx + 2.4, wy + 1.5) controlPoint1:NSMakePoint(wx + 0.8, wy + 3.2) controlPoint2:NSMakePoint(wx + 1.6, wy + 3.2)];
                [wave curveToPoint:NSMakePoint(wx + 4.8, wy + 1.5) controlPoint1:NSMakePoint(wx + 3.2, wy - 0.2) controlPoint2:NSMakePoint(wx + 4.0, wy - 0.2)];
                [wave setLineWidth:1.2];
                [textColor setStroke];
                [wave stroke];

            } else {
                // --- STATE E: HOLDING LIMIT / ON CHARGER NOT CHARGING (Power Plug) ---
                CGFloat plugW = 4.8;
                CGFloat plugH = 5.8;
                CGFloat spacing = 0.8;
                CGFloat totalW = textSize.width + spacing + plugW;
                CGFloat startX = bodyX + (bodyW - totalW) / 2.0;
                CGFloat textY = bodyY + (bodyH - textSize.height) / 2.0 - 0.2;

                [pctStr drawAtPoint:NSMakePoint(startX, textY) withAttributes:attrs];

                CGFloat px = startX + textSize.width + spacing;
                CGFloat py = bodyY + (bodyH - plugH) / 2.0;

                // Plug body
                NSRect pBody = NSMakeRect(px, py + 1.2, 3.0, 3.4);
                NSBezierPath *pPath = [NSBezierPath bezierPathWithRoundedRect:pBody xRadius:0.6 yRadius:0.6];
                [textColor setFill];
                [pPath fill];

                // Prongs on right
                NSRect prong1 = NSMakeRect(px + 3.0, py + 3.3, 1.8, 0.9);
                NSRect prong2 = NSMakeRect(px + 3.0, py + 1.6, 1.8, 0.9);
                NSRectFill(prong1);
                NSRectFill(prong2);
            }
        } else {
            // --- STATE F: ON BATTERY (UNPLUGGED) -> Clean Centered Percentage ---
            CGFloat textX = bodyX + (bodyW - textSize.width) / 2.0;
            CGFloat textY = bodyY + (bodyH - textSize.height) / 2.0 - 0.2;
            [pctStr drawAtPoint:NSMakePoint(textX, textY) withAttributes:attrs];
        }

        [NSGraphicsContext restoreGraphicsState];

        // 4. Subtle Outer Rim Stroke (0.6pt for crisp edge against any desktop)
        [[NSColor colorWithCalibratedWhite:0.6 alpha:0.35] setStroke];
        [body setLineWidth:0.6];
        [body stroke];
        [cap setLineWidth:0.6];
        [cap stroke];

        return YES;
    }];
}

@implementation VoltCraftAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    loadProConfig();

    self.mainController = [MainWindowController sharedController];

    // Status Item in Menu Bar
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    NSStatusBarButton *button = self.statusItem.button;
    if (button) {
        button.target = self;
        button.action = @selector(onStatusItemClicked:);
        [button sendActionOn:NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp];
    }

    // Slider Popover
    self.popoverVC = [[SliderPopoverViewController alloc] init];
    self.popoverVC.delegate = self;

    self.popover = [[NSPopover alloc] init];
    self.popover.contentViewController = self.popoverVC;
    self.popover.behavior = NSPopoverBehaviorTransient;
    self.popover.animates = YES;

    [self updateStatus];

    // Background engine cycle timer every 2 seconds
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                         target:self
                                                       selector:@selector(onTimerTick)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)onTimerTick {
    runEngineCycle();
    [self updateStatus];
    if (self.popover.isShown) {
        [self.popoverVC refreshUI];
    }
}

- (void)updateStatus {
    BatteryTelemetry tel = getBatteryTelemetry();
    ChargeState state = getOverallChargeState();

    NSStatusBarButton *button = self.statusItem.button;
    if (button) {
        button.image = createVoltCraftStatusIcon(tel.currentCapacity, state, tel.externalConnected, tel.isCharging);
        button.imagePosition = NSImageOnly;
        button.title = @"";
    }
}

- (void)onStatusItemClicked:(id)sender {
    NSEvent *event = [NSApp currentEvent];
    if (event.type == NSEventTypeRightMouseUp) {
        [self showContextMenu];
    } else {
        [self togglePopover:sender];
    }
}

- (void)togglePopover:(id)sender {
    if (self.popover.isShown) {
        [self.popover performClose:sender];
    } else {
        [self.popoverVC refreshUI];
        NSStatusBarButton *btn = self.statusItem.button;
        if (btn) {
            [self.popover showRelativeToRect:btn.bounds ofView:btn preferredEdge:NSRectEdgeMinY];
            [self.popover.contentViewController.view.window makeKeyWindow];
        }
    }
}

#pragma mark - SliderPopoverDelegate

- (void)popoverDidRequestOpenSettings {
    [self.popover performClose:nil];
    [self.mainController showDashboard];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)popoverDidRequestQuit {
    [NSApp terminate:nil];
}

- (void)popoverDidChangeChargeLimit {
    [self updateStatus];
}

#pragma mark - Right Click Menu

- (void)showContextMenu {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"VoltCraft Quick Menu"];

    VoltCraftConfig *cfg = getProConfig();
    BatteryTelemetry tel = getBatteryTelemetry();

    NSMenuItem *header = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"VoltCraft Pro — %d%% (%@)",
                                                           tel.currentCapacity, getChargeStateDescription(getOverallChargeState())]
                                                    action:nil keyEquivalent:@""];
    header.enabled = NO;
    [menu addItem:header];
    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *dashItem = [[NSMenuItem alloc] initWithTitle:@"Open Dashboard & Settings..." action:@selector(onOpenDashboard) keyEquivalent:@"s"];
    dashItem.target = self;
    [menu addItem:dashItem];

    NSMenuItem *topUpItem = [[NSMenuItem alloc] initWithTitle:@"Top Up to 100%" action:@selector(onQuickTopUp) keyEquivalent:@"t"];
    topUpItem.target = self;
    if (cfg->isTopUpActive) topUpItem.state = NSControlStateValueOn;
    [menu addItem:topUpItem];

    NSMenuItem *disItem = [[NSMenuItem alloc] initWithTitle:@"Discharge Battery" action:@selector(onQuickDischarge) keyEquivalent:@"d"];
    disItem.target = self;
    if (cfg->isDischarging) disItem.state = NSControlStateValueOn;
    [menu addItem:disItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit VoltCraft" action:@selector(onQuickQuit) keyEquivalent:@"q"];
    quitItem.target = self;
    [menu addItem:quitItem];

    [menu popUpMenuPositioningItem:nil atLocation:NSEvent.mouseLocation inView:nil];
}

- (void)onOpenDashboard {
    [self.mainController showDashboard];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)onQuickTopUp {
    toggleTopUp();
    [self updateStatus];
}

- (void)onQuickDischarge {
    toggleDischarge();
    [self updateStatus];
}

- (void)onQuickQuit {
    [NSApp terminate:nil];
}

@end
