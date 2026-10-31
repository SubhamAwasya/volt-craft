#import "menu_bar.h"
#import "battery_core.h"
#import "slider_popover.h"

// Retina-sharp vector battery icon reacting dynamically to all hardware conditions
static void drawStatusContent(NSString *pctStr, NSDictionary *attrs, NSRect bodyRect, ChargeState state, BOOL externalConnected, BOOL isCharging, NSColor *glyphColor, BOOL showGlyphs) {
    BOOL hasText = (pctStr.length > 0);
    NSSize textSize = hasText ? [pctStr sizeWithAttributes:attrs] : NSZeroSize;
    CGFloat bodyX = bodyRect.origin.x;
    CGFloat bodyY = bodyRect.origin.y;
    CGFloat bodyW = bodyRect.size.width;
    CGFloat bodyH = bodyRect.size.height;

    if (!hasText && !showGlyphs) return;

    if (externalConnected && showGlyphs) {
        if (state == ChargeStateDischarging) {
            // --- STATE A: FORCED DISCHARGE ON AC (Down Arrow) ---
            CGFloat arrW = 4.2;
            CGFloat arrH = 7.6;
            CGFloat spacing = hasText ? 1.0 : 0.0;
            CGFloat totalContentW = textSize.width + spacing + arrW;
            CGFloat startX = bodyX + (bodyW - totalContentW) / 2.0;

            if (hasText) {
                CGFloat textY = bodyY + (bodyH - textSize.height) / 2.0 - 0.2;
                [pctStr drawAtPoint:NSMakePoint(startX, textY) withAttributes:attrs];
            }

            CGFloat ax = hasText ? (startX + textSize.width + spacing) : (bodyX + (bodyW - arrW) / 2.0);
            CGFloat ay = bodyY + (bodyH - arrH) / 2.0;

            NSBezierPath *arr = [NSBezierPath bezierPath];
            [arr moveToPoint:NSMakePoint(ax + arrW / 2.0, ay + arrH)];
            [arr lineToPoint:NSMakePoint(ax + arrW / 2.0, ay + 0.5)];
            [arr moveToPoint:NSMakePoint(ax + 0.2, ay + 3.2)];
            [arr lineToPoint:NSMakePoint(ax + arrW / 2.0, ay + 0.5)];
            [arr lineToPoint:NSMakePoint(ax + arrW - 0.2, ay + 3.2)];
            [arr setLineWidth:1.2];
            [glyphColor setStroke];
            [arr stroke];

        } else if (state == ChargeStateNormalCharging || state == ChargeStateTopUp || (isCharging && state != ChargeStateHoldingLimit)) {
            // --- STATE B: CHARGING (Sharp Lightning Bolt) ---
            CGFloat boltW = 4.4;
            CGFloat boltH = 8.8;
            CGFloat spacing = hasText ? 1.0 : 0.0;
            CGFloat totalContentW = textSize.width + spacing + boltW;
            CGFloat startX = bodyX + (bodyW - totalContentW) / 2.0;

            if (hasText) {
                CGFloat textY = bodyY + (bodyH - textSize.height) / 2.0 - 0.2;
                [pctStr drawAtPoint:NSMakePoint(startX, textY) withAttributes:attrs];
            }

            CGFloat bx = hasText ? (startX + textSize.width + spacing) : (bodyX + (bodyW - boltW) / 2.0);
            CGFloat by = bodyY + (bodyH - boltH) / 2.0;

            NSBezierPath *bolt = [NSBezierPath bezierPath];
            [bolt moveToPoint:NSMakePoint(bx + 2.7, by + boltH)];
            [bolt lineToPoint:NSMakePoint(bx + 0.2, by + 4.0)];
            [bolt lineToPoint:NSMakePoint(bx + 2.3, by + 4.0)];
            [bolt lineToPoint:NSMakePoint(bx + 1.8, by + 0.0)];
            [bolt lineToPoint:NSMakePoint(bx + 4.4, by + 5.0)];
            [bolt lineToPoint:NSMakePoint(bx + 2.3, by + 5.0)];
            [bolt closePath];
            [glyphColor setFill];
            [bolt fill];

        } else if (state == ChargeStateHeatPaused) {
            // --- STATE C: HEAT PAUSED (Pause Bars) ---
            CGFloat barW = 1.4;
            CGFloat barH = 6.2;
            CGFloat spacing = hasText ? 1.0 : 0.0;
            CGFloat totalContentW = textSize.width + spacing + (barW * 2 + 1.2);
            CGFloat startX = bodyX + (bodyW - totalContentW) / 2.0;

            if (hasText) {
                CGFloat textY = bodyY + (bodyH - textSize.height) / 2.0 - 0.2;
                [pctStr drawAtPoint:NSMakePoint(startX, textY) withAttributes:attrs];
            }

            CGFloat px = hasText ? (startX + textSize.width + spacing) : (bodyX + (bodyW - (barW * 2 + 1.2)) / 2.0);
            CGFloat py = bodyY + (bodyH - barH) / 2.0;

            [glyphColor setFill];
            NSRectFill(NSMakeRect(px, py, barW, barH));
            NSRectFill(NSMakeRect(px + barW + 1.2, py, barW, barH));

        } else if (state == ChargeStateSailing) {
            // --- STATE D: SAILING MODE (Gentle Wave) ---
            CGFloat waveW = 5.0;
            CGFloat waveH = 3.2;
            CGFloat spacing = hasText ? 1.0 : 0.0;
            CGFloat totalContentW = textSize.width + spacing + waveW;
            CGFloat startX = bodyX + (bodyW - totalContentW) / 2.0;

            if (hasText) {
                CGFloat textY = bodyY + (bodyH - textSize.height) / 2.0 - 0.2;
                [pctStr drawAtPoint:NSMakePoint(startX, textY) withAttributes:attrs];
            }

            CGFloat wx = hasText ? (startX + textSize.width + spacing) : (bodyX + (bodyW - waveW) / 2.0);
            CGFloat wy = bodyY + (bodyH - waveH) / 2.0;

            NSBezierPath *wave = [NSBezierPath bezierPath];
            [wave moveToPoint:NSMakePoint(wx, wy + 1.6)];
            [wave curveToPoint:NSMakePoint(wx + 2.5, wy + 1.6) controlPoint1:NSMakePoint(wx + 0.8, wy + 3.4) controlPoint2:NSMakePoint(wx + 1.7, wy + 3.4)];
            [wave curveToPoint:NSMakePoint(wx + 5.0, wy + 1.6) controlPoint1:NSMakePoint(wx + 3.3, wy - 0.2) controlPoint2:NSMakePoint(wx + 4.2, wy - 0.2)];
            [wave setLineWidth:1.2];
            [glyphColor setStroke];
            [wave stroke];

        } else {
            // --- STATE E: HOLDING LIMIT / ON CHARGER NOT CHARGING (Power Plug) ---
            CGFloat plugBodyW = 4.2;
            CGFloat plugBodyH = 7.2;
            CGFloat prongL = 2.2;
            CGFloat prongH = 1.3;
            CGFloat prongGap = 1.8;
            CGFloat collarW = 0.8;

            CGFloat totalPlugW = collarW + plugBodyW + prongL;
            CGFloat spacing = hasText ? 1.0 : 0.0;
            CGFloat totalContentW = textSize.width + spacing + totalPlugW;
            CGFloat startX = bodyX + (bodyW - totalContentW) / 2.0;

            if (hasText) {
                CGFloat textY = bodyY + (bodyH - textSize.height) / 2.0 - 0.2;
                [pctStr drawAtPoint:NSMakePoint(startX, textY) withAttributes:attrs];
            }

            CGFloat px = hasText ? (startX + textSize.width + spacing + collarW) : (bodyX + (bodyW - totalPlugW) / 2.0 + collarW);
            CGFloat py = bodyY + (bodyH - plugBodyH) / 2.0;

            // Plug main body
            NSRect pBody = NSMakeRect(px, py, plugBodyW, plugBodyH);
            NSBezierPath *pPath = [NSBezierPath bezierPathWithRoundedRect:pBody xRadius:1.0 yRadius:1.0];
            [glyphColor setFill];
            [pPath fill];

            // Cord relief collar on left
            CGFloat collarH = plugBodyH * 0.5;
            NSRect collarRect = NSMakeRect(px - collarW, py + (plugBodyH - collarH) / 2.0, collarW, collarH);
            NSBezierPath *cPath = [NSBezierPath bezierPathWithRoundedRect:collarRect xRadius:0.4 yRadius:0.4];
            [cPath fill];

            // Top & bottom prongs on right
            CGFloat p1Y = py + (plugBodyH + prongGap) / 2.0;
            CGFloat p2Y = py + (plugBodyH - prongGap) / 2.0 - prongH;
            NSRect prong1 = NSMakeRect(px + plugBodyW, p1Y, prongL, prongH);
            NSRect prong2 = NSMakeRect(px + plugBodyW, p2Y, prongL, prongH);
            NSBezierPath *pr1 = [NSBezierPath bezierPathWithRoundedRect:prong1 xRadius:0.4 yRadius:0.4];
            NSBezierPath *pr2 = [NSBezierPath bezierPathWithRoundedRect:prong2 xRadius:0.4 yRadius:0.4];
            [pr1 fill];
            [pr2 fill];
        }
    } else if (hasText) {
        // Centered Percentage (Unplugged or Glyphs disabled)
        CGFloat textX = bodyX + (bodyW - textSize.width) / 2.0;
        CGFloat textY = bodyY + (bodyH - textSize.height) / 2.0 - 0.2;
        [pctStr drawAtPoint:NSMakePoint(textX, textY) withAttributes:attrs];
    }
}

