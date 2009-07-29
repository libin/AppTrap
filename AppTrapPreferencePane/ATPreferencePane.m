/*
-----------------------------------------------
  APPTRAP LICENSE

  "Do what you want to do,
  and go where you're going to
  Think for yourself,
  'cause I won't be there with you"

  You are completely free to do anything with
  this source code, but if you try to make
  money on it you will be beaten up with a
  large stick. I take no responsibility for
  anything, and this license text must
  always be included.

  Markus Amalthea Magnuson <markus.magnuson@gmail.com>
-----------------------------------------------
*/

#import "ATPreferencePane.h"
#import "ATNotifications.h"
#import "ATVariables.h"
#import "UKLoginItemRegistry.h"

@implementation ATPreferencePane

- (void)mainViewDidLoad
{
	[[ATSUUpdater sharedUpdater] resetUpdateCycle];
	[[ATSUUpdater sharedUpdater] setDelegate:self];
		
    // Setup the application path
    appPath = [[[self bundle] pathForResource:@"AppTrap" ofType:@"app"] retain];
	[automaticallyCheckForUpdate setState:[[ATSUUpdater sharedUpdater] automaticallyChecksForUpdates]];

    // Restart AppTrap in case the user just updated to a new version
    // TODO: Check AppTrap's version against the prefpane version and only restart if they differ
    // TODO: Leave this off for now, something goes haywire on startup
    /*if ([self appTrapIsRunning])
        [self launchAppTrap];*/
        
    // Check if application is in login items
    if ([self inLoginItems]) {
		[startOnLoginButton setState:NSOnState];
	} else {
		[startOnLoginButton setState:NSOffState];
	}
    
    // Display read me file
    [aboutView readRTFDFromFile:[[self bundle] pathForResource:@"Read Me" ofType:@"rtf"]];
    // Replace the {APPTRAP_VERSION} symbol with the version number
    NSRange versionSymbolRange = [[aboutView string] rangeOfString:@"{APPTRAP_VERSION}"];
    if (versionSymbolRange.location != NSNotFound){
        [[aboutView textStorage] replaceCharactersInRange:versionSymbolRange withString:[[self bundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
	}

    // Register for notifications from AppTrap
    NSDistributedNotificationCenter *nc = [NSDistributedNotificationCenter defaultCenter];
    
    [nc addObserver:self
           selector:@selector(updateStatus)
               name:ATApplicationFinishedLaunchingNotification
             object:nil
 suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
    
    [nc addObserver:self
           selector:@selector(updateStatus)
               name:ATApplicationTerminatedNotification
             object:nil
 suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
	
	[nc addObserver:self
		   selector:@selector(checkBackgroundProcessVersion:) 
			   name:ATApplicationGetVersionData 
			 object:nil 
 suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
	
	[nc postNotificationName:ATApplicationSendVersionData 
					  object:nil 
					userInfo:nil 
		  deliverImmediately:YES];
}

- (void)checkBackgroundProcessVersion:(NSNotification*)notification {
	NSLog(@"checkBackgroundProcessVersion");
	NSLog(@"notification: %@", [notification description]);
	NSLog(@"notification userInfo class: %@", [[notification userInfo] className]);
	NSLog(@"notification userInfo: %@", [[notification userInfo] description]);
	
	NSString *backgroundProcessVersion = [[notification userInfo] objectForKey:ATBackgroundProcessVersion];
	int backgroundProcessVersionInt = [backgroundProcessVersion intValue];
	NSString *prefpaneVersion = [[self bundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
	int prefpaneVersionInt = [prefpaneVersion intValue];
	
	if (prefpaneVersionInt != backgroundProcessVersionInt) {
		NSBeginAlertSheet(@"AppTrap", 
						  NSLocalizedStringFromTableInBundle(@"Restart AppTrap", nil, [self bundle], @""), 
						  NSLocalizedStringFromTableInBundle(@"Don't restart AppTrap", nil, [self bundle], @""), 
						  nil, 
						  [startStopButton window], 
						  self, 
						  @selector(sheetDidEnd:returnCode:contextInfo:), 
						  nil, 
						  nil, 
						  NSLocalizedStringFromTableInBundle(@"The background process is an older version. Would you like to restart it with the newer version?", nil, [self bundle], @""));
	}
}

- (void)sheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo {
	if (returnCode == NSAlertDefaultReturn) {
		[restartingAppTrapIndicator startAnimation:nil];
		[restartingAppTrapTextField setHidden:NO];
		[self terminateAppTrap];
		[self performSelector:@selector(restartWithNewVersion) withObject:nil afterDelay:5];
	}
}

- (void)restartWithNewVersion {
	[self launchAppTrap];
	[restartingAppTrapIndicator stopAnimation:nil];
	[restartingAppTrapTextField setHidden:YES];
}

- (void)didSelect
{
    [self updateStatus];
    //[self checkForUpdate];
}

- (void)updateStatus
{
    if ([self appTrapIsRunning]) {
        // Need to specify bundle because we're a prefpane
        [statusText setStringValue:NSLocalizedStringFromTableInBundle(@"Active", nil, [self bundle], @"")];
        [statusText setTextColor:[NSColor blackColor]];
        [startStopButton setTitle:NSLocalizedStringFromTableInBundle(@"Stop AppTrap", nil, [self bundle], @"")];
    }
    else {
        // Need to specify bundle because we're a prefpane
        [statusText setStringValue:NSLocalizedStringFromTableInBundle(@"Inactive", nil, [self bundle], @"")];
        [statusText setTextColor:[NSColor grayColor]];
        [startStopButton setTitle:NSLocalizedStringFromTableInBundle(@"Start AppTrap", nil, [self bundle], @"")];
    }
    
    // Extra check after five seconds in case the launch/termination was delayed
    [self performSelector:@selector(updateStatus)
			   withObject:nil
			   afterDelay:5.0];
}

- (void)launchAppTrap
{    
    // Try to launch AppTrap
	NSLog(@"launching AppTrap");
	NSURL *appURL = [NSURL fileURLWithPath:appPath];
	unsigned options = NSWorkspaceLaunchWithoutAddingToRecents | NSWorkspaceLaunchWithoutActivation | NSWorkspaceLaunchAsync;
    
	BOOL launched = [[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:appURL]
                                    withAppBundleIdentifier:nil
                                                    options:options
                             additionalEventParamDescriptor:nil
                                          launchIdentifiers:NULL];
    
    if (!launched)
        NSLog(@"Couldn't launch AppTrap!");
}

- (void)terminateAppTrap
{
	NSLog(@"terminating Apptrap");
    NSDistributedNotificationCenter *nc = [NSDistributedNotificationCenter defaultCenter];
    [nc postNotificationName:ATApplicationShouldTerminateNotification
                      object:nil
                    userInfo:nil
          deliverImmediately:YES];
}

// Code from Growl
- (BOOL)appTrapIsRunning
{
    BOOL appTrapIsRunning = NO;
    ProcessSerialNumber PSN = {kNoProcess, kNoProcess};
    
    while (GetNextProcess(&PSN) == noErr) {
        CFDictionaryRef infoDict = ProcessInformationCopyDictionary(&PSN, kProcessDictionaryIncludeAllInformationMask);
        CFStringRef bundleId = CFDictionaryGetValue(infoDict, kCFBundleIdentifierKey);
        
        if (bundleId && CFStringCompare(bundleId, CFSTR("se.konstochvanligasaker.AppTrap"), 0) == kCFCompareEqualTo) {
            appTrapIsRunning = YES;
            CFRelease(infoDict);
            break;
        }
        CFRelease(infoDict);
    }
    
    return appTrapIsRunning;
}

#pragma mark -
#pragma mark Update check

- (SUUpdater*)updater {
	return [SUUpdater updaterForBundle:[NSBundle bundleForClass:[self class]]];
}

- (IBAction)automaticallyCheckForUpdate:(id)sender {
	[[ATSUUpdater sharedUpdater] setAutomaticallyChecksForUpdates:[sender state]];
}

- (IBAction)checkForUpdate:(id)sender {
	[[ATSUUpdater sharedUpdater] checkForUpdates:sender];
}

#pragma mark -
#pragma mark Login items

- (BOOL)inLoginItems
{
    if ([UKLoginItemRegistry indexForLoginItemWithPath:appPath] > 0)
        return YES;
    else
        return NO;
}

- (void)addToLoginItems
{
    // Only if we're not in login items already
    if (![self inLoginItems]) {
        [UKLoginItemRegistry addLoginItemWithPath:appPath hideIt:NO];
    }
}

- (void)removeFromLoginItems
{
    // Only if we already are in login items
    if ([self inLoginItems]) {
        [UKLoginItemRegistry removeLoginItemWithPath:appPath];
    }
}

#pragma mark -
#pragma mark Interface actions

- (IBAction)startStopAppTrap:(id)sender
{
    if ([self appTrapIsRunning])
        [self terminateAppTrap];
    else
        [self launchAppTrap];
}

- (IBAction)startOnLogin:(id)sender
{
    if ([sender state] == NSOnState)
        [self addToLoginItems];
    else
        [self removeFromLoginItems];
    
}

- (IBAction)visitWebsite:(id)sender
{
    NSURL *url = [NSURL URLWithString:@"http://onnati.net/apptrap/"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

@end
