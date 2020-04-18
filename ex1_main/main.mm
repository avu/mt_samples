#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

constexpr int W = 800;
constexpr int H = 800;

@interface OSXMetalView : NSView
@end

@implementation OSXMetalView {
@public
    CVDisplayLinkRef _displayLink;
}

static CVReturn OnDisplayLinkFrame(CVDisplayLinkRef displayLink,
                                   const CVTimeStamp *now,
                                   const CVTimeStamp *outputTime,
                                   CVOptionFlags flagsIn,
                                   CVOptionFlags *flagsOut,
                                   void *displayLinkContext) {
    OSXMetalView *view = (__bridge OSXMetalView *) displayLinkContext;

    @autoreleasepool {
        [view update];
    }

    return kCVReturnSuccess;
}

+ (Class)layerClass {
    return [CAMetalLayer class];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];

    if (self) {
        self.wantsLayer = YES;
        self.layer = [CAMetalLayer layer];

        NSError *error = nil;


        CVReturn cvReturn = CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);

        cvReturn = CVDisplayLinkSetOutputCallback(_displayLink, &OnDisplayLinkFrame, (__bridge void *) self);
        cvReturn = CVDisplayLinkSetCurrentCGDisplay(_displayLink, CGMainDisplayID());

        CVDisplayLinkStart(_displayLink);

        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

        [notificationCenter addObserver:self
                               selector:@selector(windowWillClose:)
                                   name:NSWindowWillCloseNotification
                                 object:self.window];
    }

    return self;
}

- (void)dealloc {
    if (_displayLink) {
        [self stopUpdate];
    }
}

- (void)windowWillClose:(NSNotification *)notification {
// Stop the display link when the window is closing because we will
// not be able to get a drawable, but the display link may continue
// to fire
    if (notification.object == self.window) {
        CVDisplayLinkStop(_displayLink);
    }
}

- (void)update {
    NSLog(@"Hello");
}

- (void)stopUpdate {
    if (_displayLink) {
        CVDisplayLinkStop(_displayLink);
        CVDisplayLinkRelease(_displayLink);
    }
}

@end

int main () {
    @autoreleasepool {
            [NSApplication sharedApplication];
            [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

            NSRect frame = NSMakeRect(0, 0, W, H);
            NSWindow* window = [[NSWindow alloc]
            initWithContentRect:frame styleMask:NSTitledWindowMask
            backing:NSBackingStoreBuffered defer:NO];
            [window cascadeTopLeftFromPoint:NSMakePoint(20,20)];
            window.title = [[NSProcessInfo processInfo] processName];
            OSXMetalView* view = [[OSXMetalView alloc] initWithFrame:frame];
            window.contentView = view;
            view.needsDisplay = YES;

            [window makeKeyAndOrderFront:nil];

            [NSApp activateIgnoringOtherApps:YES];
            [NSApp run];
    }
    return 0;
}
