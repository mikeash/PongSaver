//
//  PongSaverView.m
//  PongSaver
//
//  Created by Michael Ash on 11/26/05.
//  Copyright (c) 2005, __MyCompanyName__. All rights reserved.
//

#import "PongSaverView.h"

static const float kNativeHeight = 240.0;
static const float kPaddleWidth = 10.0;
static const float kPaddleHeight = 50.0;
static const float kPaddleMargin = 20.0;
static const float kBallSize = 5.0;
static const float kBallSpeed = 6.0;
static const float kPaddleSpeed = 12.0;
static const float kIdleResetInterval = 5.0;
static const float kIdleScale = 5.0;
static const float kDigitSegmentWidth = 5.0;
static const float kDigitSegmentLength = 20.0;
static const float kDigitHeight = 55.0;
static const float kDigitWidth = 30.0;

static const int kDigitSegment0[] = { 0, 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, -1 };
static const int kDigitSegment1[] = { 2, 4, 7, 9, 12, -1 };
static const int kDigitSegment2[] = { 0, 1, 2, 3, 5, 6, 7, 9, 10, 11, 12, -1 };
static const int kDigitSegment3[] = { 0, 1, 2, 4, 6, 7, 9, 10, 11, 12, -1 };
static const int kDigitSegment4[] = { 2, 4, 5, 6, 7, 8, 9, 12, -1 };
static const int kDigitSegment5[] = { 0, 1, 2, 4, 5, 6, 7, 8, 10, 11, 12, -1 };
static const int kDigitSegment6[] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, -1 };
static const int kDigitSegment7[] = { 2, 4, 7, 9, 11, 12, -1 };
static const int kDigitSegment8[] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, -1 };
static const int kDigitSegment9[] = { 0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, -1 };
static const int *kDigitSegments[] = { kDigitSegment0, kDigitSegment1, kDigitSegment2, kDigitSegment3, kDigitSegment4, kDigitSegment5, kDigitSegment6, kDigitSegment7, kDigitSegment8, kDigitSegment9 };

@implementation PongSaverView

+ (void)initialize
{
    [[ScreenSaverDefaults defaultsForModuleWithName:
      [[NSBundle bundleForClass: [self class]] bundleIdentifier]]
     registerDefaults:
         [NSDictionary dictionaryWithObjectsAndKeys:
          [NSNumber numberWithBool: YES], @"hasSound",
          [NSNumber numberWithBool: NO], @"isTwelveHour",
          nil]];
}

- (void)_setNotifications
{
    [[NSDistributedNotificationCenter defaultCenter] addObserver: self
                                                        selector: @selector(receive:)
                                                            name: @"com.apple.screenIsUnlocked"
                                                          object: nil
    ];
}

- (void)receive:(NSNotification *)notification
{
    [self stopAnimation];
    exit(0);
}

- (void)_loadFromDefaults
{
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName: [[NSBundle bundleForClass: [self class]] bundleIdentifier]];
    [defaults synchronize];
    hasSound = [defaults boolForKey: @"hasSound"];
    isTwelveHour = [defaults boolForKey: @"isTwelveHour"];
    playOnAllScreens = [defaults boolForKey: @"playOnAllScreens"];
}

- (void)_saveToDefaults
{
    ScreenSaverDefaults *defaults = [ScreenSaverDefaults defaultsForModuleWithName: [[NSBundle bundleForClass: [self class]] bundleIdentifier]];
    [defaults setBool: isTwelveHour forKey: @"isTwelveHour"];
    [defaults setBool: hasSound forKey: @"hasSound"];
    [defaults setBool: playOnAllScreens forKey: @"playOnAllScreens"];
    [defaults synchronize];
}

- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview
{
    self = [super initWithFrame:frame isPreview:isPreview];
    if (self) {
        masterScale = NSHeight( frame ) / kNativeHeight;
        
        lPos = NSHeight( frame ) / 2.0;
        rPos = NSHeight( frame ) / 2.0;
        
        NSDateComponents* timeComponents = [[NSCalendar currentCalendar] components:NSCalendarUnitHour | NSCalendarUnitMinute fromDate:[NSDate now]];
        scores[0] = (int)[timeComponents minute];
        scores[1] = (int)[timeComponents hour];
        
        [self resetBall];
        [self setDigitSegmentRects];
        [self _loadFromDefaults];
        if (!isPreview)
            [self _setNotifications];
        
        NSString *launchPath = [[NSBundle bundleForClass: [self class]] pathForSoundResource: @"launch"];
        NSString *reboundPath = [[NSBundle bundleForClass: [self class]] pathForSoundResource: @"rebound"];
        
        launchSound = [[NSSound alloc] initWithContentsOfFile: launchPath byReference: YES];
        reboundSound = [[NSSound alloc] initWithContentsOfFile: reboundPath byReference: YES];
    }
    return self;
}

