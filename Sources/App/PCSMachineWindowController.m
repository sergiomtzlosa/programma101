#import "PCSMachineWindowController.h"
#import "PCSKeyboardView.h"
#import "PCS101Machine.h"
#import "PCSProgram.h"
#import "PCSInstruction.h"
#import "PCSNumber.h"
#import "PCSCard.h"

@interface PCSMachineWindowController () <PCSKeyboardViewDelegate, NSTextFieldDelegate>
@property (nonatomic, strong) PCS101Machine *machine;
@property (nonatomic, strong) NSTextView *printerView;
@property (nonatomic, strong) NSTextView *listingView;
@property (nonatomic, strong) NSTextField *stateLabel;
@property (nonatomic, strong) NSTextField *pcLabel;
@property (nonatomic, strong) NSTextField *pendingLabel;
@property (nonatomic, strong) NSTextField *messageLabel;
@property (nonatomic, strong) NSTextField *entryField;
@property (nonatomic, strong) NSPopUpButton *wheelPopUp;
@property (nonatomic, strong) NSButton *recordCheckbox;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSTextField *> *registerFields;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, copy) NSString *pendingRegister;
@property (nonatomic, copy) NSString *lastRoutine;
@property (nonatomic) NSUInteger lastPrinterLineCount;
@property (nonatomic) BOOL updatingUI;
@property (nonatomic) BOOL preserveRegistersOnNextLoad;
@property (nonatomic, copy) NSString *lastCardPath;
@property (nonatomic) NSInteger lastStripeIndex;

- (void)loadProgramFromPath:(NSString *)path preserveRegisters:(BOOL)preserve;
@end

@implementation PCSMachineWindowController

- (instancetype)init {
    NSRect frame = NSMakeRect(0, 0, 1240, 820);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:(NSWindowStyleMaskTitled |
                                                              NSWindowStyleMaskClosable |
                                                              NSWindowStyleMaskMiniaturizable |
                                                              NSWindowStyleMaskResizable)
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = @"Olivetti Programma 101";
    // Minimum content size that keeps every fixed/required element visible:
    // the two columns measure 1174 x 703 (left pane 440 + gap 18 + right pane
    // 680 + margins 36), so 1180 x 750 leaves a small safety margin.
    window.contentMinSize = NSMakeSize(1180, 750);
    self = [super initWithWindow:window];
    if (self) {
        _machine = [PCS101Machine new];
        _pendingRegister = @"M";
        _lastRoutine = @"V";
        _registerFields = [NSMutableDictionary dictionary];
        _lastPrinterLineCount = NSUIntegerMax;
        [self buildInterface];
        [self refresh];
        [window center];
    }
    return self;
}

#pragma mark - Construction

- (NSTextField *)labelWithString:(NSString *)text font:(NSFont *)font color:(NSColor *)color {
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = font;
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    return label;
}

- (NSButton *)buttonWithTitle:(NSString *)title action:(SEL)action {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.bezelStyle = NSBezelStyleRounded;
    button.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    return button;
}

- (NSScrollView *)newScrollViewWithTextView {
    NSTextView *textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 400, 400)];
    textView.editable = NO;
    textView.selectable = YES;
    textView.richText = NO;
    textView.font = [NSFont monospacedSystemFontOfSize:15 weight:NSFontWeightRegular];
    textView.textColor = [NSColor colorWithCalibratedWhite:0.08 alpha:1.0];
    textView.backgroundColor = [NSColor colorWithCalibratedRed:0.98 green:0.96 blue:0.88 alpha:1.0];
    textView.textContainerInset = NSMakeSize(8, 8);
    textView.minSize = NSMakeSize(0, 0);
    textView.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);
    textView.verticallyResizable = YES;
    textView.horizontallyResizable = NO;
    textView.textContainer.containerSize = NSMakeSize(FLT_MAX, FLT_MAX);
    textView.textContainer.widthTracksTextView = YES;

    NSScrollView *scroll = [[NSScrollView alloc] init];
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.borderType = NSBezelBorder;
    scroll.documentView = textView;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    return scroll;
}

