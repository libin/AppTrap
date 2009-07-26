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
#import "UKLoginItemRegistry.h"

@implementation ATPreferencePane

- (void)mainViewDidLoad
{
	[[ATSUUpdater sharedUpdater] resetUpdateCycle];
    // Setup the application path
    appPath = [[[self bundle] pathForResource:@"AppTrap" ofType:@"app"] retain];
	[automaticallyCheckForUpdate setState:[[ATSUUpdater sharedUpdater] automaticallyChecksForUpdates]];

    // Restart AppTrap in case the user just updated to a new version
    // TODO: Check AppTrap's version against the prefpane version and only restart if they differ
    // TODO: Leave this off for now, something goes haywire on startup
    /*if ([self appTrapIsRunning])
        [self launchAppTrap];*/
        
    // Check if application is in login items
    if ([self inLoginItems])
        [startOnLoginButton setState:NSOnState];
    else
        [startOnLoginButton setState:NSOffState];
    
    // Display read me file
    [aboutView readRTFDFromFile:[[self bundle] pathForResource:@"Read Me" ofType:@"rtf"]];
    // Replace the {APPTRAP_VERSION} symbol with the version number
    NSRange versionSymbolRange = [[aboutView string] rangeOfString:@"{APPTRAP_VERSION}"];
    if (versionSymbolRange.location != NSNotFound)
        [[aboutView textStorage] replaceCharactersInRange:versionSymbolRange withString:[[self bundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
    
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
}

- (SUUpdater*)updater {
	return [SUUpdater updaterForBundle:[NSBundle bundleForClass:[self class]]];
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
- (IBAction)automaticallyCheckForUpdate:(id)sender {
	[[ATSUUpdater sharedUpdater] setAutomaticallyChecksForUpdates:[sender state]];
}

- (IBAction)checkForUpdate:(id)sender {
	[[ATSUUpdater sharedUpdater] checkForUpdates:sender];
}

- (void)checkForUpdate
{
    // create the request
    NSURLRequest *theRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://svn.konstochvanligasaker.se/apptrap/latest_version"]
                                                cachePolicy:NSURLRequestReloadIgnoringCacheData
                                            timeoutInterval:30.0];
    
    // create the connection with the request and start loading the data
    NSURLDownload  *theDownload = [[NSURLDownload alloc] initWithRequest:theRequest
                                                                delegate:self];
    
    if (theDownload) {
        // set the destination file now
        [theDownload setDestination:@"/tmp/apptrap_latest_version" allowOverwrite:YES];
    }
}

- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error
{
    // release the connection
    [download release];
    
    // inform the user (sort of!)
    NSLog(@"Couldn't get latest version! Error - %@ %@", [error localizedDescription],
          [[error userInfo] objectForKey:NSErrorFailingURLStringKey]);
}

- (void)downloadDidFinish:(NSURLDownload *)download
{
    // release the connection
    [download release];
    
    // do something with the data
    NSString *latestVersion = [NSString stringWithContentsOfFile:@"/tmp/apptrap_latest_version"];
    
    if (latestVersion) {
        // What version are we using now?
        // We must get the current version explicitly from the Info.plist file. Getting it from our bundle would give us an old version string, since that would use the currently loaded bundle
        NSString *plist = [[[self bundle] bundlePath] stringByAppendingPathComponent:@"Contents/Info.plist"];
        NSDictionary *theDictionary = [NSDictionary dictionaryWithContentsOfFile:plist];
        NSString *currentVersion = [[[theDictionary valueForKey:@"CFBundleVersion"] componentsSeparatedByString:@"."] componentsJoinedByString:@""];
        
        int old = [currentVersion intValue];
        int new = [latestVersion intValue];
        
        if (new > old) {
            // A new version is available, prompt the user
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Download", nil, [self bundle], @"")];
            [alert addButtonWithTitle:NSLocalizedStringFromTableInBundle(@"Don't download", nil, [self bundle], @"")];
            [alert setMessageText:NSLocalizedStringFromTableInBundle(@"New version", nil, [self bundle], @"")];
            [alert setInformativeText:NSLocalizedStringFromTableInBundle(@"A new version of AppTrap is available, do you want to download it now?", nil, [self bundle], @"")];
            [alert setAlertStyle:NSWarningAlertStyle];
            
            [alert beginSheetModalForWindow:[[self mainView] window] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
        }
    }
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if (returnCode == NSAlertFirstButtonReturn) {
        // Let's download the latest version of AppTrap
        NSURL *downloadURL = [NSURL URLWithString:@"http://konstochvanligasaker.se/apptrap/AppTrap.dmg"];
        [[NSWorkspace sharedWorkspace] openURL:downloadURL];
    }
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
