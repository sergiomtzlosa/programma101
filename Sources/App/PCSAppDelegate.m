#import "PCSAppDelegate.h"
#import "PCSMachineWindowController.h"

@implementation PCSAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.windowController = [[PCSMachineWindowController alloc] init];
    [self.windowController showWindow:nil];
    [self buildMenu];
    [NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

#pragma mark - Menu

- (NSMenuItem *)itemWithTitle:(NSString *)title action:(SEL)action key:(NSString *)key {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:key];
    item.target = self;
    return item;
}

- (void)buildMenu {
    NSMenu *mainMenu = [[NSMenu alloc] init];

    // Application menu
    NSMenuItem *appItem = [[NSMenuItem alloc] init];
    NSMenu *appMenu = [[NSMenu alloc] init];
    appMenu.title = @"Programma 101";
    [appMenu addItemWithTitle:@"About Programma 101" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Hide Programma 101" action:@selector(hide:) keyEquivalent:@"h"];
    NSMenuItem *hideOthers = [[NSMenuItem alloc] initWithTitle:@"Hide Others"
                                                        action:@selector(hideOtherApplications:)
                                                 keyEquivalent:@"h"];
    hideOthers.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagOption;
    [appMenu addItem:hideOthers];
    [appMenu addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Quit Programma 101" action:@selector(terminate:) keyEquivalent:@"q"];
    appItem.submenu = appMenu;
    [mainMenu addItem:appItem];

    // File menu
    NSMenuItem *fileItem = [[NSMenuItem alloc] init];
    NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
    [fileMenu addItem:[self itemWithTitle:@"Load Program…" action:@selector(forwardOpenProgram:) key:@"o"]];
    [fileMenu addItem:[self itemWithTitle:@"Insert Next Card…" action:@selector(forwardInsertCard:) key:@""]];
    [fileMenu addItem:[self itemWithTitle:@"Save Card…" action:@selector(forwardSaveCard:) key:@"s"]];
    [fileMenu addItem:[NSMenuItem separatorItem]];
    [fileMenu addItemWithTitle:@"Close Window" action:@selector(performClose:) keyEquivalent:@"w"];
    fileItem.submenu = fileMenu;
    [mainMenu addItem:fileItem];

    // Machine menu
    NSMenuItem *machineItem = [[NSMenuItem alloc] init];
    NSMenu *machineMenu = [[NSMenu alloc] initWithTitle:@"Machine"];
    [machineMenu addItem:[self itemWithTitle:@"Run / Continue" action:@selector(forwardRun:) key:@"r"]];
    [machineMenu addItem:[self itemWithTitle:@"Step" action:@selector(forwardStep:) key:@"."]];
    [machineMenu addItem:[self itemWithTitle:@"Stop" action:@selector(forwardStop:) key:@""]];
    NSMenuItem *resetItem = [self itemWithTitle:@"Reset" action:@selector(forwardReset:) key:@"r"];
    resetItem.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [machineMenu addItem:resetItem];
    [machineMenu addItem:[NSMenuItem separatorItem]];
    [machineMenu addItem:[self itemWithTitle:@"Print Program" action:@selector(forwardPrintProgram:) key:@"p"]];
    machineItem.submenu = machineMenu;
    [mainMenu addItem:machineItem];

    // Examples menu
    NSMenuItem *examplesItem = [[NSMenuItem alloc] init];
    NSMenu *examplesMenu = [[NSMenu alloc] initWithTitle:@"Examples"];
    NSArray<NSURL *> *urls = [[NSBundle mainBundle] URLsForResourcesWithExtension:@"prg" subdirectory:@"examples"];
    urls = [urls sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
        return [a.lastPathComponent compare:b.lastPathComponent];
    }];
    for (NSURL *url in urls) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:url.lastPathComponent
                                                      action:@selector(loadExample:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = url.path;
        [examplesMenu addItem:item];
    }
    if (urls.count == 0) {
        NSMenuItem *empty = [[NSMenuItem alloc] initWithTitle:@"No example programs found"
                                                       action:NULL keyEquivalent:@""];
        empty.enabled = NO;
        [examplesMenu addItem:empty];
    }
    examplesItem.submenu = examplesMenu;
    [mainMenu addItem:examplesItem];

    // Window menu
    NSMenuItem *windowItem = [[NSMenuItem alloc] init];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    [windowMenu addItemWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"Zoom" action:@selector(performZoom:) keyEquivalent:@""];
    [windowMenu addItem:[NSMenuItem separatorItem]];
    [windowMenu addItemWithTitle:@"Bring All to Front" action:@selector(arrangeInFront:) keyEquivalent:@""];
    windowItem.submenu = windowMenu;
    [mainMenu addItem:windowItem];
    NSApp.windowsMenu = windowMenu;

    NSApp.mainMenu = mainMenu;
}

- (void)loadExample:(NSMenuItem *)sender {
    NSString *path = sender.representedObject;
    if (path) [self.windowController loadExampleFromPath:path];
}

- (void)forwardOpenProgram:(id)sender {
    [self.windowController openProgram:sender];
}

- (void)forwardInsertCard:(id)sender {
    [self.windowController insertCard:sender];
}

- (void)forwardSaveCard:(id)sender {
    [self.windowController saveCard:sender];
}

- (void)forwardRun:(id)sender {
    [self.windowController runMachine:sender];
}

- (void)forwardStep:(id)sender {
    [self.windowController stepMachine:sender];
}

- (void)forwardStop:(id)sender {
    [self.windowController stopMachine:sender];
}

- (void)forwardReset:(id)sender {
    [self.windowController resetMachine:sender];
}

- (void)forwardPrintProgram:(id)sender {
    [self.windowController printProgram:sender];
}

@end