- (NSBox *)boxWithTitle:(NSString *)title content:(NSView *)content {
    NSBox *box = [[NSBox alloc] init];
    box.title = title;
    box.titlePosition = NSAtTop;
    box.boxType = NSBoxPrimary;
    box.translatesAutoresizingMaskIntoConstraints = NO;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [box.contentView addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:box.contentView.leadingAnchor constant:8],
        [content.trailingAnchor constraintEqualToAnchor:box.contentView.trailingAnchor constant:-8],
        [content.topAnchor constraintEqualToAnchor:box.contentView.topAnchor constant:4],
        [content.bottomAnchor constraintEqualToAnchor:box.contentView.bottomAnchor constant:-8],
    ]];
    return box;
}

- (void)buildInterface {
    NSView *content = self.window.contentView;
    content.wantsLayer = YES;
    content.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.92 green:0.91 blue:0.88 alpha:1.0].CGColor;

    NSTextField *title = [self labelWithString:@"PROGRAMMA 101"
                                        font:[NSFont systemFontOfSize:26 weight:NSFontWeightBold]
                                       color:[NSColor colorWithCalibratedWhite:0.10 alpha:1.0]];
    NSTextField *subtitle = [self labelWithString:@"Olivetti · 1965 · Programmable desk computer"
                                           font:[NSFont systemFontOfSize:12 weight:NSFontWeightRegular]
                                          color:[NSColor colorWithCalibratedWhite:0.35 alpha:1.0]];

    _stateLabel = [self labelWithString:@"IDLE"
                                  font:[NSFont monospacedSystemFontOfSize:13 weight:NSFontWeightSemibold]
                                 color:[NSColor colorWithCalibratedRed:0.12 green:0.34 blue:0.16 alpha:1.0]];
    _pcLabel = [self labelWithString:@"PC 000    "
                               font:[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]
                              color:[NSColor colorWithCalibratedWhite:0.30 alpha:1.0]];
    _pendingLabel = [self labelWithString:@"Register: M"
                                    font:[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]
                                   color:[NSColor colorWithCalibratedWhite:0.30 alpha:1.0]];

    NSStackView *statusRow = [NSStackView stackViewWithViews:@[_stateLabel, _pcLabel, [NSView new], _pendingLabel]];
    statusRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    statusRow.spacing = 12;
    statusRow.distribution = NSStackViewDistributionFill;

    // Registers grid: a stack of rows so the value columns stretch with the
    // panel instead of pinning the window to a fixed width.
    NSArray<NSString *> *names = self.machine.registerNames;
    NSStackView *grid = [[NSStackView alloc] init];
    grid.orientation = NSUserInterfaceLayoutOrientationVertical;
    grid.alignment = NSLayoutAttributeLeading;
    grid.spacing = 3;

    for (NSUInteger i = 0; i < names.count; i += 2) {
        NSString *name1 = names[i];
        NSString *name2 = (i + 1 < names.count) ? names[i + 1] : @"";
        NSTextField *n1 = [self labelWithString:name1
                                          font:[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightBold]
                                         color:[NSColor colorWithCalibratedWhite:0.35 alpha:1.0]];
        NSTextField *v1 = [self labelWithString:@"0"
                                          font:[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]
                                         color:[NSColor blackColor]];
        NSTextField *n2 = [self labelWithString:name2
                                          font:[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightBold]
                                         color:[NSColor colorWithCalibratedWhite:0.35 alpha:1.0]];
        NSTextField *v2 = [self labelWithString:@"0"
                                          font:[NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular]
                                         color:[NSColor blackColor]];
        v1.lineBreakMode = NSLineBreakByTruncatingMiddle;
        v2.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [v1 setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
        [v2 setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
        if (name1.length) self.registerFields[name1] = v1;
        if (name2.length) self.registerFields[name2] = v2;

        NSStackView *row = [NSStackView stackViewWithViews:@[n1, v1, n2, v2]];
        row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        row.spacing = 8;
        row.distribution = NSStackViewDistributionFill;
        [n1.widthAnchor constraintEqualToConstant:22].active = YES;
        [n2.widthAnchor constraintEqualToConstant:22].active = YES;
        [v1.widthAnchor constraintEqualToAnchor:v2.widthAnchor].active = YES;
        [grid addArrangedSubview:row];
        [row.widthAnchor constraintEqualToAnchor:grid.widthAnchor].active = YES;
    }
    grid.translatesAutoresizingMaskIntoConstraints = NO;
    NSBox *registerBox = [self boxWithTitle:@"Registers" content:grid];

    // Controls
    _wheelPopUp = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    for (NSInteger i = 0; i <= 15; i++) {
        [_wheelPopUp addItemWithTitle:[NSString stringWithFormat:@"%ld", (long)i]];
    }
    [_wheelPopUp selectItemAtIndex:self.machine.decimalWheel];
    _wheelPopUp.target = self;
    _wheelPopUp.action = @selector(wheelChanged:);

    _recordCheckbox = [NSButton checkboxWithTitle:@"Record Program" target:self action:@selector(recordChanged:)];
    _recordCheckbox.font = [NSFont systemFontOfSize:12];

    NSStackView *wheelRow = [NSStackView stackViewWithViews:@[
        [self labelWithString:@"Decimal wheel"
                        font:[NSFont systemFontOfSize:12 weight:NSFontWeightMedium]
                       color:[NSColor colorWithCalibratedWhite:0.25 alpha:1.0]],
        _wheelPopUp,
        [NSView new],
        _recordCheckbox,
    ]];
    wheelRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    wheelRow.spacing = 8;

    NSButton *runButton = [self buttonWithTitle:@"Run / Continue" action:@selector(runMachine:)];
    NSButton *stepButton = [self buttonWithTitle:@"Step" action:@selector(stepMachine:)];
    NSButton *stopButton = [self buttonWithTitle:@"Stop" action:@selector(stopMachine:)];
    NSButton *resetButton = [self buttonWithTitle:@"Reset" action:@selector(resetMachine:)];
    NSStackView *runRow = [NSStackView stackViewWithViews:@[runButton, stepButton, stopButton, resetButton]];
    runRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    runRow.spacing = 8;
    runRow.distribution = NSStackViewDistributionFillEqually;

    NSButton *loadButton = [self buttonWithTitle:@"Load Program…" action:@selector(openProgram:)];
    NSButton *insertButton = [self buttonWithTitle:@"Insert Next Card…" action:@selector(insertCard:)];
    NSButton *saveButton = [self buttonWithTitle:@"Save Card…" action:@selector(saveCard:)];
    NSButton *printProgramButton = [self buttonWithTitle:@"Print Program" action:@selector(printProgram:)];
    NSStackView *fileRow = [NSStackView stackViewWithViews:@[loadButton, insertButton, saveButton, printProgramButton]];
    fileRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    fileRow.spacing = 8;
    fileRow.distribution = NSStackViewDistributionFillEqually;

    PCSKeyboardView *keyboard = [[PCSKeyboardView alloc] initWithFrame:NSZeroRect];
    keyboard.delegate = self;
    keyboard.translatesAutoresizingMaskIntoConstraints = NO;
    [keyboard.heightAnchor constraintEqualToConstant:252].active = YES;

    _entryField = [[NSTextField alloc] init];
    _entryField.placeholderString = @"Type a number, then Enter M";
    _entryField.font = [NSFont monospacedSystemFontOfSize:15 weight:NSFontWeightMedium];
    _entryField.target = self;
    _entryField.action = @selector(enterEntry:);
    _entryField.delegate = self;
    [_entryField.widthAnchor constraintEqualToConstant:210].active = YES;
    NSButton *enterButton = [self buttonWithTitle:@"Enter M" action:@selector(enterEntry:)];
    NSButton *clearEntryButton = [self buttonWithTitle:@"Clear Entry" action:@selector(clearEntry:)];
    NSStackView *entryRow = [NSStackView stackViewWithViews:@[
        [self labelWithString:@"Entry" font:[NSFont systemFontOfSize:12 weight:NSFontWeightMedium]
                        color:[NSColor colorWithCalibratedWhite:0.30 alpha:1.0]],
        _entryField, enterButton, clearEntryButton, [NSView new],
    ]];
    entryRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    entryRow.spacing = 8;

    _messageLabel = [self labelWithString:@"Load a .prg program or pick one from the Examples menu."
                                    font:[NSFont systemFontOfSize:11 weight:NSFontWeightRegular]
                                   color:[NSColor colorWithCalibratedWhite:0.35 alpha:1.0]];
    _messageLabel.maximumNumberOfLines = 2;

    NSStackView *right = [[NSStackView alloc] init];
    right.orientation = NSUserInterfaceLayoutOrientationVertical;
    right.alignment = NSLayoutAttributeLeading;
    right.spacing = 10;
    [right addArrangedSubview:title];
    [right addArrangedSubview:subtitle];
    [right addArrangedSubview:statusRow];
    [right addArrangedSubview:registerBox];
    [right addArrangedSubview:wheelRow];
    [right addArrangedSubview:runRow];
    [right addArrangedSubview:fileRow];
    [right addArrangedSubview:keyboard];
    [right addArrangedSubview:entryRow];
    [right addArrangedSubview:_messageLabel];

    for (NSView *view in @[registerBox, wheelRow, runRow, fileRow, keyboard, entryRow]) {
        [view.widthAnchor constraintEqualToAnchor:right.widthAnchor].active = YES;
    }

    // Paper + listing
    NSScrollView *printerScroll = [self newScrollViewWithTextView];
    self.printerView = (NSTextView *)printerScroll.documentView;
    NSTextField *printerLabel = [self labelWithString:@"PRINTED TAPE"
                                                 font:[NSFont systemFontOfSize:11 weight:NSFontWeightSemibold]
                                                color:[NSColor colorWithCalibratedWhite:0.35 alpha:1.0]];
    NSScrollView *listingScroll = [self newScrollViewWithTextView];
    self.listingView = (NSTextView *)listingScroll.documentView;
    _listingView.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    NSTextField *listingLabel = [self labelWithString:@"PROGRAM LISTING"
                                                 font:[NSFont systemFontOfSize:11 weight:NSFontWeightSemibold]
                                                color:[NSColor colorWithCalibratedWhite:0.35 alpha:1.0]];

    NSStackView *left = [[NSStackView alloc] init];
    left.orientation = NSUserInterfaceLayoutOrientationVertical;
    left.alignment = NSLayoutAttributeLeading;
    left.spacing = 8;
    [left addArrangedSubview:printerLabel];
    [left addArrangedSubview:printerScroll];
    [left addArrangedSubview:listingLabel];
    [left addArrangedSubview:listingScroll];
    [printerScroll.heightAnchor constraintGreaterThanOrEqualToConstant:440].active = YES;
    [listingScroll.heightAnchor constraintEqualToConstant:170].active = YES;
    for (NSView *view in @[printerScroll, listingScroll]) {
        [view.widthAnchor constraintEqualToAnchor:left.widthAnchor].active = YES;
    }
    [left.widthAnchor constraintEqualToConstant:440].active = YES;

    // Pin the two columns directly to the content view. The control column
    // keeps its natural height at the top; the paper pane on the left absorbs
    // any extra window height instead of leaving a gap.
    NSView *rightPane = [[NSView alloc] init];
    rightPane.translatesAutoresizingMaskIntoConstraints = NO;
    right.translatesAutoresizingMaskIntoConstraints = NO;
    [rightPane addSubview:right];
    left.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:left];
    [content addSubview:rightPane];
    [NSLayoutConstraint activateConstraints:@[
        [left.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:18],
        [left.topAnchor constraintEqualToAnchor:content.topAnchor constant:16],
        [left.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-14],
        [rightPane.leadingAnchor constraintEqualToAnchor:left.trailingAnchor constant:18],
        [rightPane.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-18],
        [rightPane.topAnchor constraintEqualToAnchor:content.topAnchor constant:16],
        [rightPane.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-14],
        [rightPane.widthAnchor constraintGreaterThanOrEqualToConstant:680],
        [right.leadingAnchor constraintEqualToAnchor:rightPane.leadingAnchor],
        [right.trailingAnchor constraintEqualToAnchor:rightPane.trailingAnchor],
        [right.topAnchor constraintEqualToAnchor:rightPane.topAnchor],
        [right.bottomAnchor constraintLessThanOrEqualToAnchor:rightPane.bottomAnchor],
    ]];
}

