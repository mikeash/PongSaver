//
//  PongSaverView.h
//  PongSaver
//
//  Created by Michael Ash on 11/26/05.
//  Copyright (c) 2005, __MyCompanyName__. All rights reserved.
//

#import <ScreenSaver/ScreenSaver.h>


@interface PongSaverView : ScreenSaverView 
{
	float masterScale;
	
	float lPos;
	float rPos;
	float lSpeed;
	float rSpeed;
	float lIdleSpeed;
	float rIdleSpeed;
	NSTimer *idleTimer;
	float lIntelligence; // 0 = max, larger = dumber
	float rIntelligence;
	
	NSPoint bPos;
	NSPoint bSpeed;
	
	int scores[2];
	
	NSRect digitSegments[13];
	
	BOOL shouldAnimate;
	
	BOOL isTwelveHour;
	BOOL hasSound;
	BOOL playOnAllScreens;
	NSSound *launchSound;
	NSSound *reboundSound;
	
	IBOutlet NSPanel *configurePanel;
	IBOutlet NSObjectController *configureObjController;
}

- (void)resetBall;
- (void)setDigitSegmentRects;

- (IBAction)configureOK: (id)sender;
- (IBAction)configureCancel: (id)sender;

@end