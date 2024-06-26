#import <Foundation/Foundation.h>
#import "PCS101Machine.h"
#import "PCSProgram.h"
#import "PCSNumber.h"

static void printUsage(void) {
    fprintf(stderr, "usage: p101run <program.prg> [--routine V] [--wheel N] [--set REG=VALUE ...] [inputs...]\n");
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            printUsage();
            return 2;
        }
        NSString *path = [NSString stringWithUTF8String:argv[1]];
        NSError *error = nil;
        NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
        if (!text) {
            fprintf(stderr, "cannot read %s: %s\n", argv[1], error.localizedDescription.UTF8String);
            return 1;
        }
        PCS101Program *program = [PCS101Program programWithText:text error:&error];
        if (!program) {
            fprintf(stderr, "parse error: %s\n", error.localizedDescription.UTF8String);
            return 1;
        }
        PCS101Machine *machine = [PCS101Machine new];
        [machine loadProgram:program error:NULL];
        NSString *routine = @"V";
        NSInteger wheel = program.decimalWheel >= 0 ? program.decimalWheel : 4;
        NSMutableArray<NSString *> *inputs = [NSMutableArray array];
        NSMutableArray<NSString *> *assignments = [NSMutableArray array];
        for (int i = 2; i < argc; i++) {
            NSString *arg = [NSString stringWithUTF8String:argv[i]];
            if ([arg isEqualToString:@"--routine"] && i + 1 < argc) {
                routine = [NSString stringWithUTF8String:argv[++i]];
            } else if ([arg isEqualToString:@"--wheel"] && i + 1 < argc) {
                wheel = atoi(argv[++i]);
            } else if ([arg isEqualToString:@"--set"] && i + 1 < argc) {
                [assignments addObject:[NSString stringWithUTF8String:argv[++i]]];
            } else {
                [inputs addObject:arg];
            }
        }
        machine.decimalWheel = wheel;
        for (NSString *assignment in assignments) {
            NSArray<NSString *> *parts = [assignment componentsSeparatedByString:@"="];
            if (parts.count == 2) {
                PCSNumber *value = [PCSNumber numberWithString:parts[1]];
                if (value) [machine setValue:value forRegister:parts[0]];
            }
        }
        error = nil;
        if (![machine startAtRoutine:routine error:&error]) {
            fprintf(stderr, "start error: %s\n", error.localizedDescription.UTF8String);
            return 1;
        }
        [machine runWithInputs:inputs maxSteps:2000000];

        printf("program: %s\n", path.lastPathComponent.UTF8String);
        printf("instructions: %lu, wheel: %ld, routine: %s\n",
               (unsigned long)program.instructions.count, (long)machine.decimalWheel, routine.UTF8String);
        printf("state: %ld, pc: %ld, error: %s\n",
               (long)machine.state, (long)machine.programCounter,
               machine.errorMessage ? machine.errorMessage.UTF8String : "-");
        printf("--- printer ---\n");
        for (NSString *line in machine.printerLines) {
            printf("%s\n", line.UTF8String);
        }
        printf("--- registers ---\n");
        for (NSString *name in machine.registerNames) {
            printf("%s = %s\n", name.UTF8String,
                   [[machine valueForRegister:name] stringValue].UTF8String);
        }
        return machine.state == PCS101StateError ? 1 : 0;
    }
}