#pragma mark - UI refresh

- (NSString *)stateName {
    switch (self.machine.state) {
        case PCS101StateIdle: return @"IDLE";
        case PCS101StateRunning: return @"RUNNING";
        case PCS101StateWaitingForInput: return @"READY FOR INPUT";
        case PCS101StateHalted: return @"PROGRAM ENDED";
        case PCS101StateError: return @"ERROR";
    }
    return @"?";
}

- (void)refresh {
    if (self.updatingUI) return;
    self.updatingUI = YES;

    self.stateLabel.stringValue = [self stateName];
    NSString *instruction = self.machine.currentInstructionText ?: @"---";
    if (self.machine.state == PCS101StateError) {
        self.stateLabel.textColor = [NSColor systemRedColor];
    } else if (self.machine.state == PCS101StateWaitingForInput) {
        self.stateLabel.textColor = [NSColor colorWithCalibratedRed:0.55 green:0.35 blue:0.05 alpha:1.0];
    } else if (self.machine.state == PCS101StateRunning) {
        self.stateLabel.textColor = [NSColor colorWithCalibratedRed:0.05 green:0.35 blue:0.55 alpha:1.0];
    } else {
        self.stateLabel.textColor = [NSColor colorWithCalibratedRed:0.12 green:0.34 blue:0.16 alpha:1.0];
    }
    self.pcLabel.stringValue = [NSString stringWithFormat:@"PC %03ld   %@",
                                (long)self.machine.programCounter,
                                instruction];
    self.pendingLabel.stringValue = [NSString stringWithFormat:@"Register: %@", self.pendingRegister];

    NSArray<NSString *> *printerLines = self.machine.printerLines;
    if (printerLines.count != self.lastPrinterLineCount) {
        self.printerView.string = [printerLines componentsJoinedByString:@"\n"];
        [self.printerView scrollRangeToVisible:NSMakeRange(self.printerView.string.length, 0)];
        self.lastPrinterLineCount = printerLines.count;
    }

    PCS101Program *program = self.machine.program;
    self.listingView.string = program ? [self numberedListingForProgram:program] : @"";
    self.wheelPopUp.enabled = YES;
    [self.wheelPopUp selectItemAtIndex:self.machine.decimalWheel];
    self.recordCheckbox.state = self.machine.recordMode ? NSControlStateValueOn : NSControlStateValueOff;

    for (NSString *name in self.registerFields) {
        NSTextField *field = self.registerFields[name];
        field.stringValue = [[self.machine valueForRegister:name] stringValue];
    }

    if (self.machine.state == PCS101StateWaitingForInput) {
        _entryField.placeholderString = @"Program stopped — enter value, then Continue";
        self.messageLabel.stringValue = @"The program is waiting at a Stop instruction. Type a number, press Enter M, then Run / Continue (or S).";
    } else if (self.machine.state == PCS101StateError) {
        self.messageLabel.stringValue = self.machine.errorMessage ?: @"Machine error.";
    } else if (self.machine.state == PCS101StateRunning) {
        self.messageLabel.stringValue = @"Running…";
    } else if (!program) {
        self.messageLabel.stringValue = @"Load a .prg program or pick one from the Examples menu.";
    } else {
        self.messageLabel.stringValue = @"Ready. Press Run to start at the selected routine (V by default).";
    }

    self.updatingUI = NO;
}

