#import <Cocoa/Cocoa.h>

static void drawStandardMacOSShadow(CGContextRef ctx, NSRect sqRect, CGFloat cornerR) {
    CGContextSaveGState(ctx);
    NSBezierPath *shadowPath = [NSBezierPath bezierPathWithRoundedRect:sqRect xRadius:cornerR yRadius:cornerR];
    NSShadow *dropShadow = [[NSShadow alloc] init];
    dropShadow.shadowColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.32];
    dropShadow.shadowBlurRadius = 38.0;
    dropShadow.shadowOffset = NSMakeSize(0, -20.0);
    [dropShadow set];
    [[NSColor blackColor] setFill];
    [shadowPath fill];
    CGContextRestoreGState(ctx);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        int size = 1024;
        NSSize iconSize = NSMakeSize(size, size);
        NSImage *image = [NSImage imageWithSize:iconSize flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
            CGContextRef ctx = [NSGraphicsContext currentContext].CGContext;
            NSRect sqRect = NSMakeRect(100, 100, 824, 824);
            CGFloat cornerR = 185;

            // 1. Standard macOS Ambient Drop Shadow
            drawStandardMacOSShadow(ctx, sqRect, cornerR);

            // 2. Base Squircle with Deep Midnight Slate Gradient
            NSBezierPath *sq = [NSBezierPath bezierPathWithRoundedRect:sqRect xRadius:cornerR yRadius:cornerR];
            [NSGraphicsContext saveGraphicsState];
            [sq addClip];

            NSGradient *bgGrad = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedRed:0.09 green:0.105 blue:0.13 alpha:1.0]
                                                               endingColor:[NSColor colorWithCalibratedRed:0.14 green:0.165 blue:0.21 alpha:1.0]];
            [bgGrad drawInRect:sqRect angle:90];

            // Subtle ambient radial glow behind battery
            CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
            CGFloat glowComp[] = { 0.20, 0.82, 0.45, 0.16,  0.20, 0.82, 0.45, 0.0 };
            CGFloat glowLoc[] = { 0.0, 1.0 };
            CGGradientRef radGlow = CGGradientCreateWithColorComponents(cs, glowComp, glowLoc, 2);
            CGContextDrawRadialGradient(ctx, radGlow, CGPointMake(512, 512), 40, CGPointMake(512, 512), 360, 0);
            CGGradientRelease(radGlow);
            CGColorSpaceRelease(cs);

            // 3. Flat 2D Vertical Battery Geometry
            CGFloat bw = 276;
            CGFloat bh = 496;
            CGFloat capW = 108;
            CGFloat capH = 28;
            CGFloat capGap = 16;
            CGFloat totalH = bh + capGap + capH;

            CGFloat bx = (1024 - bw) / 2.0;
            CGFloat by = (1024 - totalH) / 2.0;
            CGFloat br = 56;

            NSRect bRect = NSMakeRect(bx, by, bw, bh);
            NSBezierPath *battery = [NSBezierPath bezierPathWithRoundedRect:bRect xRadius:br yRadius:br];

            // Cap on top
            CGFloat cx = (1024 - capW) / 2.0;
            CGFloat cy = by + bh + capGap;
            NSBezierPath *cap = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(cx, cy, capW, capH) xRadius:14 yRadius:14];

            // Shell Background
            [[NSColor colorWithCalibratedWhite:1.0 alpha:0.08] setFill];
            [battery fill];

            // Inner 80% Energy Level Fill (Clean Flat Gradient)
            NSRect innerRect = NSInsetRect(bRect, 20, 20);
            NSBezierPath *innerPath = [NSBezierPath bezierPathWithRoundedRect:innerRect xRadius:br - 18 yRadius:br - 18];
            [NSGraphicsContext saveGraphicsState];
            [innerPath addClip];

            [[NSColor colorWithCalibratedWhite:0.0 alpha:0.35] setFill];
            [innerPath fill];

            CGFloat fillH = innerRect.size.height * 0.80;
            NSRect fillRect = NSMakeRect(innerRect.origin.x, innerRect.origin.y, innerRect.size.width, fillH);
            NSGradient *fillGrad = [[NSGradient alloc] initWithStartingColor:[NSColor colorWithCalibratedRed:0.18 green:0.82 blue:0.42 alpha:1.0]
                                                                 endingColor:[NSColor colorWithCalibratedRed:0.24 green:0.90 blue:0.58 alpha:1.0]];
            [fillGrad drawInRect:fillRect angle:90];
            [NSGraphicsContext restoreGraphicsState];

            // 4. Bold Crisp Lightning Bolt in Center (Pure 2D vector, no blur)
            CGFloat boltW = 106;
            CGFloat boltH = 180;
            CGFloat boltX = (1024 - boltW) / 2.0;
            CGFloat boltY = by + (bh - boltH) / 2.0;

            NSBezierPath *bolt = [NSBezierPath bezierPath];
            [bolt moveToPoint:NSMakePoint(boltX + 64, boltY + boltH)];
            [bolt lineToPoint:NSMakePoint(boltX + 6,  boltY + 82)];
            [bolt lineToPoint:NSMakePoint(boltX + 54, boltY + 82)];
            [bolt lineToPoint:NSMakePoint(boltX + 44, boltY + 0)];
            [bolt lineToPoint:NSMakePoint(boltX + 102, boltY + 98)];
            [bolt lineToPoint:NSMakePoint(boltX + 54, boltY + 98)];
            [bolt closePath];

            [NSGraphicsContext saveGraphicsState];
            NSShadow *boltShadow = [[NSShadow alloc] init];
            boltShadow.shadowColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.30];
            boltShadow.shadowBlurRadius = 8;
            boltShadow.shadowOffset = NSMakeSize(0, -3);
            [boltShadow set];
            [[NSColor whiteColor] setFill];
            [bolt fill];
            [NSGraphicsContext restoreGraphicsState];

            // 5. Outer Border & Cap in Crisp Apple Silver
            [battery setLineWidth:18];
            [[NSColor colorWithCalibratedWhite:1.0 alpha:0.82] setStroke];
            [battery stroke];

            [[NSColor colorWithCalibratedWhite:1.0 alpha:0.82] setFill];
            [cap fill];

            // Inner squircle highlight rim
            [NSGraphicsContext restoreGraphicsState];
            [sq setLineWidth:2.0];
            [[NSColor colorWithCalibratedWhite:1.0 alpha:0.18] setStroke];
            [sq stroke];

            return YES;
        }];

        // Save as 1024x1024 PNG
        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData:[image TIFFRepresentation]];
        NSData *pngData = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        NSString *outPath = @"AppIcon.png";
        [pngData writeToFile:outPath atomically:YES];
        printf("Successfully generated clean 2D flat 1024x1024 icon at: %s\n", [outPath UTF8String]);
    }
    return 0;
}
