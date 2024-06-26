#import "PCS101Machine.h"
#import "PCSInstruction.h"
#import "PCSNumber.h"
#import "PCSProgram.h"

NSString *const PCS101MachineErrorDomain = @"PCS101MachineErrorDomain";

static NSString *PCSNormalizeRegister(NSString *key) {
    if (![key isKindOfClass:[NSString class]] || key.length == 0) return @"M";
    if ([key isEqualToString:@"/"]) return @"/";
    if ([key hasSuffix:@"/"]) {
        NSString *base = [[key substringToIndex:key.length - 1] uppercaseString];
        // Only B–F can be split into left/right halves. M, A and R are never
        // split; an A/ style instruction therefore addresses the full register.
        if (base.length == 1 && [@"BCDEF" containsString:base]) {
            return [base lowercaseString];
        }
        return base;
    }
    if (key.length == 1) {
        unichar c = [key characterAtIndex:0];
        if (c >= 'b' && c <= 'f') return key; // split-register half, e.g. "b"
        if (c == 'a') return @"A";
    }
    return [key uppercaseString];
}

static NSInteger PCSCapacityForRegister(NSString *key) {
    if (key.length == 1) {
        unichar c = [key characterAtIndex:0];
        if (c >= 'b' && c <= 'f') return 11;
    }
    return 22;
}

static NSInteger PCSDigitForConstantOp(unichar op) {
    switch (op) {
        case 'S': return 0;
        case '$': return 1;
        case '^': return 2;
        case '&': return 3;
        case '+': return 4;
        case '-': return 5;
        case '*': return 6;
        case ':': return 7;
        case '%': return 8;
        case '!': return 9;
        default: return -1;
    }
}

@interface PCS101Machine () {
    NSMutableDictionary<NSString *, PCSNumber *> *_registers;
    NSMutableArray<NSString *> *_printer;
    PCS101Program *_program;
    NSInteger _pc;
    PCS101State _state;
    NSString *_errorMessage;
    NSMutableString *_entry;
    NSInteger _decimalWheel;
}

@end

@implementation PCS101Machine

- (instancetype)init {
    self = [super init];
    if (self) {
        _registers = [NSMutableDictionary dictionary];
        _printer = [NSMutableArray array];
        _entry = [NSMutableString string];
        _decimalWheel = 4;
        [self resetRegisters];
    }
    return self;
}

- (void)setDecimalWheel:(NSInteger)decimalWheel {
    _decimalWheel = MIN(MAX(decimalWheel, 0), 15);
}

- (NSInteger)decimalWheel {
    return _decimalWheel;
}

- (NSArray<NSString *> *)printerLines {
    return [_printer copy];
}

- (NSString *)errorMessage {
    return _errorMessage;
}

- (PCS101State)state {
    return _state;
}

- (NSInteger)programCounter {
    return _pc;
}

- (PCS101Program *)program {
    return _program;
}

- (NSString *)currentInstructionText {
    if (!_program) return nil;
    NSArray<PCS101Instruction *> *instructions = _program.instructions;
    if (_pc < 0 || _pc >= (NSInteger)instructions.count) return nil;
    return instructions[(NSUInteger)_pc].text;
}

- (NSString *)entryString {
    return [_entry copy];
}

- (NSArray<NSString *> *)registerNames {
    return @[@"M", @"A", @"R",
             @"B", @"b", @"C", @"c", @"D", @"d", @"E", @"e", @"F", @"f"];
}

- (void)reset {
    _program = nil;
    _pc = 0;
    _decimalWheel = 4;
    _recordMode = NO;
    [_printer removeAllObjects];
    [self resetRegisters];
}

- (void)resetRegisters {
    _registers = [NSMutableDictionary dictionary];
    NSArray<NSString *> *keys = @[@"M", @"A", @"R",
                                  @"B", @"b", @"C", @"c", @"D", @"d",
                                  @"E", @"e", @"F", @"f"];
    for (NSString *key in keys) {
        _registers[key] = [PCSNumber zero];
    }
    _entry = [NSMutableString string];
    _errorMessage = nil;
    _state = PCS101StateIdle;
}