- (NSString *)numberedListingForProgram:(PCS101Program *)program {
    NSMutableString *out = [NSMutableString string];
    NSInteger index = 0;
    for (PCS101Instruction *instruction in program.instructions) {
        [out appendFormat:@"%03ld   %@\n", (long)index++, instruction.text];
    }
    if (program.constants.count > 0) {
        [out appendString:@"\nCard constants:\n"];
        for (NSString *key in [program.constants.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            NSString *display = [key isEqualToString:[key lowercaseString]]
                ? [[key uppercaseString] stringByAppendingString:@"/"] : [key uppercaseString];
            [out appendFormat:@"  %@ = %@\n", display, [program.constants[key] stringValue]];
        }
    }
    return out;
}

#pragma mark - Timer

- (void)startTimer {
    if (self.timer) return;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.05
                                                  target:self
                                                selector:@selector(tick:)
                                                userInfo:nil
                                                 repeats:YES];
    self.timer.tolerance = 0.01;
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)stopTimer {
    [self.timer invalidate];
    self.timer = nil;
}

- (void)tick:(NSTimer *)timer {
    if (self.machine.state != PCS101StateRunning) {
        [self stopTimer];
        [self refresh];
        return;
    }
    [self.machine step];
    [self refresh];
    if (self.machine.state != PCS101StateRunning) [self stopTimer];
}

