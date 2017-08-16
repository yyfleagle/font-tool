//
//  ShapingWindowController.m
//  tx-research
//
//  Created by Yuqing Jiang on 6/5/17.
//
//
#import "CharEncoding.h"
#import "Shapper.h"
#import "ShapingWindowController.h"
#import "TypefaceDocument.h"
#import "TypefaceNames.h"
#import "GlyphInfoViewController.h"

typedef NS_ENUM(NSInteger, ShapingViewOption) {
    ShapingViewShowMetricsLines = 1 << 0,
    ShapingViewShowGlyphOrigin  = 1 << 1,
};


@interface ShapingView ()
@property TypefaceDocument * document;
@property Shapper * shapper;
@property Typeface * face;
@property NSMutableArray<TypefaceGlyph *> * glyphs;

@property (nonatomic, getter=getFontSize, setter=setFontSize:) CGFloat fontSize;
@property (nonatomic, getter=setOptions, setter=setOptions:) ShapingViewOption options;
- (void)reload;
- (void)windowDidResize;

@property NSPoint lastClickLocation;

@end

#define FONT_SIZE 120

#define MARGIN_LEFT  20
#define MARGIN_RIGHT 20
#define MARGIN_TOP   50
#define MARGIN_BOTTOM 20
#define BASELINE_OFFSET_X 80
#define BASELINE_OFFSET_Y 100
#define GLYPH_TABLE_HEIGHT BASELINE_OFFSET_Y
#define GLYPH_TABLE_ROWS 5
#define GLYPH_TABLE_ROW_HEIGHT (GLYPH_TABLE_HEIGHT/GLYPH_TABLE_ROWS)

typedef struct {
    CGPoint  origin;
    CGVector offset;
    CGVector advance;
    CGRect   fullBounds;
} GlyphDrawingMetrics;

@implementation ShapingView
@synthesize fontSize = _fontSize;
@synthesize options = _options;

- (void)awakeFromNib
{
    [self setupViewToInitState];
}
- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self setupViewToInitState];
    }
    return self;
}

- (id)initWithFrame:(NSRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setupViewToInitState];
    }
    return self;
}