- (void)startAnimation
{
    if (isAnimating)
        return;
    
    [super startAnimation];
    [self _loadFromDefaults];
    
    shouldAnimate = [self isPreview] || playOnAllScreens || [[[self window] screen] isEqual: [NSScreen mainScreen]];
    [self setAnimationTimeInterval: shouldAnimate ? 1/30.0 : 1000000000];
    [super startAnimation];
    
    if( shouldAnimate )
        idleTimer = [NSTimer scheduledTimerWithTimeInterval: kIdleResetInterval target: self selector: @selector( doIdle: ) userInfo: nil repeats: YES];
    
    isAnimating = YES;
}

- (void)stopAnimation
{
    if (!isAnimating)
        return;
    
    [super stopAnimation];
    [idleTimer invalidate];
    idleTimer = nil;
    [configureObjController setContent: nil];
    
    isAnimating = NO;
}

- (float)paddleMargin
{
    return kPaddleMargin * masterScale;
}

- (float)paddleHeight
{
    return kPaddleHeight * masterScale;
}

- (float)paddleWidth
{
    return kPaddleWidth * masterScale;
}

- (float)ballSize
{
    return kBallSize * masterScale;
}

- (void)drawDigit: (int)digit atPoint: (NSPoint)point
{
    const int *segments = kDigitSegments[digit];
    int i = 0;
    while( segments[i] != -1 )
        [NSBezierPath fillRect: NSOffsetRect( digitSegments[segments[i++]], point.x, point.y )];
}

- (void)drawScore
{
    NSRect bounds = [self bounds];
    
    float midx = NSWidth( bounds ) / 2.0;
    float digitWidth = kDigitWidth * masterScale;
    float digitHeight = kDigitHeight * masterScale;
    float segmentWidth = kDigitSegmentWidth * masterScale;
    float segmentLength = kDigitSegmentLength * masterScale;
    
    float y = NSMaxY( bounds ) - digitHeight - segmentWidth;
    
    [[NSColor colorWithDeviceWhite: 1.0 alpha: 0.5] setFill];
    
    int leftScore = scores[1];
    int rightScore = scores[0];
    
    if( isTwelveHour )
        {
        leftScore %= 12;
        if( leftScore == 0 )
            leftScore = 12;
        }
    
    [self drawDigit: (leftScore / 10) % 10 atPoint: NSMakePoint( midx - digitWidth * 2.0 - segmentLength - segmentWidth, y )];
    [self drawDigit: leftScore % 10 atPoint: NSMakePoint( midx - digitWidth - segmentLength, y )];
    
    [self drawDigit: rightScore % 10 atPoint: NSMakePoint( midx + digitWidth + segmentLength + segmentWidth, y )];
    [self drawDigit: (rightScore / 10) % 10 atPoint: NSMakePoint( midx + segmentLength, y )];
}

- (void)drawPaddlesAndBall
{
    NSRect bounds = [self bounds];
    
    [[NSColor whiteColor] setFill];
    
    float paddleMargin = [self paddleMargin];
    float paddleHeight = [self paddleHeight];
    float paddleWidth = [self paddleWidth];
    
    NSRect lRect = NSMakeRect( paddleMargin, lPos - paddleHeight / 2.0, paddleWidth, paddleHeight );
    NSRect rRect = NSMakeRect( NSMaxX( bounds ) - paddleMargin - paddleWidth, rPos - paddleHeight / 2.0, paddleWidth, paddleHeight );
    
    NSRectFill( lRect );
    NSRectFill( rRect );
    
    float ballSize = [self ballSize];
    
    NSRect bRect = NSMakeRect( bPos.x - ballSize / 2.0, bPos.y - ballSize / 2.0, ballSize, ballSize );
    NSRectFill( bRect );
}

