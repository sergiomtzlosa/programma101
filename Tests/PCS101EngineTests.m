#import <XCTest/XCTest.h>
#import "PCS101Machine.h"
#import "PCSProgram.h"
#import "PCSInstruction.h"
#import "PCSNumber.h"
#import "PCSCard.h"

static NSString *PCSExamplePath(NSString *name) {
    NSString *source = [NSString stringWithUTF8String:__FILE__];
    NSString *root = [[source stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
    return [[root stringByAppendingPathComponent:@"Resources/examples"] stringByAppendingPathComponent:name];
}

@interface PCS101EngineTests : XCTestCase
@end

@implementation PCS101EngineTests

- (PCS101Machine *)loadExample:(NSString *)name error:(NSError **)error {
    NSString *path = PCSExamplePath(name);
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:error];
    if (!text) return nil;
    PCS101Program *program = [PCS101Program programWithText:text error:error];
    if (!program) return nil;
    PCS101Machine *machine = [PCS101Machine new];
    [machine loadProgram:program error:error];
    return machine;
}

- (NSArray<NSString *> *)runExample:(NSString *)name
                             routine:(NSString *)routine
                               wheel:(NSInteger)wheel
                              inputs:(NSArray<NSString *> *)inputs {
    NSError *error = nil;
    PCS101Machine *machine = [self loadExample:name error:&error];
    XCTAssertNotNil(machine, @"load failed: %@", error);
    if (wheel >= 0) machine.decimalWheel = wheel;
    XCTAssertTrue([machine startAtRoutine:routine error:&error], @"start failed: %@", error);
    [machine runWithInputs:inputs maxSteps:1000000];
    XCTAssertNotEqual(machine.state, PCS101StateError, @"machine error: %@", machine.errorMessage);
    return machine.printerLines;
}

#pragma mark - Decimal arithmetic

- (void)testDecimalArithmetic {
    PCSNumber *a = [PCSNumber numberWithString:@"18"];
    PCSNumber *b = [PCSNumber numberWithString:@"4"];
    XCTAssertEqualObjects([[a adding:b] stringValue], @"22");
    XCTAssertEqualObjects([[a subtracting:b] stringValue], @"14");
    XCTAssertEqualObjects([[a multiplying:b] stringValue], @"72");
    XCTAssertEqualObjects([[a dividingBy:b decimalPlaces:0] stringValue], @"4");
    XCTAssertEqualObjects([[a squareRootWithDecimalPlaces:4] stringValue], @"4.2426");
    XCTAssertEqualObjects([a stringValueWithDecimalPlaces:4], @"18.0000");
    XCTAssertEqualObjects([[[PCSNumber numberWithString:@"3.14159"] truncatedToDecimalPlaces:2] stringValue], @"3.14");
    XCTAssertEqualObjects([[[PCSNumber numberWithString:@"-1.2345"] fractionalPart] stringValue], @"-0.2345");
}

- (void)testDivisionRemainder {
    PCS101Machine *machine = [PCS101Machine new];
    machine.decimalWheel = 2;
    [machine setValue:[PCSNumber numberWithString:@"7"] forRegister:@"A"];
    [machine setValue:[PCSNumber numberWithString:@"3"] forRegister:@"M"];
    NSError *error = nil;
    XCTAssertTrue([machine executeManualInstructionWithRegister:@"M" operation:@":" error:&error]);
    XCTAssertEqualObjects([[machine valueForRegister:@"A"] stringValue], @"2.33");
    XCTAssertEqualObjects([[machine valueForRegister:@"R"] stringValue], @"0.01");
}

#pragma mark - Instruction semantics

- (void)testAbsoluteValueAndFractionalPart {
    PCS101Machine *machine = [PCS101Machine new];
    [machine setValue:[PCSNumber numberWithString:@"-3.75"] forRegister:@"A"];
    NSError *error = nil;
    XCTAssertTrue([machine executeManualInstructionWithRegister:@"A" operation:@"&" error:&error]);
    XCTAssertEqualObjects([[machine valueForRegister:@"A"] stringValue], @"3.75");
    XCTAssertTrue([machine executeManualInstructionWithRegister:@"/" operation:@"&" error:&error]);
    XCTAssertEqualObjects([[machine valueForRegister:@"M"] stringValue], @"0.75");
}

- (void)testTransfersAndClear {
    PCS101Machine *machine = [PCS101Machine new];
    [machine setValue:[PCSNumber numberWithString:@"12.5"] forRegister:@"M"];
    NSError *error = nil;
    XCTAssertTrue([machine executeManualInstructionWithRegister:@"B" operation:@"^" error:&error]);
    XCTAssertEqualObjects([[machine valueForRegister:@"B"] stringValue], @"12.5");
    XCTAssertTrue([machine executeManualInstructionWithRegister:@"B" operation:@"$" error:&error]);
    XCTAssertEqualObjects([[machine valueForRegister:@"A"] stringValue], @"12.5");
    [machine setValue:[PCSNumber numberWithString:@"2"] forRegister:@"A"];
    XCTAssertTrue([machine executeManualInstructionWithRegister:@"B" operation:@"&" error:&error]);
    XCTAssertEqualObjects([[machine valueForRegister:@"A"] stringValue], @"12.5");
    XCTAssertEqualObjects([[machine valueForRegister:@"B"] stringValue], @"2");
    XCTAssertTrue([machine executeManualInstructionWithRegister:@"B" operation:@"!" error:&error]);
    XCTAssertEqualObjects([[machine valueForRegister:@"B"] stringValue], @"0");
}

- (void)testOnlyBFHaveSplittableHalves {
    PCS101Machine *machine = [PCS101Machine new];
    [machine setValue:[PCSNumber numberWithInteger:5] forRegister:@"A/"];
    XCTAssertEqualObjects([[machine valueForRegister:@"A"] stringValue], @"5");
    [machine setValue:[PCSNumber numberWithInteger:7] forRegister:@"B/"];
    XCTAssertEqualObjects([[machine valueForRegister:@"b"] stringValue], @"7");
    XCTAssertEqualObjects([[machine valueForRegister:@"B"] stringValue], @"0");
}

#pragma mark - Original programs

- (void)testManualExampleTest1 {
    NSArray<NSString *> *expected = @[@"7.0000", @"-1.0000", @"12.0000", @"18.0000", @"4.2426"];
    NSArray<NSString *> *actual = [self runExample:@"test1.prg" routine:@"V" wheel:4 inputs:@[@"3", @"4"]];
    XCTAssertEqualObjects(actual, expected);
}

- (void)testFactorialTest4 {
    NSArray<NSString *> *actual = [self runExample:@"test4.prg" routine:@"Z" wheel:0 inputs:@[@"5"]];
    XCTAssertEqualObjects(actual, @[@"120"]);
}

- (void)testArcCosineTest3 {
    NSArray<NSString *> *actual = [self runExample:@"test3.prg" routine:@"V" wheel:-1 inputs:@[@"0.8"]];
    XCTAssertEqualObjects(actual, @[@"0.6435011083"]);
}

- (void)testCubicRootTest2 {
    NSArray<NSString *> *actual = [self runExample:@"test2.prg" routine:@"V" wheel:4 inputs:@[@"2", @"3", @"-85"]];
    XCTAssertEqualObjects(actual, (@[@"3.3466", @""]));
}

- (void)testPistonVelocityProgramLoads {
    NSError *error = nil;
    PCS101Machine *machine = [self loadExample:@"test5.prg" error:&error];
    XCTAssertNotNil(machine, @"load failed: %@", error);
    XCTAssertEqual(machine.program.instructions.count, 106);
    XCTAssertTrue([machine startAtRoutine:@"V" error:&error]);
}

- (void)testConstantsAreLoadedFromListing {
    NSError *error = nil;
    PCS101Machine *machine = [self loadExample:@"test3.prg" error:&error];
    XCTAssertNotNil(machine);
    XCTAssertEqualObjects([[machine valueForRegister:@"F"] stringValue], @"-1");
    XCTAssertEqual(machine.decimalWheel, 10);
}

#pragma mark - Cards

- (void)testCardRoundTrip {
    NSError *error = nil;
    PCS101Machine *machine = [self loadExample:@"test4.prg" error:&error];
    XCTAssertNotNil(machine);
    machine.decimalWheel = 0;
    XCTAssertTrue([machine startAtRoutine:@"Z" error:&error]);
    [machine runWithInputs:@[@"6"] maxSteps:1000000];
    XCTAssertEqualObjects(machine.printerLines, @[@"720"]);

    PCSCard *card = [PCSCard cardWithProgram:machine.program];
    NSString *cardText = [card textRepresentation];
    PCSCard *reloaded = [PCSCard cardWithText:cardText error:&error];
    XCTAssertNotNil(reloaded, @"card parse failed: %@", error);
    XCTAssertEqual(reloaded.stripes.count, 1);

    PCS101Machine *fresh = [PCS101Machine new];
    XCTAssertTrue([fresh loadProgram:reloaded.stripes.firstObject error:&error]);
    fresh.decimalWheel = 0;
    XCTAssertTrue([fresh startAtRoutine:@"Z" error:&error]);
    [fresh runWithInputs:@[@"6"] maxSteps:1000000];
    XCTAssertEqualObjects(fresh.printerLines, @[@"720"]);
}

- (void)testMultiCardProgramPreservesRegistersAndRS {
    PCS101Program *first = [PCS101Program programWithText:@"# first card\nA V\n  S\n  V\n" error:NULL];
    PCS101Program *second = [PCS101Program programWithText:@"# second card\nA W\nR/S\nR %\n  S\n" error:NULL];
    XCTAssertNotNil(first);
    XCTAssertNotNil(second);

    NSError *error = nil;
    PCS101Machine *machine = [PCS101Machine new];
    XCTAssertTrue([machine loadProgram:first error:&error]);
    [machine setValue:[PCSNumber numberWithInteger:42] forRegister:@"D"];
    XCTAssertTrue([machine loadProgram:second preserveRegisters:YES error:&error]);
    XCTAssertEqualObjects([[machine valueForRegister:@"D"] stringValue], @"42");

    XCTAssertTrue([machine startAtRoutine:@"W" error:&error]);
    [machine runWithInputs:@[] maxSteps:1000];
    XCTAssertEqual(machine.state, PCS101StateWaitingForInput);
    XCTAssertEqualObjects(machine.printerLines, @[@"42"]);

    PCS101Machine *fresh = [PCS101Machine new];
    XCTAssertTrue([fresh loadProgram:second error:&error]);
    XCTAssertEqualObjects([[fresh valueForRegister:@"D"] stringValue], @"0");
}

- (void)testCardRoundTripPreservesConstants {
    NSError *error = nil;
    PCS101Machine *machine = [self loadExample:@"test3.prg" error:&error];
    XCTAssertNotNil(machine);
    XCTAssertEqualObjects([[machine valueForRegister:@"F"] stringValue], @"-1");
    XCTAssertTrue([machine startAtRoutine:@"V" error:&error]);
    [machine runWithInputs:@[@"0.8"] maxSteps:1000000];
    NSArray<NSString *> *expected = machine.printerLines;
    XCTAssertEqualObjects(expected, @[@"0.6435011083"]);

    PCSCard *card = [PCSCard cardWithProgram:machine.program];
    PCSCard *reloaded = [PCSCard cardWithText:[card textRepresentation] error:&error];
    XCTAssertNotNil(reloaded, @"card parse failed: %@", error);

    PCS101Machine *fresh = [PCS101Machine new];
    XCTAssertTrue([fresh loadProgram:reloaded.stripes.firstObject error:&error]);
    XCTAssertEqual(fresh.decimalWheel, 10);
    XCTAssertEqualObjects([[fresh valueForRegister:@"F"] stringValue], @"-1");
    XCTAssertTrue([fresh startAtRoutine:@"V" error:&error]);
    [fresh runWithInputs:@[@"0.8"] maxSteps:1000000];
    XCTAssertEqualObjects(fresh.printerLines, expected);
}

- (void)testCardRecordsRegisterSnapshot {
    PCS101Program *program = [PCS101Program programWithText:@"# snapshot test\nA V\n  S\nA %\n" error:NULL];
    XCTAssertNotNil(program);
    NSDictionary<NSString *, PCSNumber *> *constants = @{
        @"D": [PCSNumber numberWithString:@"10"],
        @"d": [PCSNumber numberWithString:@"2.5"],
        @"E": [PCSNumber numberWithString:@"0"],
        @"e": [PCSNumber numberWithString:@"0"],
        @"F": [PCSNumber numberWithString:@"-7"],
        @"f": [PCSNumber numberWithString:@"0.125"],
    };
    PCSCard *card = [PCSCard cardWithProgram:program constants:constants];
    NSError *error = nil;
    PCSCard *reloaded = [PCSCard cardWithText:[card textRepresentation] error:&error];
    XCTAssertNotNil(reloaded, @"card parse failed: %@", error);
    PCS101Program *copy = reloaded.stripes.firstObject;
    XCTAssertEqualObjects([copy.constants[@"D"] stringValue], @"10");
    XCTAssertEqualObjects([copy.constants[@"d"] stringValue], @"2.5");
    XCTAssertEqualObjects([copy.constants[@"F"] stringValue], @"-7");
    XCTAssertEqualObjects([copy.constants[@"f"] stringValue], @"0.125");

    PCS101Machine *machine = [PCS101Machine new];
    XCTAssertTrue([machine loadProgram:copy error:&error]);
    XCTAssertEqualObjects([[machine valueForRegister:@"D"] stringValue], @"10");
    XCTAssertEqualObjects([[machine valueForRegister:@"d"] stringValue], @"2.5");
    XCTAssertEqualObjects([[machine valueForRegister:@"F"] stringValue], @"-7");
    XCTAssertEqualObjects([[machine valueForRegister:@"f"] stringValue], @"0.125");
}

- (void)testTwoStripeCard {
    NSString *one = @"# one\nA V\n  S\nA %\n  V\n";
    NSString *two = @"# two\nA W\n  S\nA %\n  W\n";
    PCS101Program *p1 = [PCS101Program programWithText:one error:NULL];
    PCS101Program *p2 = [PCS101Program programWithText:two error:NULL];
    PCSCard *card = [PCSCard cardWithPrograms:@[p1, p2]];
    PCSCard *copy = [PCSCard cardWithText:[card textRepresentation] error:NULL];
    XCTAssertEqual(copy.stripes.count, 2);
    XCTAssertEqualObjects(copy.stripes[1].instructions.firstObject.text, @"A W");
}

#pragma mark - Learn mode

- (void)testAppendInstructionAndPrintProgram {
    PCS101Machine *machine = [PCS101Machine new];
    NSError *error = nil;
    XCTAssertTrue([machine appendInstructionText:@"A V" error:&error]);
    XCTAssertTrue([machine appendInstructionText:@"  S" error:&error]);
    XCTAssertTrue([machine appendInstructionText:@"A %" error:&error]);
    XCTAssertEqual(machine.program.instructions.count, 3);
    [machine printProgram];
    XCTAssertEqualObjects(machine.printerLines, (@[@"A V", @"  S", @"A %"]));
}

- (void)testKeyboardEntry {
    PCS101Machine *machine = [PCS101Machine new];
    [machine entryDigit:@"1"];
    [machine entryDigit:@"2"];
    [machine entryDecimalPoint];
    [machine entryDigit:@"5"];
    [machine toggleEntrySign];
    XCTAssertEqualObjects([[machine valueForRegister:@"M"] stringValue], @"-12.5");
    [machine clearEntry];
    XCTAssertEqualObjects([[machine valueForRegister:@"M"] stringValue], @"0");
}

@end
