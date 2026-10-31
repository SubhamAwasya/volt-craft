#ifndef SIDEBAR_VIEW_H
#define SIDEBAR_VIEW_H

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, SidebarSection) {
    SidebarSectionDashboard = 0,
    SidebarSectionChargeControl,
    SidebarSectionSleepBehavior,
    SidebarSectionEnergyUse,
    SidebarSectionSchedule,
    SidebarSectionShortcuts,
    SidebarSectionPopover,
    SidebarSectionMenuBar,
    SidebarSectionOther
};

@protocol SidebarViewDelegate <NSObject>
- (void)sidebarDidSelectSection:(SidebarSection)section;
- (void)sidebarDidClickPower;
- (void)sidebarDidClickHelp;
- (void)sidebarDidClickSettings;
@end

@interface SidebarView : NSView

@property (nonatomic, weak) id<SidebarViewDelegate> delegate;
@property (nonatomic, assign) SidebarSection selectedSection;

- (void)selectSection:(SidebarSection)section;

@end

#endif // SIDEBAR_VIEW_H