- (void)drawRect:(NSRect)rect
{
    [[NSColor blackColor] setFill];
    NSRectFill( rect );
    
    if( shouldAnimate ) {
        [self drawPaddlesAndBall];
        [self drawScore];
    }
}

- (void)resetIntelligences
{
    NSDateComponents* timeComponents = [[NSCalendar currentCalendar] components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:[NSDate now]];
    int hour = (int)[timeComponents hour];
    int min = (int)[timeComponents minute];
    int sec = (int)[timeComponents second];
    
    if( scores[0] != min && scores[0] != ((min + 1) % 60) )
        lIntelligence = ((ABS( min - scores[0] ) - 1) * 60 + sec) / 10;
    else
        lIntelligence = 0;
    
    if( scores[1] != hour )
        rIntelligence = (min * 60 + sec) / 30;
    else
        rIntelligence = 0;
}

- (void)doIdle: (NSTimer *)timer
{
    float maxSpeed = kPaddleSpeed * masterScale / kIdleScale;
    lIdleSpeed = SSRandomFloatBetween( -maxSpeed, maxSpeed );
    rIdleSpeed = SSRandomFloatBetween( -maxSpeed, maxSpeed );
    
    [self resetIntelligences];
}

- (void)resetBall
{
    NSRect bounds = [self bounds];
    bPos.x = NSWidth( bounds ) / 2.0;
    bPos.y = NSHeight( bounds ) / 2.0;
    bSpeed.x = copysignf( kBallSpeed * masterScale, bSpeed.x );
    bSpeed.y = SSRandomFloatBetween( -bSpeed.x, bSpeed.y );
    
    [self resetIntelligences];
}

- (void)setDigitSegmentRects
{
    float w = kDigitSegmentWidth;
    float l = kDigitSegmentLength;
    
    digitSegments[0 ] = NSMakeRect( 0, 0, w, w );
    digitSegments[1 ] = NSMakeRect( w, 0, l, w );
    digitSegments[2 ] = NSMakeRect( l+w, 0, w, w );
    digitSegments[3 ] = NSMakeRect( 0, w, w, l );
    digitSegments[4 ] = NSMakeRect( l+w, w, w, l );
    digitSegments[5 ] = NSMakeRect( 0, l+w, w, w );
    digitSegments[6 ] = NSMakeRect( w, l+w, l, w );
    digitSegments[7 ] = NSMakeRect( l+w, l+w, w, w );
    digitSegments[8 ] = NSMakeRect( 0, 2*w+l, w, l );
    digitSegments[9 ] = NSMakeRect( l+w, 2*w+l, w, l );
    digitSegments[10] = NSMakeRect( 0, 2*w+2*l, w, w );
    digitSegments[11] = NSMakeRect( w, 2*w+2*l, l, w );
    digitSegments[12] = NSMakeRect( l+w, 2*w+2*l, w, w );
    
    int i;
    for( i = 0; i < 13; i++ )
        {
        digitSegments[i].origin.x *= masterScale;
        digitSegments[i].origin.y *= masterScale;
        digitSegments[i].size.width *= masterScale;
        digitSegments[i].size.height *= masterScale;
        }
}

- (void)ballMissed: (int)side
{
    scores[side] = (scores[side] + 1) % (side == 1 ? 24 : 60);
    [self resetBall];
    
    [self display];
    [NSThread sleepUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.5]];
    
    if( hasSound )
        [launchSound play];
}