NSImage *createVoltCraftStatusIcon(int percentage, ChargeState state, BOOL externalConnected, BOOL isCharging) {
    VoltCraftConfig *cfg = getProConfig();
    CGFloat totalW = (cfg->iconWidth >= 26 && cfg->iconWidth <= 46) ? (CGFloat)cfg->iconWidth : 36.0;
    CGFloat totalH = 15.5;
    NSSize size = NSMakeSize(totalW, totalH);

    NSImage *icon = [NSImage imageWithSize:size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
        CGFloat strokeW = 1.15;
        CGFloat capW = 2.0;
        CGFloat capH = 5.6;
        CGFloat capGap = 1.0;

        CGFloat bodyX = 1.0;
        CGFloat bodyY = 1.25;
        CGFloat bodyH = 13.0;
        CGFloat bodyW = totalW - bodyX - capW - capGap - 1.0;
        CGFloat cornerR = 3.6;

        NSRect bodyRect = NSMakeRect(bodyX, bodyY, bodyW, bodyH);
        NSBezierPath *body = [NSBezierPath bezierPathWithRoundedRect:bodyRect xRadius:cornerR yRadius:cornerR];

        // Terminal Cap on Right
        CGFloat capX = bodyX + bodyW + capGap;
        CGFloat capY = bodyY + (bodyH - capH) / 2.0;
        NSRect capRect = NSMakeRect(capX, capY, capW, capH);
        NSBezierPath *cap = [NSBezierPath bezierPathWithRoundedRect:capRect xRadius:1.0 yRadius:1.0];

        // Appearance Check
        BOOL isDark = YES;
        if (@available(macOS 10.14, *)) {
            NSAppearanceName bestMatch = [[NSApp effectiveAppearance] bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
            isDark = [bestMatch isEqualToString:NSAppearanceNameDarkAqua];
        }

        // 1. Unfilled Background Shell
        NSColor *shellBgColor;
        if (cfg->iconHighContrastBorder) {
            shellBgColor = isDark ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.18]
                                  : [NSColor colorWithCalibratedWhite:0.0 alpha:0.12];
        } else {
            shellBgColor = isDark ? [NSColor colorWithCalibratedWhite:0.35 alpha:0.30]
                                  : [NSColor colorWithCalibratedWhite:0.0 alpha:0.08];
        }
        [shellBgColor setFill];
        [body fill];

        // 2. Determine Fill Color & Over-fill text color
        NSColor *fillColor = [NSColor colorWithCalibratedWhite:0.95 alpha:1.0];
        BOOL isFillDark = NO;

        if (cfg->iconColorMode == 1) {
            // Monochrome Mode: Pure crisp white / silver
            fillColor = isDark ? [NSColor colorWithCalibratedWhite:0.95 alpha:1.0]
                               : [NSColor colorWithCalibratedWhite:0.25 alpha:1.0];
            isFillDark = !isDark;
        } else {
            // Dynamic State Colors
            if (state == ChargeStateNormalCharging || state == ChargeStateTopUp) {
                // Charging: Vibrant Apple Green
                fillColor = [NSColor colorWithCalibratedRed:0.20 green:0.82 blue:0.40 alpha:1.0];
            } else if (state == ChargeStateDischarging) {
                // Forced Discharge: Active Alert Amber/Orange
                fillColor = [NSColor colorWithCalibratedRed:1.0 green:0.62 blue:0.12 alpha:1.0];
            } else if (state == ChargeStateHeatPaused) {
                // Thermal Guard: Red Warning
                fillColor = [NSColor colorWithCalibratedRed:1.0 green:0.30 blue:0.25 alpha:1.0];
                isFillDark = YES; // White text over red
            } else if (state == ChargeStateSailing) {
                // Sailing Mode: Sea Cyan
                fillColor = [NSColor colorWithCalibratedRed:0.22 green:0.75 blue:0.95 alpha:1.0];
            } else if (!externalConnected && percentage <= 20) {
                // Low Battery on Unplugged: Warning Red
                fillColor = [NSColor colorWithCalibratedRed:1.0 green:0.25 blue:0.25 alpha:1.0];
                isFillDark = YES; // White text over red
            } else {
                // Holding at limit on AC, or on battery > 20%: Clean crisp white/silver
                if (isDark) {
                    fillColor = [NSColor colorWithCalibratedWhite:0.95 alpha:1.0];
                } else {
                    fillColor = [NSColor colorWithCalibratedWhite:0.35 alpha:1.0];
                    isFillDark = YES;
                }
            }
        }

        // 3. Draw Fill Level (Clipped to body)
        CGFloat fillPct = MAX(0.04, MIN(percentage / 100.0, 1.0));
        CGFloat fillW = bodyW * fillPct;
        NSRect fillRect = NSMakeRect(bodyX, bodyY, fillW, bodyH);

        [NSGraphicsContext saveGraphicsState];
        [body addClip];
        [fillColor setFill];
        NSRectFill(fillRect);
        [NSGraphicsContext restoreGraphicsState];

        // 4. Two-Pass Content Drawing (Split Color for 100% legibility across dark mode)
        if (cfg->iconShowPercentage || cfg->iconShowGlyphs) {
            NSString *pctStr = @"";
            if (cfg->iconShowPercentage) {
                pctStr = cfg->iconShowPercentSign ? [NSString stringWithFormat:@"%d%%", percentage]
                                                   : [NSString stringWithFormat:@"%d", percentage];
            }

            CGFloat fontSize = 10.2;
            if (pctStr.length >= 4) { // e.g. "100%"
                fontSize = 7.6;
            } else if (pctStr.length == 3) { // e.g. "100" or "88%"
                fontSize = 8.6;
            } else if (totalW < 32.0) {
                fontSize = 9.2;
            }
            NSFont *font = [NSFont systemFontOfSize:fontSize weight:NSFontWeightBold];

            // Pass A: Over unfilled background -> Clean Crisp White in Dark Mode
            NSColor *unfilledTextColor = isDark ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.95]
                                                : [NSColor colorWithCalibratedWhite:0.1 alpha:0.95];
            [NSGraphicsContext saveGraphicsState];
            [body addClip];
            NSDictionary *unfilledAttrs = @{
                NSFontAttributeName: font,
                NSForegroundColorAttributeName: unfilledTextColor
            };
            drawStatusContent(pctStr, unfilledAttrs, bodyRect, state, externalConnected, isCharging, unfilledTextColor, cfg->iconShowGlyphs);
            [NSGraphicsContext restoreGraphicsState];

            // Pass B: Over filled background -> High contrast (Dark/Black or White if red)
            NSColor *filledTextColor = isFillDark ? [NSColor whiteColor] : [NSColor colorWithCalibratedWhite:0.05 alpha:1.0];
            [NSGraphicsContext saveGraphicsState];
            [body addClip];
            NSRectClip(fillRect); // Only over the filled area!
            NSDictionary *filledAttrs = @{
                NSFontAttributeName: font,
                NSForegroundColorAttributeName: filledTextColor
            };
            drawStatusContent(pctStr, filledAttrs, bodyRect, state, externalConnected, isCharging, filledTextColor, cfg->iconShowGlyphs);
            [NSGraphicsContext restoreGraphicsState];
        }

        // 5. Crisp Outer Border Stroke & Cap (High visibility in Dark Mode)
        NSColor *borderColor;
        if (cfg->iconHighContrastBorder) {
            borderColor = isDark ? [NSColor colorWithCalibratedWhite:1.0 alpha:0.85]
                                 : [NSColor colorWithCalibratedWhite:0.1 alpha:0.85];
        } else {
            borderColor = isDark ? [NSColor colorWithCalibratedWhite:0.70 alpha:0.45]
                                 : [NSColor colorWithCalibratedWhite:0.25 alpha:0.45];
        }
        [borderColor setStroke];
        [body setLineWidth:strokeW];
        [body stroke];

        [borderColor setFill];
        [cap fill];

        return YES;
    }];

    [icon setTemplate:NO];
    return icon;
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

    // Notification observer for immediate real-time icon customization updates
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateStatus)
                                                 name:kVoltCraftIconConfigChangedNotification
                                               object:nil];

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
