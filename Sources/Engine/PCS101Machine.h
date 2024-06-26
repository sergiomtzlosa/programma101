#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class PCSNumber;
@class PCS101Program;

typedef NS_ENUM(NSInteger, PCS101State) {
    PCS101StateIdle = 0,
    PCS101StateRunning,
    PCS101StateWaitingForInput,
    PCS101StateHalted,
    PCS101StateError
};

extern NSString *const PCS101MachineErrorDomain;

@interface PCS101Machine : NSObject

@property (nonatomic, assign) NSInteger decimalWheel; // 0…15, default 4
@property (nonatomic, readonly) PCS101State state;
@property (nonatomic, readonly, copy) NSArray<NSString *> *printerLines;
@property (nonatomic, readonly, copy, nullable) NSString *errorMessage;
@property (nonatomic, readonly) NSInteger programCounter;
@property (nonatomic, readonly, copy, nullable) PCS101Program *program;
@property (nonatomic, readonly, copy, nullable) NSString *currentInstructionText;
@property (nonatomic, assign) BOOL recordMode; // learn mode indicator
@property (nonatomic, readonly, copy) NSString *entryString;

- (void)reset;
- (void)resetRegisters;

- (NSArray<NSString *> *)registerNames;
- (PCSNumber *)valueForRegister:(NSString *)registerKey;
- (void)setValue:(PCSNumber *)value forRegister:(NSString *)registerKey;

- (BOOL)loadProgram:(PCS101Program *)program error:(NSError **)error;
// Multi-card operation: load the next card's program and constants without
// clearing the M/A/R/B/C data registers that the previous card left behind.
- (BOOL)loadProgram:(PCS101Program *)program
   preserveRegisters:(BOOL)preserve
               error:(NSError **)error;
- (BOOL)loadProgramText:(NSString *)text error:(NSError **)error;
- (BOOL)appendInstructionText:(NSString *)text error:(NSError **)error;
- (void)clearProgram;
- (void)printProgram;

- (BOOL)startAtRoutine:(NSString *)routine error:(NSError **)error;
- (void)step;
- (void)stop;
- (void)continueWithInput:(nullable PCSNumber *)input;
- (void)runWithMaxSteps:(NSInteger)maxSteps;
- (void)runWithInputs:(NSArray<NSString *> *)inputs maxSteps:(NSInteger)maxSteps;

// Keyboard entry (always accumulates into M).
- (void)entryDigit:(NSString *)digit;
- (void)entryDecimalPoint;
- (void)toggleEntrySign;
- (void)clearEntry;
- (void)commitEntry;

// Manual operation, e.g. register "A", operation "+" (`*` multiply, `:` divide,
// `#` sqrt, `^` ↑, `$` ↓, `&` ↕, `!` clear, `%` diamond).
- (BOOL)executeManualInstructionWithRegister:(NSString *)registerKey
                                  operation:(NSString *)operation
                                      error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
