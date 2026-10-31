#ifndef SETTINGS_TAB_VIEWS_H
#define SETTINGS_TAB_VIEWS_H

#import <Cocoa/Cocoa.h>

// --- Helper Base Card Class for Consistent Professional Styling ---
@interface SettingsCardView : NSBox
+ (instancetype)cardWithFrame:(NSRect)frame;
@end

// 1. Sleep Behavior View
@interface SleepBehaviorView : NSView
- (void)refreshUI;
@end

// 2. Energy Use View
@interface EnergyUseView : NSView
- (void)refreshUI;
@end

// 3. Schedule View
@interface ScheduleView : NSView
- (void)refreshUI;
@end

// 4. Shortcuts View
@interface ShortcutsView : NSView
- (void)refreshUI;
@end

// 5. Popover Settings View
@interface PopoverSettingsView : NSView
- (void)refreshUI;
@end

// 6. Menu Bar Settings View
@interface MenuBarSettingsView : NSView
- (void)refreshUI;
@end

// 7. Other Settings View
@interface OtherSettingsView : NSView
- (void)refreshUI;
@end

#endif // SETTINGS_TAB_VIEWS_H
