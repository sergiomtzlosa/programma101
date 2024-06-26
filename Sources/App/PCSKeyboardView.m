#import "PCSKeyboardView.h"

@implementation PCSKeyboardView

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        [self buildKeyboard];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self buildKeyboard];
    }
    return self;
}

- (NSString *)titleForKey:(NSString *)key {
    static NSDictionary<NSString *, NSString *> *titles;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        titles = @{@"*": @"×", @":": @"÷", @"#": @"√", @"^": @"↑",
                   @"$": @"↓", @"&": @"↕", @"!": @"✱", @"%": @"♢",
                   @"-": @"−", @"S": @"S", @"/": @"/", @"+": @"+"};
    });
    return titles[key] ?: key;
}

- (void)buildKeyboard {
    NSArray<NSArray<NSString *> *> *rows = @[
        @[@"7", @"8", @"9", @":", @"#", @"^"],
        @[@"4", @"5", @"6", @"*", @"&", @"$"],
        @[@"1", @"2", @"3", @"-", @"%", @"!"],
        @[@"0", @".", @"±", @"+", @"S", @"/"],
        @[@"A", @"B", @"C", @"D", @"E", @"F"],
        @[@"R", @"M", @"V", @"W", @"Y", @"Z"],
    ];

    NSStackView *column = [[NSStackView alloc] init];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.spacing = 6;
    column.distribution = NSStackViewDistributionFillEqually;
    column.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:column];

    for (NSArray<NSString *> *rowKeys in rows) {
        NSStackView *row = [[NSStackView alloc] init];
        row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        row.spacing = 6;
        row.distribution = NSStackViewDistributionFillEqually;
        for (NSString *key in rowKeys) {
            NSButton *button = [NSButton buttonWithTitle:[self titleForKey:key]
                                                  target:self
                                                  action:@selector(pressKey:)];
            button.bezelStyle = NSBezelStyleRounded;
            button.font = [NSFont monospacedSystemFontOfSize:15 weight:NSFontWeightMedium];
            button.identifier = key;
            button.toolTip = [self tooltipForKey:key];
            [row addArrangedSubview:button];
        }
        [column addArrangedSubview:row];
    }

    [NSLayoutConstraint activateConstraints:@[
        [column.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [column.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [column.topAnchor constraintEqualToAnchor:self.topAnchor],
        [column.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];
}

- (NSString *)tooltipForKey:(NSString *)key {
    static NSDictionary<NSString *, NSString *> *tips;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        tips = @{@"^": @"↑  Copy M into the selected register",
                 @"$": @"↓  Copy the selected register into A",
                 @"&": @"↕  Exchange A with the register (A↕ = absolute value)",
                 @"!": @"✱  Clear the selected register",
                 @"%": @"♢  Print the selected register ( /♢ = blank line)",
                 @"S": @"S  Stop / continue",
                 @"V": @"V  Start routine V",
                 @"W": @"W  Start routine W",
                 @"Y": @"Y  Start routine Y",
                 @"Z": @"Z  Start routine Z",
                 @"/": @"/  Split-register modifier",
                 @"±": @"Change the sign of the current entry",
                 @"A": @"A register", @"B": @"B register", @"C": @"C register",
                 @"D": @"D register", @"E": @"E register", @"F": @"F register",
                 @"R": @"R register", @"M": @"M register"};
    });
    return tips[key];
}

- (void)pressKey:(NSButton *)sender {
    NSString *key = sender.identifier;
    if (!key) return;
    [self.delegate keyboardView:self didPressKey:key];
}

@end