#pragma mark - Actions

- (void)startRoutine:(NSString *)routine {
    NSError *error = nil;
    if (![self.machine startAtRoutine:routine error:&error]) {
        [self showAlertForError:error];
        return;
    }
    self.lastRoutine = routine;
    [self startTimer];
    [self refresh];
}

- (IBAction)runMachine:(id)sender {
    if (self.machine.state == PCS101StateWaitingForInput) {
        [self enterEntry:nil];
        [self.machine continueWithInput:nil];
        [self startTimer];
        [self refresh];
        return;
    }
    if (self.machine.state == PCS101StateRunning) {
        [self startTimer];
        return;
    }
    if (!self.machine.program) {
        self.messageLabel.stringValue = @"Load a program first.";
        return;
    }
    [self startRoutine:self.lastRoutine ?: @"V"];
}

- (IBAction)stepMachine:(id)sender {
    if (self.machine.state == PCS101StateIdle ||
        self.machine.state == PCS101StateHalted ||
        self.machine.state == PCS101StateError) {
        NSError *error = nil;
        if (![self.machine startAtRoutine:self.lastRoutine ?: @"V" error:&error]) {
            [self showAlertForError:error];
            return;
        }
    } else if (self.machine.state == PCS101StateWaitingForInput) {
        [self enterEntry:nil];
        [self.machine continueWithInput:nil];
    }
    [self.machine step];
    [self refresh];
}