- (void)moveBall
{
    NSRect bounds = [self bounds];
    float paddleMargin = [self paddleMargin];
    float paddleHeight = [self paddleHeight];
    float paddleWidth = [self paddleWidth];
    float ballSize = [self ballSize];
    float lFront = paddleMargin + paddleWidth;
    float rFront = NSMaxX( bounds ) - paddleMargin - paddleWidth;
    
    bPos.x += bSpeed.x;
    bPos.y += bSpeed.y;
    
    if( bSpeed.y > 0 )
        {
        if( bPos.y + ballSize/2.0 > NSMaxY( bounds ) )
            bSpeed.y = -bSpeed.y;
        }
    else
        {
        if( bPos.y - ballSize/2.0 < 0.0 )
            bSpeed.y = -bSpeed.y;
        }
    
    float maxBallSpeed = kBallSpeed * masterScale;
    
    if( bSpeed.x > 0 )
        {
        if( bPos.x + ballSize/2.0 > rFront )
            {
            float miny = rPos - paddleHeight / 2.0 - ballSize / 2.0;
            float maxy = rPos + paddleHeight / 2.0 + ballSize / 2.0;
            
            if( bPos.y >= miny && bPos.y <= maxy )
                {
                bSpeed.x = -bSpeed.x;
                bSpeed.y = (bPos.y - rPos) / (paddleHeight / 2.0) * maxBallSpeed + SSRandomFloatBetween( -0.1 * maxBallSpeed, 0.1 * maxBallSpeed ) + rSpeed;
                bSpeed.y = copysignf( MIN( fabs( bSpeed.y ), maxBallSpeed ), bSpeed.y );
                if( hasSound )
                    [reboundSound play];
                }
            else
                {
                [self ballMissed: 1];
                }
            }
        }
    else
        {
        if( bPos.x - ballSize/2.0 < lFront )
            {
            float miny = lPos - paddleHeight / 2.0 - ballSize / 2.0;
            float maxy = lPos + paddleHeight / 2.0 + ballSize / 2.0;
            
            if( bPos.y >= miny && bPos.y <= maxy )
                {
                bSpeed.x = -bSpeed.x;
                bSpeed.y = (bPos.y - lPos) / (paddleHeight / 2.0) * maxBallSpeed + SSRandomFloatBetween( -0.1 * maxBallSpeed, 0.1 * maxBallSpeed ) + lSpeed;
                bSpeed.y = copysignf( MIN( fabs( bSpeed.y ), maxBallSpeed ), bSpeed.y );
                if( hasSound )
                    [reboundSound play];
                }
            else
                {
                [self ballMissed: 0];
                }
            }
        }
}

- (void)calcPaddleSpeeds
{
    NSRect bounds = [self bounds];
    float width = NSWidth( bounds );
    float ratio = bPos.x / width;
    float paddleMargin = [self paddleMargin];
    
    float lMult = expf( -lIntelligence );
    float rMult = expf( -rIntelligence );
    
    if( ratio > 0.25 )
        {
        float xdiff = width - paddleMargin - bPos.x;
        float ydiff = bPos.y - rPos;
        
        rSpeed = (1.0 / xdiff) * ydiff * masterScale * kPaddleSpeed * rMult;
        }
    else
        rSpeed = rIdleSpeed;
    
    if( ratio < 0.75 )
        {
        float xdiff = bPos.x - paddleMargin;
        float ydiff = bPos.y - lPos;
        
        lSpeed = (1.0 / xdiff) * ydiff * masterScale * kPaddleSpeed * lMult;
        }
    else
        lSpeed = lIdleSpeed;
}

- (void)movePaddles
{
    NSRect bounds = [self bounds];
    
    float paddleHeight = [self paddleHeight];
    float miny = paddleHeight / 2.0;
    float maxy = NSHeight( bounds ) - paddleHeight / 2.0;
    
    rPos += rSpeed;
    lPos += lSpeed;
    
    if( rPos > maxy )
        {
        rPos = maxy;
        rSpeed = 0.0;
        }
    if( rPos < miny )
        {
        rPos = miny;
        rSpeed = 0.0;
        }
    if( lPos > maxy )
        {
        lPos = maxy;
        lSpeed = 0.0;
        }
    if( lPos < miny )
        {
        lPos = miny;
        lSpeed = 0.0;
        }
}

- (void)animateOneFrame
{
    [self calcPaddleSpeeds];
    [self movePaddles];
    [self moveBall];
    
    [self setNeedsDisplay: YES];
}

- (BOOL)hasConfigureSheet
{
    return YES;
}

- (NSWindow*)configureSheet
{
    if( !configurePanel ) {
        NSBundle *bundle = [NSBundle bundleForClass: [self class]];
        [bundle loadNibNamed: @"Configure" owner: self topLevelObjects: nil];
    }
    
    [configureObjController setContent: self];
    
    return configurePanel;
}

- (IBAction)configureOK: (id)sender
{
    [self _saveToDefaults];
    [NSApp endSheet: configurePanel];
    [configureObjController setContent: nil];
}

- (IBAction)configureCancel: (id)sender
{
    [self _loadFromDefaults];
    [NSApp endSheet: configurePanel];
    [configureObjController setContent: nil];
}

@end
