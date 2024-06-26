#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@protocol PCSKeyboardViewDelegate <NSObject>
- (void)keyboardView:(id)keyboardView didPressKey:(NSString *)key;
@end

/// The 36-key Programma 101 keyboard, drawn with AppKit buttons.
@interface PCSKeyboardView : NSView

@property (nonatomic, weak, nullable) id<PCSKeyboardViewDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
