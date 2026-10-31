#ifndef MENU_BAR_H
#define MENU_BAR_H

#import <Cocoa/Cocoa.h>
#import "main_window.h"
#import "slider_popover.h"

@interface VoltCraftAppDelegate : NSObject <NSApplicationDelegate, SliderPopoverDelegate>

@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSPopover *popover;
@property (nonatomic, strong) SliderPopoverViewController *popoverVC;
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, strong) MainWindowController *mainController;

- (void)updateStatus;
- (void)togglePopover:(id)sender;

@end

#endif // MENU_BAR_H