- (IBAction)stopMachine:(id)sender {
    [self stopTimer];
    [self.machine stop];
    [self refresh];
}

- (IBAction)resetMachine:(id)sender {
    [self stopTimer];
    [self.machine reset];
    self.pendingRegister = @"M";
    self.lastPrinterLineCount = NSUIntegerMax;
    [self refresh];
}

- (IBAction)printProgram:(id)sender {
    [self.machine printProgram];
    [self refresh];
}

- (IBAction)openProgram:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = NO;
    panel.allowsOtherFileTypes = YES;
    panel.message = @"Choose a Programma 101 program or magnetic-card file";
    BOOL preserve = self.preserveRegistersOnNextLoad;
    self.preserveRegistersOnNextLoad = NO;
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK && panel.URL.path) {
            [self loadProgramFromPath:panel.URL.path preserveRegisters:preserve];
        }
    }];
}

- (IBAction)insertCard:(id)sender {
    self.preserveRegistersOnNextLoad = YES;
    [self openProgram:sender];
}

- (IBAction)saveCard:(id)sender {
    PCS101Program *program = self.machine.program;
    if (!program) {
        self.messageLabel.stringValue = @"There is no program to record.";
        return;
    }
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowsOtherFileTypes = YES;
    panel.nameFieldStringValue = @"programma101-card.p101card";
    panel.message = @"Record the program and its D/E/F constants onto a virtual magnetic card";
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result != NSModalResponseOK || !panel.URL) return;
        // The first 48 instructions live in p1/p2, so all of D/d/E/e/F/f are
        // available for numeric constants. Longer programs overflow into those
        // registers on real hardware; in that case record only the constants
        // declared by the listing rather than inventing a mixed snapshot.
        NSDictionary<NSString *, PCSNumber *> *snapshot = nil;
        if (program.instructions.count <= 48) {
            snapshot = @{
                @"D": [self.machine valueForRegister:@"D"],
                @"d": [self.machine valueForRegister:@"d"],
                @"E": [self.machine valueForRegister:@"E"],
                @"e": [self.machine valueForRegister:@"e"],
                @"F": [self.machine valueForRegister:@"F"],
                @"f": [self.machine valueForRegister:@"f"],
            };
        }
        PCSCard *card = [PCSCard cardWithProgram:program constants:snapshot];
        NSError *error = nil;
        if (![[card textRepresentation] writeToURL:panel.URL atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
            [self showAlertForError:error];
        } else {
            self.messageLabel.stringValue = [NSString stringWithFormat:@"Recorded card: %@", panel.URL.lastPathComponent];
        }
    }];
}

