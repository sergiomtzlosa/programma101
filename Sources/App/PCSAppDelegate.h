#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class PCSMachineWindowController;

@interface PCSAppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, strong, nullable) PCSMachineWindowController *windowController;

@end

NS_ASSUME_NONNULL_END