- (PCSNumber *)valueForRegister:(NSString *)registerKey {
    NSString *key = PCSNormalizeRegister(registerKey);
    PCSNumber *value = _registers[key];
    if (!value) {
        value = [PCSNumber zero];
        _registers[key] = value;
    }
    return value;
}

- (void)setValue:(PCSNumber *)value forRegister:(NSString *)registerKey {
    NSString *key = PCSNormalizeRegister(registerKey);
    if (![key isEqualToString:@"/"] && value) {
        _registers[key] = [value truncatedToSignificantDigits:PCSCapacityForRegister(key)];
    }
}

#pragma mark - Program

- (BOOL)loadProgram:(PCS101Program *)program error:(NSError **)error {
    return [self loadProgram:program preserveRegisters:NO error:error];
}

- (BOOL)loadProgram:(PCS101Program *)program
   preserveRegisters:(BOOL)preserve
               error:(NSError **)error {
    if (!program) {
        if (error) {
            *error = [NSError errorWithDomain:PCS101MachineErrorDomain code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"No program supplied."}];
        }
        return NO;
    }
    _program = program;
    _pc = 0;
    if (preserve) {
        _entry = [NSMutableString string];
        _errorMessage = nil;
        _state = PCS101StateIdle;
    } else {
        [self resetRegisters];
        [_printer removeAllObjects];
    }
    if (program.decimalWheel >= 0) self.decimalWheel = program.decimalWheel;
    for (NSString *key in program.constants) {
        [self setValue:program.constants[key] forRegister:key];
    }
    return YES;
}

- (BOOL)loadProgramText:(NSString *)text error:(NSError **)error {
    PCS101Program *program = [PCS101Program programWithText:text error:error];
    if (!program) return NO;
    return [self loadProgram:program error:error];
}

- (BOOL)appendInstructionText:(NSString *)text error:(NSError **)error {
    if (!_program) {
        _program = [PCS101Program programWithText:@"" error:NULL];
    }
    return [_program appendInstructionText:text error:error];
}

- (void)clearProgram {
    _program = nil;
    _pc = 0;
    _state = PCS101StateIdle;
}

- (void)printProgram {
    for (PCS101Instruction *instruction in _program.instructions) {
        [_printer addObject:instruction.text];
    }
}

#pragma mark - Execution

- (BOOL)startAtRoutine:(NSString *)routine error:(NSError **)error {
    if (!_program) {
        if (error) {
            *error = [NSError errorWithDomain:PCS101MachineErrorDomain code:2
                                     userInfo:@{NSLocalizedDescriptionKey: @"No program is loaded."}];
        }
        return NO;
    }
    NSString *key = [routine uppercaseString];
    if (!([key isEqualToString:@"V"] || [key isEqualToString:@"W"] ||
          [key isEqualToString:@"Y"] || [key isEqualToString:@"Z"])) {
        if (error) {
            *error = [NSError errorWithDomain:PCS101MachineErrorDomain code:3
                                     userInfo:@{NSLocalizedDescriptionKey: @"Routine must be V, W, Y or Z."}];
        }
        return NO;
    }
    NSString *label = [NSString stringWithFormat:@"A %@", key];
    NSNumber *index = [_program indexOfLabelText:label];
    if (!index) {
        if (error) {
            *error = [NSError errorWithDomain:PCS101MachineErrorDomain code:4
                                     userInfo:@{NSLocalizedDescriptionKey:
                                                    [NSString stringWithFormat:@"Start label “%@” not found.", label]}];
        }
        return NO;
    }
    _pc = index.integerValue + 1;
    _errorMessage = nil;
    _state = PCS101StateRunning;
    return YES;
}

- (void)failWithMessage:(NSString *)message {
    _errorMessage = message;
    _state = PCS101StateError;
}