- (void)loadProgramFromPath:(NSString *)path {
    [self loadProgramFromPath:path preserveRegisters:NO];
}

- (void)loadProgramFromPath:(NSString *)path preserveRegisters:(BOOL)preserve {
    NSError *error = nil;
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (!text) {
        [self showAlertForError:error];
        return;
    }
    PCSCard *card = [PCSCard cardWithText:text error:&error];
    if (!card) {
        [self showAlertForError:error];
        return;
    }
    // Picking the same two-stripe card file again during “Insert Next Card…”
    // advances to the second stripe; picking a different file starts at stripe 1.
    NSInteger stripeIndex = 0;
    if (preserve && [path isEqualToString:self.lastCardPath] &&
        (NSUInteger)(self.lastStripeIndex + 1) < card.stripes.count) {
        stripeIndex = self.lastStripeIndex + 1;
    }
    PCS101Program *program = [card programForStripe:stripeIndex];
    if (!program) {
        [self showAlertForError:[NSError errorWithDomain:PCSCardErrorDomain code:2
                                           userInfo:@{NSLocalizedDescriptionKey: @"The card has no program stripe."}]];
        return;
    }
    self.lastCardPath = path;
    self.lastStripeIndex = stripeIndex;
    [self stopTimer];
    if (![self.machine loadProgram:program preserveRegisters:preserve error:&error]) {
        [self showAlertForError:error];
        return;
    }
    self.lastRoutine = @"V";
    for (NSString *routine in @[@"V", @"W", @"Y", @"Z"]) {
        NSString *label = [NSString stringWithFormat:@"A %@", routine];
        if ([program indexOfLabelText:label]) {
            self.lastRoutine = routine;
            break;
        }
    }
    self.pendingRegister = @"M";
    if (!preserve) self.lastPrinterLineCount = NSUIntegerMax;
    [self refresh];
    self.messageLabel.stringValue = [NSString stringWithFormat:
        @"%@ %@ (stripe %ld) — %lu instructions. Press Run to begin at routine %@%@.",
        preserve ? @"Inserted" : @"Loaded",
        path.lastPathComponent, (long)(stripeIndex + 1),
        (unsigned long)program.instructions.count, self.lastRoutine,
        preserve ? @"; data registers preserved" : @""];
    [self.window makeFirstResponder:self.window.contentView];
}

- (void)loadExampleFromPath:(NSString *)path {
    [self loadProgramFromPath:path];
}

- (void)showAlertForError:(NSError *)error {
    if (!error) return;
    self.messageLabel.stringValue = error.localizedDescription;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = @"Programma 101";
    alert.informativeText = error.localizedDescription ?: @"Unknown error.";
    [alert beginSheetModalForWindow:self.window completionHandler:nil];
}

#pragma mark - Controls

- (IBAction)wheelChanged:(NSPopUpButton *)sender {
    self.machine.decimalWheel = sender.indexOfSelectedItem;
    [self refresh];
}

- (IBAction)recordChanged:(NSButton *)sender {
    self.machine.recordMode = (sender.state == NSControlStateValueOn);
    [self refresh];
}

- (IBAction)enterEntry:(id)sender {
    NSString *text = [self.entryField.stringValue stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length > 0) {
        PCSNumber *number = [PCSNumber numberWithString:text];
        if (!number) {
            self.messageLabel.stringValue = @"Invalid number.";
            return;
        }
        [self.machine setValue:number forRegister:@"M"];
        [self.machine clearEntry];
        [self.machine setValue:number forRegister:@"M"];
        self.entryField.stringValue = @"";
        self.messageLabel.stringValue = [NSString stringWithFormat:@"M = %@", [number stringValue]];
    }
    [self refresh];
}

- (IBAction)clearEntry:(id)sender {
    [self.machine clearEntry];
    self.entryField.stringValue = @"";
    [self refresh];
}

#pragma mark - Keyboard

- (BOOL)isRegisterKey:(NSString *)key {
    return [key isEqualToString:@"M"] || [key isEqualToString:@"R"] ||
           (key.length == 1 && [key characterAtIndex:0] >= 'A' && [key characterAtIndex:0] <= 'F');
}

- (BOOL)isOperatorKey:(NSString *)key {
    return [@"+-*:#^$&!%S/VWYZ" containsString:key];
}

