#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class PCS101Machine;

@interface PCSMachineWindowController : NSWindowController

@property (nonatomic, readonly) PCS101Machine *machine;

- (instancetype)init;
- (void)loadProgramFromPath:(NSString *)path;
- (void)loadExampleFromPath:(NSString *)path;

- (IBAction)openProgram:(nullable id)sender;
- (IBAction)insertCard:(nullable id)sender;
- (IBAction)saveCard:(nullable id)sender;
- (IBAction)resetMachine:(nullable id)sender;
- (IBAction)runMachine:(nullable id)sender;
- (IBAction)stepMachine:(nullable id)sender;
- (IBAction)stopMachine:(nullable id)sender;
- (IBAction)printProgram:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