- (void)setupViewToInitState {
    [self setAutoresizingMask:NSViewNotSizable];
    _fontSize = FONT_SIZE;
    _options = ShapingViewShowGlyphOrigin | ShapingViewShowMetricsLines;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (CGPoint)baselineOrigin {
    CGFloat descender = [self fontUnitToPixel:self.face.descender];
    return CGPointMake(MARGIN_LEFT + BASELINE_OFFSET_X, MARGIN_BOTTOM  + BASELINE_OFFSET_Y - descender);
}

- (void)enumerateGlyphs:(BOOL (^)(GlyphDrawingMetrics metrics, NSUInteger index)) handler {
    CGPoint origin = self.baselineOrigin;
    CGPoint p = origin;
    
    CGFloat colMaxY = self.bounds.size.height;
    CGFloat colMinY = MARGIN_BOTTOM + GLYPH_TABLE_ROW_HEIGHT;
    
    for (NSUInteger index = 0; index < self.glyphs.count; ++ index) {
        CGVector advance = [self fontUnitToPixelVector:[self.shapper glyphAdvanceAtIndex:index]];
        
        GlyphDrawingMetrics metrics;
        metrics.origin = p;
        metrics.advance = advance;
        metrics.offset = [self fontUnitToPixelVector:[self.shapper glyphOffsetAtIndex:index]];
        metrics.fullBounds = CGRectMake(p.x, colMinY, advance.dx, colMaxY - colMinY);
        
        BOOL continueLoop = handler(metrics, index);
        if (!continueLoop)
            break;
        
        p.x += advance.dx;
        p.y += advance.dy;
    }
}

- (void)enumerateTableCells:(BOOL (^)(GlyphDrawingMetrics metrics, NSUInteger index, CGRect * cellRects, NSUInteger count)) handler {
    NSFont * font = [self tableFont];
    CGFloat textHeight = font.pointSize;
    
    [self enumerateGlyphs:^BOOL(GlyphDrawingMetrics metrics, NSUInteger index) {
        CGFloat cellAdvance = metrics.advance.dx;
        CGFloat x = metrics.origin.x;
        CGFloat newX = x + cellAdvance;
        
        CGRect (^getCellRect)(NSUInteger) = ^(NSUInteger cell){
            return NSMakeRect(x, MARGIN_BOTTOM + GLYPH_TABLE_HEIGHT - (cell + 1) * GLYPH_TABLE_ROW_HEIGHT + (GLYPH_TABLE_ROW_HEIGHT - textHeight) / 2, metrics.advance.dx, textHeight);
        };
        
        CGRect rects[5];
        rects[0] = getCellRect(0);
        rects[1] = getCellRect(1);
        rects[2] = getCellRect(2);
        rects[3] = getCellRect(3);
        rects[4] = NSMakeRect((x + newX)/2, MARGIN_BOTTOM + (GLYPH_TABLE_ROW_HEIGHT - textHeight) / 2, cellAdvance, textHeight);
        return handler(metrics, index, rects, 5);
    }];
}

-(NSUInteger)glyphIndexAtPoint:(CGPoint)point outMetrics:(GlyphDrawingMetrics*)outMetrics{
    __block NSUInteger glyphIndex = NSNotFound;
    [self enumerateGlyphs:^BOOL(GlyphDrawingMetrics metrics, NSUInteger index) {
        if (CGRectContainsPoint(metrics.fullBounds, point)) {
            glyphIndex = index;
            if (outMetrics) *outMetrics = metrics;
            return NO;
        }
        return YES;
    }];
    return glyphIndex;
}

-(void)mouseDown:(NSEvent *)event {
    self.lastClickLocation = [self convertPoint:[event locationInWindow] fromView:nil];
    [self setNeedsDisplay:YES];
    
    if([event clickCount] > 1) {
        GlyphDrawingMetrics metrics;
        NSUInteger index = [self glyphIndexAtPoint:self.lastClickLocation outMetrics:&metrics];
        if (index != NSNotFound) {
            [self doubleClickGlyphAtIndex:index cellRect:metrics.fullBounds];
        }
    }
}


- (void)doubleClickGlyphAtIndex:(NSUInteger)index cellRect:(NSRect)rect {
    TypefaceGlyphcode * code = [[TypefaceGlyphcode alloc] init];
    code.GID = [self.glyphs objectAtIndex:index].GID;
    code.isGID = YES;
    
    rect = [NSApp.keyWindow.contentView convertRect:rect fromView:self];
    
    [[GlyphInfoViewController createViewController] showPopoverRelativeToRect:rect
                                                                       ofView:[[NSApp keyWindow] contentView]
                                                                preferredEdge:NSRectEdgeMaxX
                                                                    withGlyph:code
                                                                   ofDocument:self.document];
    
}


- (void)reload {
    if (!_fontSize)
        _fontSize = FONT_SIZE;
    
    self.glyphs = [[NSMutableArray<TypefaceGlyph *>  alloc] init];
    self.face = self.shapper.typeface;
    NSUInteger count = self.shapper.numberOfGlyphs;
    for (NSUInteger index = 0; index < count; ++ index) {
        NSInteger gid = [self.shapper glyphAtIndex:index];
        [self.glyphs addObject:[self.face loadGlyph:[TypefaceGlyphcode glyphCodeWithGID:gid] size:self.fontSize]];
    }
    
    [self calculateSize];
    [self setupTooltips];
    [self setNeedsDisplay:YES];
    
}

- (void)windowDidResize {
    [self calculateSize];
    [self setupTooltips];
    [self setNeedsDisplay:YES];
}

- (void)calculateSize {
    CGFloat x = 0;
    for (NSUInteger index = 0; index < self.glyphs.count; ++ index)
        x += [self fontUnitToPixel:[self.shapper glyphAdvanceAtIndex:index].dx];
    
    x += [self fontUnitToPixel:self.face.bbox.size.width];
    
    CGFloat y = [self ptToPixel:self.fontSize] + MARGIN_TOP + MARGIN_BOTTOM + BASELINE_OFFSET_Y;
    y = MAX(y, self.superview.bounds.size.height);
    
    [self setFrameSize:NSMakeSize(x + MARGIN_LEFT + BASELINE_OFFSET_X + MARGIN_RIGHT, y)];
}

- (void)setupTooltips {
    [self removeAllToolTips];
    
    [self enumerateTableCells:^BOOL(GlyphDrawingMetrics metrics, NSUInteger index, CGRect *cellRects, NSUInteger count) {
        TypefaceGlyph * glyph = [self.glyphs objectAtIndex:index];
        [self addToolTipRect:cellRects[0] owner:glyph.name userData:nil];
        [self addToolTipRect:cellRects[1] owner:[NSString stringWithFormat:@"%ld", glyph.GID] userData:nil];
        [self addToolTipRect:cellRects[2] owner:[NSString stringWithFormat:@"%ld", glyph.horiAdvance] userData:nil];
        [self addToolTipRect:cellRects[3] owner:[NSString stringWithFormat:@"%ld", (NSInteger)[self.shapper glyphAdvanceAtIndex:index].dx] userData:nil];
        
        if (index != self.glyphs.count - 1) {
            NSInteger kern = [self.shapper glyphAdvanceAtIndex:index].dx - glyph.linearAdvance;
            [self addToolTipRect:cellRects[4] owner:[NSString stringWithFormat:@"%ld", kern] userData:nil];
        }
        return YES;
    }];
}

- (CGFloat)getFontSize {
    return _fontSize;
}

- (void)setFontSize:(CGFloat)fontSize {
    _fontSize = fontSize;
    [self reload];
}


- (NSFont*)tableFont {
    return [NSFont systemFontOfSize:10];
}

- (void)setOptions:(ShapingViewOption)options {
    _options = options;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect
{
    BOOL isDark = NO;
    
    if (isDark)
        [[NSColor windowBackgroundColor] set];
    else
        [[NSColor controlBackgroundColor] set];
    
    
    [NSBezierPath fillRect:rect];
    
    CGFloat descender = [self fontUnitToPixel:self.face.descender];
    
    
    CGFloat maxX = self.bounds.size.width;
    CGFloat maxY = self.bounds.size.height;
    
    
    // draw glyphs
    [self enumerateGlyphs:^BOOL(GlyphDrawingMetrics metrics, NSUInteger index) {
        TypefaceGlyph * glyph = [self.glyphs objectAtIndex:index];
        CGFloat glyphPosX = metrics.origin.x + metrics.offset.dx;
        CGFloat glyphPosY = metrics.origin.y + metrics.offset.dy;
        
        // selected background
        BOOL selected = CGRectContainsPoint(metrics.fullBounds, self.lastClickLocation);
        if (selected) {
            NSBezierPath * path = [NSBezierPath bezierPathWithRect:metrics.fullBounds];
            if (isDark)
                [[NSColor alternateSelectedControlColor] setFill];
            else
                [[NSColor selectedControlColor] setFill];
            [path fill];
        }
        
        // tint
        NSImage * glyphImage = glyph.image;
        {
            glyphImage = [glyphImage copy];
            [glyphImage lockFocus];
            [[NSColor textColor] set];
            NSRect imageRect = {NSZeroPoint, [glyphImage size]};
            NSRectFillUsingOperation(imageRect, NSCompositingOperationSourceAtop);
            [glyphImage unlockFocus];
        }
        
        [glyphImage drawAtPoint:NSMakePoint(glyphPosX + glyph.imageOffsetX, glyphPosY + glyph.imageOffsetY)
                       fromRect:NSZeroRect
                      operation:NSCompositingOperationSourceOver
                       fraction:2];
        return YES;
    }];
    
    
    // draw grid lines
    if (_options) {
        
        // draw baseline
        CGPoint baselineOrigin = [self baselineOrigin];
        if (_options & ShapingViewShowMetricsLines)
            [self lineFrom:NSMakePoint(MARGIN_LEFT, baselineOrigin.y)
                        to:NSMakePoint(self.bounds.size.width, baselineOrigin.y)
                      dash:NO
                     color:[NSColor greenColor]];
        
        [self enumerateGlyphs:^BOOL(GlyphDrawingMetrics metrics, NSUInteger index) {
            CGFloat glyphPosX = metrics.origin.x + metrics.offset.dx;
            CGFloat glyphPosY = metrics.origin.y + metrics.offset.dy;
            
            // glyph origin
            if (_options & ShapingViewShowGlyphOrigin)
                [self crossAtPoint:CGPointMake(glyphPosX, glyphPosY) size:6 color:[NSColor blueColor]];
            
            // vertical lines
            if (_options & ShapingViewShowMetricsLines) {
                [self lineFrom:NSMakePoint(metrics.origin.x, metrics.origin.y + descender)
                            to:NSMakePoint(metrics.origin.x, maxY)
                          dash:YES
                         color:[NSColor redColor]];
                
                if (index == self.glyphs.count - 1) {
                    CGFloat newX = metrics.origin.x + metrics.advance.dx;
                    [self lineFrom:NSMakePoint(newX, metrics.origin.y + descender)
                                to:NSMakePoint(newX, maxY)
                              dash:YES
                             color:[NSColor redColor]];
                }
            }
            return YES;
        }];
    }
    
    // draw glyph table
    
    
    NSFont * font = [self tableFont];
    [font set];
    
    CGFloat textHeight = font.pointSize;
    
    NSMutableParagraphStyle *cellStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    cellStyle.alignment = NSTextAlignmentCenter;
    NSDictionary *cellAttr =  [NSDictionary dictionaryWithObjectsAndKeys:
                               cellStyle, NSParagraphStyleAttributeName,
                               [NSColor controlTextColor], NSForegroundColorAttributeName, nil];
    
    NSMutableParagraphStyle *headStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    headStyle.alignment = NSTextAlignmentRight;
    NSDictionary *headAttr = [NSDictionary dictionaryWithObjectsAndKeys:
                              headStyle, NSParagraphStyleAttributeName,
                              [NSColor controlTextColor], NSForegroundColorAttributeName, nil];
    
    for (NSUInteger row = 0; row <= GLYPH_TABLE_ROWS; ++ row) {
        [self lineFrom:NSMakePoint(MARGIN_LEFT, MARGIN_BOTTOM + row * GLYPH_TABLE_ROW_HEIGHT)
                    to:NSMakePoint(maxX, MARGIN_BOTTOM + row * GLYPH_TABLE_ROW_HEIGHT)
                  dash:NO
                 color:[NSColor grayColor]];
        
        // draw header
        NSRect (^getCellRect)(NSUInteger) = ^(NSUInteger cell){
            return NSMakeRect(MARGIN_LEFT-5, MARGIN_BOTTOM + GLYPH_TABLE_HEIGHT - (cell + 1) * GLYPH_TABLE_ROW_HEIGHT + (GLYPH_TABLE_ROW_HEIGHT - textHeight) / 2, BASELINE_OFFSET_X, textHeight);
        };
        
        [@"Name" drawWithRect:getCellRect(0) options:0 attributes:headAttr context:nil];
        [@"GID" drawWithRect:getCellRect(1) options:0 attributes:headAttr context:nil];
        [@"Linear Adv." drawWithRect:getCellRect(2) options:0 attributes:headAttr context:nil];
        [@"Shaping Adv." drawWithRect:getCellRect(3) options:0 attributes:headAttr context:nil];
        [@"Kern" drawWithRect:getCellRect(4) options:0 attributes:headAttr context:nil];
    }
    
    [self enumerateTableCells:^BOOL(GlyphDrawingMetrics metrics, NSUInteger index, CGRect *cellRects, NSUInteger count) {
        TypefaceGlyph * glyph = [self.glyphs objectAtIndex:index];
        
        CGFloat cellAdvance = metrics.advance.dx;
        
        CGFloat x = metrics.origin.x;
        CGFloat newX = x + cellAdvance;
        
        // vert line of glyph
        [self lineFrom:NSMakePoint(x, MARGIN_BOTTOM + GLYPH_TABLE_HEIGHT)
                    to:NSMakePoint(x, MARGIN_BOTTOM + GLYPH_TABLE_ROW_HEIGHT)
                  dash:NO
                 color:[NSColor grayColor]];
        
        if (index == (self.glyphs.count -1)) {
            [self lineFrom:NSMakePoint(newX, MARGIN_BOTTOM + GLYPH_TABLE_HEIGHT)
                        to:NSMakePoint(newX, MARGIN_BOTTOM + GLYPH_TABLE_ROW_HEIGHT)
                      dash:NO
                     color:[NSColor grayColor]];
        }
        
        
        // kern line of glyph
        [self lineFrom:NSMakePoint((x + newX)/2, MARGIN_BOTTOM + GLYPH_TABLE_ROW_HEIGHT)
                    to:NSMakePoint((x + newX)/2, MARGIN_BOTTOM)
                  dash:NO
                 color:[NSColor grayColor]];
        
        // first cell - glyph name
        [glyph.name drawWithRect:cellRects[0] options:0 attributes:cellAttr context:nil];
        // second sell - glyph id
        [[NSString stringWithFormat:@"%ld", glyph.GID] drawWithRect:cellRects[1]  options:0 attributes:cellAttr context:nil];
        // third cell - glyph linear advance
        [[NSString stringWithFormat:@"%ld", glyph.horiAdvance] drawWithRect:cellRects[2]  options:0 attributes:cellAttr context:nil];
        // fourth cell - shaping advance
        [[NSString stringWithFormat:@"%ld", (NSInteger)[self.shapper glyphAdvanceAtIndex:index].dx] drawWithRect:cellRects[3]  options:0 attributes:cellAttr context:nil];
        
        // kerning
        if (index != self.glyphs.count - 1) {
            NSInteger kern = [self.shapper glyphAdvanceAtIndex:index].dx - glyph.linearAdvance;
            [[NSString stringWithFormat:@"%ld", kern] drawWithRect:cellRects[4]  options:0 attributes:cellAttr context:nil];
        }
        return YES;
    }];
}

- (void)crossAtPoint:(NSPoint)point size:(CGFloat)size color:(NSColor*)color {
    [self lineFrom:NSMakePoint(point.x - size/2, point.y + size/2)
                to:NSMakePoint(point.x + size/2, point.y - size/2)
              dash:NO
             color:color];
    
    [self lineFrom:NSMakePoint(point.x - size/2, point.y - size/2)
                to:NSMakePoint(point.x + size/2, point.y + size/2)
              dash:NO
             color:color];
}

- (void)lineFrom:(NSPoint)from to:(NSPoint)to dash:(BOOL)dash color:(NSColor*)color {
    NSGraphicsContext* theContext = [NSGraphicsContext currentContext];
    
    [theContext saveGraphicsState];
    
    NSBezierPath * baseline = [NSBezierPath bezierPath];
    [baseline moveToPoint:from];
    [baseline lineToPoint:to];
    if (dash) {
        CGFloat pattern [] = {4,2};
        [baseline setLineDash:pattern count:2 phase:0];
    }
    [color setStroke];
    [baseline stroke];
    
    [theContext restoreGraphicsState];
    
}

- (CGFloat)fontUnitToPixel:(CGFloat)u {
    return [self ptToPixel:u/(CGFloat)(self.face.upem) * self.fontSize];
}

- (CGPoint)fontUnitToPixelPoint:(CGPoint)p {
    return CGPointMake([self ptToPixel:p.x/(CGFloat)(self.face.upem) * self.fontSize],
                       [self ptToPixel:p.y/(CGFloat)(self.face.upem) * self.fontSize]);
}

- (CGVector)fontUnitToPixelVector:(CGVector)v {
    return CGVectorMake([self ptToPixel:v.dx/(CGFloat)(self.face.upem) * self.fontSize],
                        [self ptToPixel:v.dy/(CGFloat)(self.face.upem) * self.fontSize]);
}

- (CGFloat)ptToPixel:(CGFloat)pt {
    return pt * self.face.dpi / 72.0;
}

@end

@implementation ShapingFeatureListView

- (void)mouseDown:(NSEvent *)event {
    //event.modifierFlags |= NSEventModifierFlagCommand;
    
    NSEvent * newEvent = [NSEvent mouseEventWithType:event.type
                                            location:event.locationInWindow
                                       modifierFlags:event.modifierFlags | NSEventModifierFlagCommand
                                           timestamp:event.timestamp
                                        windowNumber:event.windowNumber
                                             context:event.context
                                         eventNumber:event.eventNumber
                                          clickCount:event.clickCount
                                            pressure:event.pressure];
    [super mouseDown:newEvent];
}

- (void)mouseUp:(NSEvent *)event {
    NSEvent * newEvent = [NSEvent mouseEventWithType:event.type
                                            location:event.locationInWindow
                                       modifierFlags:event.modifierFlags  | NSEventModifierFlagCommand
                                           timestamp:event.timestamp
                                        windowNumber:event.windowNumber
                                             context:event.context
                                         eventNumber:event.eventNumber
                                          clickCount:event.clickCount
                                            pressure:event.pressure];
    [super mouseUp:newEvent];
}

@end

@interface ShapingViewLanuageEntry : NSObject
@property TypefaceTag * script;
@property TypefaceTag * language;
@property NSString * fullName;

- (instancetype) initWithScript:(TypefaceTag*)script language:(TypefaceTag*)language;
@end

@implementation ShapingViewLanuageEntry
- (instancetype) initWithScript:(TypefaceTag*)script language:(TypefaceTag*)language {
    if (self = [super init]) {
        self.script = script;
        self.language = language;
        
        self.fullName = [NSString stringWithFormat:@"%@ %@ (%@-%@)", OTGetScriptFullName(script.text), OTGetLanguageFullName(language.text), script.text, language.text];
    }
    return self;
}
@end


@interface ShapingWindowController ()
@property (strong) IBOutlet NSArrayController *fontSizeArrayController;
@property (weak) IBOutlet NSComboBox *fontSizeCombobox;
@property (weak) IBOutlet NSPopUpButton *directionPopUpButton;
@property (weak) IBOutlet NSButton *showMetricsLinesToggleButton;
@property (weak) IBOutlet NSButton *showGlyphOriginToggleButton;

@end

@interface ShapingViewController ()
@property (strong) IBOutlet NSArrayController *languagesArrayController;
@property (strong) IBOutlet NSArrayController *otFeaturesArrayController;
@property TypefaceDocument * document;
@property Shapper * shapper;
@property (nonatomic, getter=getDirection, setter=setDirection:) ShapingDirection direction;

- (void)changeFontSize:(CGFloat)size;
- (void)windowDidResize:(NSNotification *)notification;
- (void)windowWillClose:(NSNotification *)notification;
@end


@implementation ShapingWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    self.window.delegate = self;
    //self.window.titlebarAppearsTransparent = YES;
    
    NSArray<NSNumber*> * sizes = @[@60, @72, @84, @96, @108, @120, @132, @144, @160, @180, @200, @250, @300, @350, @400];
    [self.fontSizeArrayController addObjects:sizes];
}

- (void)windowWillClose:(NSNotification *)notification {
    [self.document removeWindowController:self];
    [self.shapingViewController windowWillClose:notification];
}

- (void)windowDidResize:(NSNotification *)notification {
    [self.shapingViewController windowDidResize:notification];
}

- (void)setupWindowTitle {
    
    TypefaceDocument * doc = self.document;
    
    [self.window setRepresentedFilename:doc.typeface.fileURL.path];
    self.window.title = [NSString stringWithFormat:@"%@ %@ (Shapping)",
                         doc.typeface.preferedLocalizedFamilyName,
                         doc.typeface.preferedLocalizedStyleName];
}

- (IBAction)doSelectFontSize:(id)sender {
    self.shapingView.fontSize = [_fontSizeCombobox.stringValue floatValue];
}

- (IBAction)doChangeDirection:(id)sender {
    self.shapingViewController.direction = self.directionPopUpButton.selectedTag;
}

- (IBAction)doToggleViewOptions:(id)sender {
    
    NSUInteger options = 0;
    if (_showMetricsLinesToggleButton.state == NSOnState)
        options |= ShapingViewShowMetricsLines;
    if (_showGlyphOriginToggleButton.state == NSOnState)
        options |= ShapingViewShowGlyphOrigin;
    
    self.shapingView.options = options;
    
}

- (ShapingViewController*)shapingViewController {
    return (ShapingViewController*)(self.contentViewController);
}

- (ShapingView*)shapingView {
    return [self shapingViewController].shapingView;
}

+ (instancetype)createWithDocument:(TypefaceDocument*)document parentWindow:(NSWindow*)parentWindow bringFront:(BOOL)bringFront {
    ShapingWindowController * wc = [[NSStoryboard storyboardWithName:@"ShapingWindow" bundle:nil] instantiateInitialController];
    
    [document addWindowController:wc];
    [parentWindow addChildWindow:wc.window ordered:NSWindowAbove];
    
    if (bringFront) {
        [wc.window makeKeyAndOrderFront:parentWindow];
        [wc setupWindowTitle];
    }
    return wc;
}

@end


@implementation ShapingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    
    
    self.document = [[NSDocumentController sharedDocumentController] currentDocument];
    self.shapper = [[Shapper alloc] initWithTypeface:self.document.typeface];
    self.shapingView.shapper = self.shapper;
    self.shapingView.document = self.document;
    
    self.direction = ShappingDirectionLTR;
    
    // load languages
    for (TypefaceTag * script in self.shapper.scripts) {
        for (TypefaceTag * language in [self.shapper languagesOfScript:script]) {
            ShapingViewLanuageEntry * entry = [[ShapingViewLanuageEntry alloc] initWithScript:script language:language];
            [self.languagesArrayController addObject:entry];
        }
    }
    
    [self.languagesArrayController setSelectionIndex:0];
    
    [self.languagesArrayController addObserver:self
                                    forKeyPath:@"selectedObjects"
                                       options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial
                                       context:nil];
    [self.otFeaturesArrayController addObserver:self
                                     forKeyPath:@"selectedObjects"
                                        options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial
                                        context:nil];
    
    [self addObserver:self
           forKeyPath:@"direction"
              options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial
              context:nil];
}