- (NSString *)instructionTextForRegister:(NSString *)reg operation:(NSString *)op {
    unichar key1 = ' ';
    unichar key2 = ' ';
    if ([reg isEqualToString:@"/"]) {
        key2 = '/';
    } else if (![reg isEqualToString:@"M"] && reg.length > 0) {
        unichar c = [reg characterAtIndex:0];
        if (c >= 'a' && c <= 'f') {
            key1 = c - 32;
            key2 = '/';
        } else {
            key1 = c;
        }
    }
    unichar opChar = [op characterAtIndex:0];
    switch (opChar) {
        case 0x00D7: opChar = '*'; break;
        case 0x00F7: opChar = ':'; break;
        case 0x221A: opChar = '#'; break;
        default: break;
    }
    return [NSString stringWithFormat:@"%c%c%c", key1, key2, opChar];
}

- (void)keyboardView:(id)keyboardView didPressKey:(NSString *)key {
    if (key.length == 1) {
        unichar c = [key characterAtIndex:0];
        if (c >= '0' && c <= '9') {
            if (self.machine.recordMode) return;
            [self.machine entryDigit:key];
            self.entryField.stringValue = self.machine.entryString;
            [self refresh];
            return;
        }
    }

    if ([key isEqualToString:@"."]) {
        if (self.machine.recordMode) return;
        [self.machine entryDecimalPoint];
        self.entryField.stringValue = self.machine.entryString;
        [self refresh];
        return;
    }
    if ([key isEqualToString:@"±"]) {
        [self.machine toggleEntrySign];
        self.entryField.stringValue = self.machine.entryString;
        [self refresh];
        return;
    }

    if ([key isEqualToString:@"/"]) {
        NSString *pending = self.pendingRegister ?: @"M";
        // Only B–F have left/right halves; A, M and R are never split.
        BOOL canSplit = (pending.length == 1 &&
                         [pending characterAtIndex:0] >= 'B' &&
                         [pending characterAtIndex:0] <= 'F');
        self.pendingRegister = canSplit ? [pending lowercaseString] : @"/";
        [self refresh];
        return;
    }

    if ([self isRegisterKey:key]) {
        self.pendingRegister = key;
        [self refresh];
        return;
    }

    if ([key isEqualToString:@"S"]) {
        if (self.machine.recordMode) {
            NSString *text = [self.pendingRegister isEqualToString:@"R"]
                ? @"R/S"
                : [self instructionTextForRegister:@"M" operation:@"S"];
            NSError *error = nil;
            if (![self.machine appendInstructionText:text error:&error]) {
                [self showAlertForError:error];
            }
            [self refresh];
            return;
        }
        if (self.machine.state == PCS101StateWaitingForInput) {
            [self runMachine:nil];
        } else if (self.machine.state == PCS101StateRunning) {
            [self stopMachine:nil];
        } else {
            [self runMachine:nil];
        }
        return;
    }

    if ([key isEqualToString:@"V"] || [key isEqualToString:@"W"] ||
        [key isEqualToString:@"Y"] || [key isEqualToString:@"Z"]) {
        if (self.machine.recordMode) {
            NSError *error = nil;
            NSString *text = [self instructionTextForRegister:self.pendingRegister operation:key];
            if (![self.machine appendInstructionText:text error:&error]) [self showAlertForError:error];
            [self refresh];
            return;
        }
        [self startRoutine:key];
        return;
    }

    if ([self isOperatorKey:key]) {
        if (self.machine.recordMode) {
            NSError *error = nil;
            NSString *text = [self instructionTextForRegister:self.pendingRegister operation:key];
            if (![self.machine appendInstructionText:text error:&error]) {
                [self showAlertForError:error];
            }
            [self refresh];
            return;
        }
        if (self.machine.state == PCS101StateRunning) {
            self.messageLabel.stringValue = @"Stop the program before using the keyboard manually.";
            return;
        }
        NSError *error = nil;
        if (![self.machine executeManualInstructionWithRegister:self.pendingRegister
                                                      operation:key
                                                          error:&error]) {
            if (self.machine.state == PCS101StateError) [self showAlertForError:error];
            else self.messageLabel.stringValue = error.localizedDescription;
        }
        [self refresh];
        return;
    }
}

@end