- (NSError *)errorWithMessage:(NSString *)message code:(NSInteger)code {
    return [NSError errorWithDomain:PCS101MachineErrorDomain code:code
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

- (void)performArithmeticOperation:(unichar)op source:(PCSNumber *)source {
    [self setValue:source forRegister:@"M"];
    PCSNumber *a = [self valueForRegister:@"A"];

    if (op == '#') {
        PCSNumber *root = [[source absoluteValue] squareRootWithDecimalPlaces:_decimalWheel];
        if (!root) {
            [self failWithMessage:@"Square root failed."];
            return;
        }
        [self setValue:root forRegister:@"A"];
        [self setValue:[[self valueForRegister:@"A"] multiplying:[PCSNumber numberWithInteger:2]]
            forRegister:@"M"];
        return;
    }

    PCSNumber *fullResult = nil;
    if (op == '+') {
        fullResult = [a adding:source];
    } else if (op == '-') {
        fullResult = [a subtracting:source];
    } else if (op == '*') {
        fullResult = [a multiplying:source];
    } else if (op == ':') {
        if (source.isZero) {
            [self failWithMessage:@"Division by zero."];
            return;
        }
        PCSNumber *quotient = [a dividingBy:source decimalPlaces:_decimalWheel];
        if (!quotient) {
            [self failWithMessage:@"Division failed."];
            return;
        }
        PCSNumber *remainder = [a subtracting:[quotient multiplying:source]];
        [self setValue:quotient forRegister:@"A"];
        [self setValue:remainder forRegister:@"R"];
        return;
    } else {
        return;
    }

    [self setValue:fullResult forRegister:@"R"];
    [self setValue:[fullResult truncatedToDecimalPlaces:_decimalWheel] forRegister:@"A"];
}

- (void)printRegisterKey:(NSString *)registerKey {
    PCSNumber *value = [self valueForRegister:registerKey];
    NSInteger places = _decimalWheel;
    if ([PCSNormalizeRegister(registerKey) isEqualToString:@"R"]) {
        places = value.scale;
    }
    [_printer addObject:[value stringValueWithDecimalPlaces:places]];
}

- (BOOL)performSimpleInstruction:(PCS101Instruction *)instruction error:(NSError **)error {
    unichar op = instruction.operation;
    NSString *reg = instruction.registerKey;

    if (op == '+' || op == '-' || op == '*' || op == ':' || op == '#') {
        if ([reg isEqualToString:@"/"]) {
            if (error) *error = [self errorWithMessage:@"Invalid register for arithmetic." code:10];
            return NO;
        }
        [self performArithmeticOperation:op source:[self valueForRegister:reg]];
        if (_state == PCS101StateError) {
            if (error) *error = [self errorWithMessage:_errorMessage ?: @"Arithmetic error." code:11];
            return NO;
        }
        return YES;
    }

    if (op == '^') {
        if ([reg isEqualToString:@"/"]) {
            if (error) *error = [self errorWithMessage:@"Invalid destination register." code:12];
            return NO;
        }
        [self setValue:[self valueForRegister:@"M"] forRegister:reg];
        return YES;
    }

    if (op == '$') {
        if ([reg isEqualToString:@"/"]) {
            if (error) *error = [self errorWithMessage:@"Invalid source register." code:13];
            return NO;
        }
        [self setValue:[self valueForRegister:reg] forRegister:@"A"];
        return YES;
    }

    if (op == '&') {
        if ([reg isEqualToString:@"A"]) {
            [self setValue:[[self valueForRegister:@"A"] absoluteValue] forRegister:@"A"];
            return YES;
        }
        if ([reg isEqualToString:@"/"]) {
            [self setValue:[[self valueForRegister:@"A"] fractionalPart] forRegister:@"M"];
            return YES;
        }
        PCSNumber *other = [self valueForRegister:reg];
        PCSNumber *a = [self valueForRegister:@"A"];
        [self setValue:other forRegister:@"A"];
        [self setValue:a forRegister:reg];
        return YES;
    }

    if (op == '!') {
        if ([reg isEqualToString:@"/"]) {
            if (error) *error = [self errorWithMessage:@"Invalid register to clear." code:14];
            return NO;
        }
        [self setValue:[PCSNumber zero] forRegister:reg];
        return YES;
    }

    if (op == '%') {
        if ([reg isEqualToString:@"/"]) {
            [_printer addObject:@""];
        } else {
            [self printRegisterKey:reg];
        }
        return YES;
    }

    if (error) *error = [self errorWithMessage:@"Instruction cannot be executed manually." code:15];
    return NO;
}

- (void)executeConstantLoader {
    NSArray<PCS101Instruction *> *instructions = _program.instructions;
    NSInteger count = (NSInteger)instructions.count;
    NSInteger i = _pc + 1;
    NSInteger limit = MIN(count, _pc + 40);
    NSMutableArray<NSNumber *> *digits = [NSMutableArray array];
    NSMutableArray<NSNumber *> *commas = [NSMutableArray array];
    NSInteger sign = 1;
    BOOL terminated = NO;

    while (i < limit) {
        PCS101Instruction *pseudo = instructions[(NSUInteger)i];
        NSInteger digit = PCSDigitForConstantOp(pseudo.operation);
        if (digit < 0) {
            [self failWithMessage:@"Malformed encoded constant."];
            return;
        }
        unichar key1 = [pseudo.text characterAtIndex:0];
        if (key1 == 'D' || key1 == 'R') {
            sign = 1;
        } else if (key1 == 'E' || key1 == 'F') {
            sign = -1;
        } else {
            [self failWithMessage:@"Malformed encoded constant sign."];
            return;
        }
        [digits addObject:@(digit)];
        [commas addObject:@([pseudo.text characterAtIndex:1] == '/')];
        i++;
        if (key1 == 'D' || key1 == 'E') {
            terminated = YES;
            break;
        }
    }

    if (!terminated) {
        [self failWithMessage:@"Unterminated encoded constant."];
        return;
    }

    NSMutableString *numberString = [NSMutableString string];
    for (NSInteger k = (NSInteger)digits.count - 1; k >= 0; k--) {
        [numberString appendFormat:@"%d", digits[(NSUInteger)k].intValue];
        if (commas[(NSUInteger)k].boolValue) [numberString appendString:@"."];
    }
    PCSNumber *number = [PCSNumber numberWithString:numberString];
    if (!number) {
        [self failWithMessage:@"Malformed encoded constant value."];
        return;
    }
    if (sign < 0) number = [number negated];
    [self setValue:number forRegister:@"M"];
    _pc = i;
}

- (void)executeJump:(PCS101Instruction *)instruction {
    if (instruction.isConditionalJump && ![self valueForRegister:@"A"].isPositive) {
        _pc++;
        return;
    }
    NSString *target = [instruction jumpTargetText];
    NSNumber *index = target ? [_program indexOfLabelText:target] : nil;
    if (!index) {
        [self failWithMessage:[NSString stringWithFormat:@"Jump reference “%@” not found.", target ?: @"?"]];
        return;
    }
    _pc = index.integerValue + 1;
}

- (void)step {
    if (_state != PCS101StateRunning) return;
    if (!_program) {
        _state = PCS101StateHalted;
        return;
    }
    NSArray<PCS101Instruction *> *instructions = _program.instructions;
    if (_pc < 0 || _pc >= (NSInteger)instructions.count) {
        _state = PCS101StateHalted;
        return;
    }
    PCS101Instruction *instruction = instructions[(NSUInteger)_pc];

    if ([instruction isConstantLoader]) {
        [self executeConstantLoader];
        return;
    }

    if ([instruction isJump]) {
        if (![instruction isJumpOrigin]) {
            _pc++;
        } else {
            [self executeJump:instruction];
        }
        return;
    }

    if (instruction.operation == 'S') {
        if ([instruction.text isEqualToString:@"R/S"] || [instruction.text isEqualToString:@"R S"]) {
            PCSNumber *r = [self valueForRegister:@"R"];
            PCSNumber *d = [self valueForRegister:@"D"];
            [self setValue:d forRegister:@"R"];
            [self setValue:r forRegister:@"D"];
        } else {
            _state = PCS101StateWaitingForInput;
        }
        _pc++;
        return;
    }

    NSError *error = nil;
    if (![self performSimpleInstruction:instruction error:&error]) {
        [self failWithMessage:error.localizedDescription ?: @"Unrecognised instruction."];
        return;
    }
    _pc++;
}

- (void)stop {
    if (_state == PCS101StateRunning || _state == PCS101StateWaitingForInput) {
        _state = PCS101StateIdle;
    }
}

- (void)continueWithInput:(PCSNumber *)input {
    if (input) [self setValue:input forRegister:@"M"];
    [_entry setString:@""];
    if (_state == PCS101StateWaitingForInput) {
        _state = PCS101StateRunning;
    }
}

- (void)runWithMaxSteps:(NSInteger)maxSteps {
    NSInteger steps = 0;
    while (_state == PCS101StateRunning && steps < maxSteps) {
        [self step];
        steps++;
    }
}

- (void)runWithInputs:(NSArray<NSString *> *)inputs maxSteps:(NSInteger)maxSteps {
    NSInteger inputIndex = 0;
    NSInteger steps = 0;
    while (steps < maxSteps) {
        if (_state == PCS101StateWaitingForInput) {
            if (inputIndex >= (NSInteger)inputs.count) break;
            PCSNumber *value = [PCSNumber numberWithString:inputs[(NSUInteger)inputIndex++]];
            if (!value) {
                [self failWithMessage:@"Invalid input value."];
                break;
            }
            [self continueWithInput:value];
            continue;
        }
        if (_state != PCS101StateRunning) break;
        [self step];
        steps++;
    }
}

#pragma mark - Keyboard entry

- (void)updateMFromEntry {
    if (_entry.length == 0) return;
    PCSNumber *number = [PCSNumber numberWithString:_entry];
    if (number) [self setValue:number forRegister:@"M"];
}

- (void)entryDigit:(NSString *)digit {
    if (digit.length != 1) return;
    unichar c = [digit characterAtIndex:0];
    if (c < '0' || c > '9') return;
    NSInteger digitCount = 0;
    for (NSUInteger i = 0; i < _entry.length; i++) {
        unichar existing = [_entry characterAtIndex:i];
        if (existing >= '0' && existing <= '9') digitCount++;
    }
    if (digitCount >= 22) return;
    [_entry appendString:digit];
    [self updateMFromEntry];
}

- (void)entryDecimalPoint {
    if ([_entry rangeOfString:@"."].location != NSNotFound) return;
    if (_entry.length == 0) [_entry appendString:@"0"];
    [_entry appendString:@"."];
    [self updateMFromEntry];
}

- (void)toggleEntrySign {
    if ([_entry hasPrefix:@"-"]) {
        [_entry deleteCharactersInRange:NSMakeRange(0, 1)];
    } else {
        [_entry insertString:@"-" atIndex:0];
    }
    [self updateMFromEntry];
}

- (void)clearEntry {
    [_entry setString:@""];
    [self setValue:[PCSNumber zero] forRegister:@"M"];
}

- (void)commitEntry {
    [self updateMFromEntry];
    [_entry setString:@""];
}

- (BOOL)executeManualInstructionWithRegister:(NSString *)registerKey
                                  operation:(NSString *)operation
                                      error:(NSError **)error {
    NSString *key = PCSNormalizeRegister(registerKey);
    unichar op;
    if (operation.length == 1) {
        op = [operation characterAtIndex:0];
        switch (op) {
            case 0x00D7: op = '*'; break; // ×
            case 0x00F7: op = ':'; break; // ÷
            case 0x221A: op = '#'; break; // √
            case 0x2195: op = '&'; break; // ↕
            case 0x2191: op = '^'; break; // ↑
            case 0x2193: op = '$'; break; // ↓
            case 0x2662: op = '%'; break; // ♢
            default: break;
        }
    } else {
        if (error) *error = [self errorWithMessage:@"Unknown operation." code:20];
        return NO;
    }

    unichar key1 = ' ';
    unichar key2 = ' ';
    if ([key isEqualToString:@"/"]) {
        key2 = '/';
    } else if ([key isEqualToString:@"M"]) {
        key1 = ' ';
    } else {
        unichar c = [key characterAtIndex:0];
        if (c >= 'a' && c <= 'f') {
            key1 = c - 32;
            key2 = '/';
        } else {
            key1 = c;
        }
    }
    NSString *text = [NSString stringWithFormat:@"%c%c%c", key1, key2, op];
    PCS101Instruction *instruction = [PCS101Instruction instructionWithText:text];
    if (!instruction) {
        if (error) *error = [self errorWithMessage:@"Invalid instruction." code:21];
        return NO;
    }
    if (instruction.isJump || instruction.operation == 'S') {
        if (error) *error = [self errorWithMessage:@"Use the program controls for jumps and stops." code:22];
        return NO;
    }
    return [self performSimpleInstruction:instruction error:error];
}

@end