- (void)windowWillClose:(NSNotification *)notification {
    [self removeObserver:self forKeyPath:@"direction"];
    [self.languagesArrayController removeObserver:self forKeyPath:@"selectedObjects"];
    [self.otFeaturesArrayController removeObserver:self forKeyPath:@"selectedObjects"];
}

- (void)windowDidResize:(NSNotification *)notification {
    [self.shapingView windowDidResize];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (object == self.languagesArrayController) {
        if ([keyPath isEqualToString:@"selectedObjects"]) {
            if (!self.languagesArrayController.selectedObjects.count)
                return;
            ShapingViewLanuageEntry * entry = [self.languagesArrayController.selectedObjects objectAtIndex:0];
            NSRange range = NSMakeRange(0, [[self.otFeaturesArrayController arrangedObjects] count]);
            [self.otFeaturesArrayController removeObjectsAtArrangedObjectIndexes:[NSIndexSet indexSetWithIndexesInRange:range]];
            
            NSMutableArray<OpenTypeFeatureTag*> * features = [[self.shapper featuresOfScript:entry.script language:entry.language] mutableCopy];
            [features sortUsingSelector:@selector(compare:)];
            [self.otFeaturesArrayController addObjects:features];
            [self.otFeaturesArrayController setSelectedObjects:[self.shapper requiredFeaturesOfScript:entry.script language:entry.language]];
        }
    }
    if (object == self.otFeaturesArrayController) {
        if ([keyPath isEqualToString:@"selectedObjects"]) {
            if ([self.otFeaturesArrayController.arrangedObjects count]) {
                [self shape];
            }
        }
    }
    if (object == self) {
        if ([keyPath isEqualToString:@"direction"]) {
            [self shape];
        }
    }
}

- (NSString *)tableView:(NSTableView *)tableView toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation {
    NSString * tagText = [[self.otFeaturesArrayController.arrangedObjects objectAtIndex:row] text];
    return OTGetFeatureFullName(tagText);
}
- (BOOL)tableView:(NSTableView *)tableView shouldTrackCell:(NSCell *)cell forTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    return YES;
}

- (void)controlTextDidChange:(NSNotification *)obj {
    [self shape];
}

- (void)changeFontSize:(CGFloat)size {
    self.shapingView.fontSize = size;
}


- (void)shape {
    ShapingViewLanuageEntry * entry = nil;
    if(self.languagesArrayController.selectedObjects.count)
        entry = [self.languagesArrayController.selectedObjects objectAtIndex:0];
    
    [self.shapper shapeText:[CharEncoding decodeUnicodeMixed:self.textInputField.stringValue]
              withDirection:self.direction
                     script:entry.script
                   language:entry.language
                   features:self.otFeaturesArrayController.selectedObjects];
    [self.shapingView reload];
}


@end
