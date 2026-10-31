#ifndef SLIDER_POPOVER_H
#define SLIDER_POPOVER_H

#import <Cocoa/Cocoa.h>

@protocol SliderPopoverDelegate <NSObject>
- (void)popoverDidRequestOpenSettings;
- (void)popoverDidRequestQuit;
@optional
- (void)popoverDidChangeChargeLimit;
@end

@interface SliderPopoverViewController : NSViewController

@property (nonatomic, weak) id<SliderPopoverDelegate> delegate;

- (void)refreshUI;

@end

#endif // SLIDER_POPOVER_H
