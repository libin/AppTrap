//
//  ATUpdateChecker.h
//  AppTrap
//
//  Created by Kumaran Vijayan on 09-12-29.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "ATUserDefaultKeys.h"

@interface ATUpdateChecker : NSObject {
	NSTimer *updateTimer;
	NSTimeInterval updateTimerTimeInterval;
	
	IBOutlet NSWindow *updateWindow;
	IBOutlet WebView *webView;
}
- (void)checkForUpdate;
- (void)stopCheckForUpdate;
- (NSInteger)getVersionNumber;
- (NSArray*)getSystemVersion;
- (IBAction)cancel:(id)sender;
- (IBAction)skipUpdate:(id)sender;
- (IBAction)installUpdate:(id)sender;
@end
