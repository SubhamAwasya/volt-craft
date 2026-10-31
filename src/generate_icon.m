#import <Cocoa/Cocoa.h>

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        int size = 1024;
        NSSize iconSize = NSMakeSize(size, size);
        NSImage *image = [[NSImage alloc] initWithSize:iconSize];
        [image lockFocus];

        NSRect fullRect = NSMakeRect(0, 0, size, size);

        // 1. Squircle Base (macOS App Icon Specification)
        // Standard macOS icon uses 824x824 squircle centered in 1024x1024 with 185pt corner radius
        NSRect tileRect = NSMakeRect(100, 100, 824, 824);
        NSBezierPath *tile = [NSBezierPath bezierPathWithRoundedRect:tileRect xRadius:185 yRadius:185];

        // Drop shadow for the tile
        NSShadow *shadow = [[NSShadow alloc] init];
        shadow.shadowColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.45];
        shadow.shadowOffset = NSMakeSize(0, -25);
        shadow.shadowBlurRadius = 35.0;
        [shadow set];

        // Background Gradient: Deep Midnight Titanium -> Space Grey
        NSColor *cTop = [NSColor colorWithCalibratedRed:0.14 green:0.15 blue:0.18 alpha:1.0];
        NSColor *cBot = [NSColor colorWithCalibratedRed:0.07 green:0.08 blue:0.09 alpha:1.0];
        NSGradient *tileGrad = [[NSGradient alloc] initWithStartingColor:cTop endingColor:cBot];
        [tileGrad drawInBezierPath:tile angle:90.0];

        // Remove shadow for inner contents
        NSShadow *noShadow = [[NSShadow alloc] init];
        [noShadow set];

        // Subtle 1.5px metallic rim stroke
        [tile setLineWidth:3.0];
        [[NSColor colorWithCalibratedWhite:0.35 alpha:0.4] setStroke];
        [tile stroke];

        // Inner glowing ambient halo
        NSBezierPath *innerClip = [NSBezierPath bezierPathWithRoundedRect:tileRect xRadius:185 yRadius:185];
        [innerClip addClip];

        // Ambient radial glow from center
        NSColor *haloCenter = [NSColor colorWithCalibratedRed:0.1 green:0.55 blue:0.85 alpha:0.35];
        NSColor *haloEdge = [NSColor colorWithCalibratedWhite:0.0 alpha:0.0];
        NSGradient *halo = [[NSGradient alloc] initWithStartingColor:haloCenter endingColor:haloEdge];
        [halo drawFromCenter:NSMakePoint(512, 512) radius:0 toCenter:NSMakePoint(512, 512) radius:480 options:0];

        // 2. Center Battery Cell Geometry
        // Vertical battery cell: w = 340, h = 500
        CGFloat battW = 340;
        CGFloat battH = 480;
        CGFloat battX = (size - battW) / 2;
        CGFloat battY = (size - battH) / 2 - 10;
        NSRect battBodyRect = NSMakeRect(battX, battY, battW, battH);
        NSBezierPath *battBody = [NSBezierPath bezierPathWithRoundedRect:battBodyRect xRadius:50 yRadius:50];

        // Battery outer shell outline (thick glowing neon cyan)
        [[NSColor colorWithCalibratedRed:0.1 green:0.85 blue:0.95 alpha:0.9] setStroke];
        [battBody setLineWidth:18.0];
        [battBody stroke];

        // Battery Terminal Cap at top
        CGFloat capW = 120;
        CGFloat capH = 36;
        CGFloat capX = (size - capW) / 2;
        CGFloat capY = battY + battH + 6;
        NSRect capRect = NSMakeRect(capX, capY, capW, capH);
        NSBezierPath *cap = [NSBezierPath bezierPathWithRoundedRect:capRect xRadius:14 yRadius:14];
        [[NSColor colorWithCalibratedRed:0.1 green:0.85 blue:0.95 alpha:0.9] setFill];
        [cap fill];

        // Inner battery liquid / energy fill (80% level fill)
        CGFloat fillMargin = 22.0;
        CGFloat fillW = battW - (fillMargin * 2);
        CGFloat fillMaxH = battH - (fillMargin * 2);
        CGFloat fillH = fillMaxH * 0.80; // 80% charge level!
        NSRect fillRect = NSMakeRect(battX + fillMargin, battY + fillMargin, fillW, fillH);
        NSBezierPath *fill = [NSBezierPath bezierPathWithRoundedRect:fillRect xRadius:32 yRadius:32];

        // Vibrant emerald to electric cyan gradient
        NSColor *fTop = [NSColor colorWithCalibratedRed:0.1 green:0.95 blue:0.75 alpha:0.85];
        NSColor *fBot = [NSColor colorWithCalibratedRed:0.05 green:0.65 blue:0.95 alpha:0.85];
        NSGradient *fillGrad = [[NSGradient alloc] initWithStartingColor:fTop endingColor:fBot];
        [fillGrad drawInBezierPath:fill angle:90.0];

        // 3. Electric Lightning Bolt in Center (VoltCraft Hallmark)
        NSBezierPath *bolt = [NSBezierPath bezierPath];
        CGFloat cx = 512;
        CGFloat cy = 490;
        [bolt moveToPoint:NSMakePoint(cx + 25, cy + 160)];
        [bolt lineToPoint:NSMakePoint(cx - 85, cy + 10)];
        [bolt lineToPoint:NSMakePoint(cx - 5, cy + 10)];
        [bolt lineToPoint:NSMakePoint(cx - 35, cy - 160)];
        [bolt lineToPoint:NSMakePoint(cx + 85, cy - 10)];
        [bolt lineToPoint:NSMakePoint(cx + 10, cy - 10)];
        [bolt closePath];

        // Bolt glow
        NSShadow *boltShadow = [[NSShadow alloc] init];
        boltShadow.shadowColor = [NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:0.9];
        boltShadow.shadowOffset = NSMakeSize(0, 0);
        boltShadow.shadowBlurRadius = 24.0;
        [boltShadow set];

        [[NSColor whiteColor] setFill];
        [bolt fill];

        [noShadow set];

        // 4. Glossy Glass Reflection Arc across top half
        NSBezierPath *gloss = [NSBezierPath bezierPath];
        [gloss moveToPoint:NSMakePoint(100, 512)];
        [gloss curveToPoint:NSMakePoint(924, 512)
              controlPoint1:NSMakePoint(320, 680)
              controlPoint2:NSMakePoint(704, 680)];
        [gloss lineToPoint:NSMakePoint(924, 924)];
        [gloss lineToPoint:NSMakePoint(100, 924)];
        [gloss closePath];

        NSColor *glossTop = [NSColor colorWithCalibratedWhite:1.0 alpha:0.12];
        NSColor *glossBot = [NSColor colorWithCalibratedWhite:1.0 alpha:0.0];
        NSGradient *glossGrad = [[NSGradient alloc] initWithStartingColor:glossTop endingColor:glossBot];
        [glossGrad drawInBezierPath:gloss angle:90.0];

        [image unlockFocus];

        // Save as 1024x1024 PNG
        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData:[image TIFFRepresentation]];
        NSData *pngData = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        NSString *outPath = @"voltcraft/AppIcon.png";
        [pngData writeToFile:outPath atomically:YES];
        printf("Successfully generated 1024x1024 icon at: %s\n", [outPath UTF8String]);
    }
    return 0;
}
