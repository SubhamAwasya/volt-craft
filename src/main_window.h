#ifndef MAIN_WINDOW_H
#define MAIN_WINDOW_H

#import <Cocoa/Cocoa.h>
#import "sidebar_view.h"
#import "dashboard_view.h"
#import "charge_control_view.h"
#import "settings_tab_views.h"

@interface MainWindowController : NSWindowController <SidebarViewDelegate>

@property (nonatomic, strong) SidebarView *sidebarView;
@property (nonatomic, strong) NSView *contentContainer;

@property (nonatomic, strong) DashboardView *dashboardView;
@property (nonatomic, strong) ChargeControlView *chargeControlView;
@property (nonatomic, strong) SleepBehaviorView *sleepBehaviorView;
@property (nonatomic, strong) EnergyUseView *energyUseView;
@property (nonatomic, strong) ScheduleView *scheduleView;
@property (nonatomic, strong) ShortcutsView *shortcutsView;
@property (nonatomic, strong) PopoverSettingsView *popoverSettingsView;
@property (nonatomic, strong) MenuBarSettingsView *menuBarSettingsView;
@property (nonatomic, strong) OtherSettingsView *otherSettingsView;

+ (instancetype)sharedController;
- (void)showDashboard;

@end

#endif // MAIN_WINDOW_H
