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

#import "ATApplicationController.h"
#import "ATArrayController.h"
#import "ATNotifications.h"
#import "ATVariables.h"
#import "UKKQueue.h"
#import "ATUserDefaultKeys.h"
#import "ATUpdateChecker.h"

// Amount to expand the window to show the filelist
const int kWindowExpansionAmount = 164;

@implementation ATApplicationController

- (id)init
{
    if ((self = [super init])) {
        // Setup the path to the trash folder
        pathToTrash = nil;
        CFURLRef trashURL;
        FSRef trashFolderRef;
        OSErr err;
        
        err = FSFindFolder(kUserDomain, kTrashFolderType, kDontCreateFolder, &trashFolderRef);
        if (err == noErr) {
            trashURL = CFURLCreateFromFSRef(kCFAllocatorSystemDefault, &trashFolderRef);
            if (trashURL) {
                pathToTrash = (NSString *)CFURLCopyFileSystemPath(trashURL, kCFURLPOSIXPathStyle);
                CFRelease(trashURL);
            }
        }
        
        // Setup paths for application folders
        applicationsPaths = [[NSSet alloc] initWithArray:NSSearchPathForDirectoriesInDomains(NSAllApplicationsDirectory, NSLocalDomainMask | NSUserDomainMask, YES)];
        
        // Setup paths for library items, where we'll search for files
        NSMutableArray *tempArray = [[NSMutableArray alloc] init];
        NSArray *tempSearchArray = nil;
        NSEnumerator *e = nil;
        id currentObject = nil;
        
        // Preferences and StartupItems
        tempSearchArray = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                              NSUserDomainMask | NSLocalDomainMask,
                                                              YES);
        e = [tempSearchArray objectEnumerator];
        while ((currentObject = [e nextObject])) {
            [tempArray addObject:[currentObject stringByAppendingPathComponent:@"Preferences"]];
            [tempArray addObject:[currentObject stringByAppendingPathComponent:@"StartupItems"]];
        }
        
        // Application Support
        [tempArray addObjectsFromArray:NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask | NSLocalDomainMask, YES)];
        
        // Cache
        [tempArray addObjectsFromArray:NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask | NSLocalDomainMask, YES)];
        
        libraryPaths = [[NSSet alloc] initWithArray:tempArray];
        
        [tempArray release];
        
        // Create an empty whitelist
        whitelist = [[NSMutableSet alloc] init];
        
        // Register for changes to the trash
        [self registerForWriteNotifications];
		
		//Set up the update timer for automatic updates

//		NSString *beginning;
//		NSArray *temp;
//		NSString *prefPanePlist = [[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent];
//		prefPanePlist = [[prefPanePlist stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
//		prefPanePlist = [[NSBundle bundleWithPath:prefPanePlist] bundleIdentifier];
//		prefPanePlist = [prefPanePlist stringByAppendingPathExtension:@"plist"];
//		e = [libraryPaths objectEnumerator];
//		//Get from the libraryPaths the user's Preferences directory
//		while (currentObject = [e nextObject]) {
//			//Use the User's preferences directory
//			if (![currentObject isEqualToString:@"/Library/Preferences"] && [[currentObject lastPathComponent] isEqualToString:@"Preferences"]) {
//				beginning = (NSString*)currentObject;
//				temp = [[NSFileManager defaultManager] directoryContentsAtPath:currentObject];
//				continue;
//			}
//		}
//		
//		NSString *filePath;
//		NSDictionary *prefPanePreferences;
//		id currentObject2;
//		e = [temp objectEnumerator];
//		//Search through the User's Preferences directory for the
//		//AppTrap prefpane's plist and load it into an NSDictionary object
//		while (currentObject2 = [e nextObject]) {
//			if ([currentObject2 isEqualToString:prefPanePlist]) {
//				filePath = [beginning stringByAppendingPathComponent:currentObject2];
//				prefPanePreferences = [NSDictionary dictionaryWithContentsOfFile:filePath];
//			}
//		}
//		
//		//start automatically checking for updates based on the prefpane preference's
//		//value for the SUEnableAutomaticChecks key
//		if ([[prefPanePreferences objectForKey:@"SUEnableAutomaticChecks"] boolValue]) {
//			[self startAutomaticallyCheckingForUpdates];
//		}
		
        // Setup default preferences
        NSDictionary *appDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithBool:NO], ATPreferencesIsExpanded,
            nil];
        [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
        
        // Register for notifications from the prefpane
        NSDistributedNotificationCenter *nc = [NSDistributedNotificationCenter defaultCenter];
        [nc addObserver:self
               selector:@selector(terminateAppTrap:)
                   name:ATApplicationShouldTerminateNotification
                 object:nil
     suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
		
		[nc addObserver:self
			   selector:@selector(sendVersion) 
				   name:ATApplicationSendVersionData 
				 object:nil
	 suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
		
		[nc addObserver:self
			   selector:@selector(automaticallyCheckForUpdates:)
				   name:ATApplicationAutomaticallyCheckForUpdates
				 object:nil
	 suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
	}
    
    return self;
}

- (void)awakeFromNib
{
    // Restore the expanded state of the window
    [self setExpanded:[[NSUserDefaults standardUserDefaults] boolForKey:ATPreferencesIsExpanded]];
    
    // Fill the text and button placeholders with localized text
    [dialogueText1 setStringValue:NSLocalizedString(@"You are moving an application to the trash, do you want to move its associated system files too?", @"")];
    [dialogueText2 setStringValue:NSLocalizedString(@"No files will be deleted until you empty the trash.", @"")];
    [leaveButton setTitle:NSLocalizedString(@"Leave files", @"")];
    [moveButton setTitle:NSLocalizedString(@"Move files", @"")];
    
    // Fix size and position for all elements
    // Some code from: http://www.cocoabuilder.com/archive/message/cocoa/2002/6/18/62576
    
    // First text field
    NSRect newFrame = [dialogueText1 frame];
    newFrame.size.height = 10000.0; // an arbitrary large number
    newFrame.size = [[dialogueText1 cell] cellSizeForBounds:newFrame];
    newFrame.origin.y = [[mainWindow contentView] frame].size.height - newFrame.size.height - 20;
    [dialogueText1 setFrame:newFrame];
    
    // Second text field
    newFrame = [dialogueText2 frame];
    newFrame.size.height = 10000.0; // an arbitrary large number
    newFrame.size = [[dialogueText2 cell] cellSizeForBounds:newFrame];
    newFrame.origin.y = [dialogueText1 frame].origin.y - newFrame.size.height - 8;
    [dialogueText2 setFrame:newFrame];
    
    // Default button
    [moveButton sizeToFit];
    newFrame = [moveButton frame];
    newFrame.size.width += 12; // To compensate for the somewhat broken sizeToFit method
    newFrame.origin.x = [mainWindow frame].size.width - newFrame.size.width - 14;
    newFrame.origin.y = [dialogueText2 frame].origin.y - newFrame.size.height - 8;
    [moveButton setFrame:newFrame];
    
    // Cancel button
    [leaveButton sizeToFit];
    newFrame = [leaveButton frame];
    newFrame.size.width += 12; // To compensate for the somewhat broken sizeToFit method
    newFrame.origin.x = [moveButton frame].origin.x - newFrame.size.width;
    newFrame.origin.y = [moveButton frame].origin.y;
    [leaveButton setFrame:newFrame];
    
    // Disclosure triangle
    newFrame = [disclosureTriangle frame];
    newFrame.origin.y = [dialogueText2 frame].origin.y - newFrame.size.height - 13;
    [disclosureTriangle setFrame:newFrame];
    
    // File list
    newFrame = [filelistView frame];
    newFrame.origin.y = [moveButton frame].origin.y - newFrame.size.height - 12;
    [filelistView setFrame:newFrame];
    
    // And finally, the window itself
    newFrame = [mainWindow frame];
    newFrame.size.height = 20 + [dialogueText1 frame].size.height + 8 + [dialogueText2 frame].size.height + 8 + [moveButton frame].size.height + 20 + 14;
    if (isExpanded)
        newFrame.size.height += [filelistView frame].size.height + 20;
    [mainWindow setFrame:newFrame display:NO];

	[self startAutomaticallyCheckingForUpdates];
}

- (void)sendVersion {
	NSDistributedNotificationCenter *nc = [NSDistributedNotificationCenter defaultCenter];
	NSDictionary *version = [NSDictionary dictionaryWithObject:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"] 
														forKey:ATBackgroundProcessVersion];
	//NSLog(@"sendVersion");
	
	[nc postNotificationName:ATApplicationGetVersionData 
					  object:nil 
					userInfo:version 
		  deliverImmediately:YES];
}

// A dealloc method is not needed since our only instance of
// ATApplicationController will always be dealloced at the same time
// as the application is quit, which releases all memory anyway. In
// fact, a dealloc here wouldn't even be called.

- (void)registerForWriteNotifications
{
    static BOOL inited = NO;
    
    if (!inited) {
        // Register for changes to the trash
        [[UKKQueue sharedFileWatcher] addPathToQueue:pathToTrash];
    }
    
    NSNotificationCenter *nc = [[NSWorkspace sharedWorkspace] notificationCenter];
    [nc addObserver:self
           selector:@selector(handleWriteNotification:)
               name:UKFileWatcherWriteNotification
             object:nil];
}

- (void)unregisterForWriteNotifications
{
    NSNotificationCenter *nc = [[NSWorkspace sharedWorkspace] notificationCenter];
    [nc removeObserver:self];
}

// Return all applications currently in the trash, as an array
// TODO: Can this method be incorporated in handleWriteNotification: to speed things up?
- (NSArray *)applicationsInTrash
{
    NSMutableArray *applicationsInTrash = [NSMutableArray array];
    
    if (pathToTrash && ![pathToTrash isEqualToString:@""]) {
        NSFileManager *manager = [NSFileManager defaultManager];
        if ([manager fileExistsAtPath:pathToTrash]) {
            NSDirectoryEnumerator *e = [manager enumeratorAtPath:pathToTrash];
            NSString *currentFilename = nil;
            
            // Use a little trick found at: http://www.cocoadev.com/index.pl?NSDirectoryEnumerator
            // For more information: http://www.wodeveloper.com/omniLists/macosx-dev/2002/June/msg00353.html
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            
            while ((currentFilename = [e nextObject])) {
                if ([currentFilename hasSuffix:@".app"])
                    [applicationsInTrash addObject:currentFilename];
                
                [pool release];
                pool = [[NSAutoreleasePool alloc] init];
            }
            
            [pool release];
            pool = nil;
        }
    }
    
    return applicationsInTrash;
}

- (void)handleWriteNotification:(NSNotification *)notification
{
    NSEnumerator *e = [[self applicationsInTrash] objectEnumerator];
    NSString *currentFilename = nil;
    
    while ((currentFilename = [e nextObject])) {
        // Is it on the whitelist?
        if ([whitelist containsObject:currentFilename])
            continue;
        
        // If it's in the applications folder, it was probably auto-updated by Sparkle
        // XXX: Currently only works for applications in root (not apps in folders), we could of course recurse with an NSDirectoryEnumerator but that would be _reeeeally_ slow since this method is called very often
        NSFileManager *manager = [NSFileManager defaultManager];
        NSEnumerator *applicationPathsEnumerator = [applicationsPaths objectEnumerator];
        id currentApplicationPath = nil;
        
        while ((currentApplicationPath = [applicationPathsEnumerator nextObject])) {
            if ([manager fileExistsAtPath:[currentApplicationPath stringByAppendingPathComponent:currentFilename]]) {
                // Add it to the whitelist
                [whitelist addObject:currentFilename];
            }
        }
        
        // Now, check again for safety
        if ([whitelist containsObject:currentFilename])
            continue;
        
        NSLog(@"I just trapped the application %@!", currentFilename);
        
		NSLog(@"whitelist before: %@", whitelist);
        // Add it to the whitelist
        [whitelist addObject:currentFilename];
		NSLog(@"whitelist after: %@", whitelist);
        
        // Get the full path of the trapped application
        NSString *fullPath = [pathToTrash stringByAppendingPathComponent:currentFilename];
        
        // Get the applications's bundle and its identifier
        NSBundle *appBundle = [NSBundle bundleWithPath:fullPath];
        NSString *preferenceFileName = [[appBundle bundleIdentifier] stringByAppendingPathExtension:@"plist"];
        
        // Get the application's true name (i.e. not the filename)
        NSString *appName = [appBundle objectForInfoDictionaryKey:@"CFBundleName"];
        
        // Let's find some system files
        NSMutableSet *matches = [[NSMutableSet alloc] init];
        NSEnumerator *libraryEnumerator = [libraryPaths objectEnumerator];
        id currentLibraryPath = nil;
        
        while ((currentLibraryPath = [libraryEnumerator nextObject])) {
            [matches addObjectsFromArray:[self matchesForFilename:preferenceFileName atPath:currentLibraryPath]];
            [matches addObjectsFromArray:[self matchesForFilename:appName atPath:currentLibraryPath]];
        }
        
        // TODO: Test performance of this
        // Get a snapshot of our matches so that we can remove objects from matches while enumerating
        NSEnumerator *matchesEnumerator = [[matches allObjects] objectEnumerator];
        id currentObject = nil;
        while (currentObject = [matchesEnumerator nextObject]) {
            [listController addPathForDeletion:currentObject];
            [matches removeObject:currentObject];
        }
        
        [matches release];
    }
    
    // Open up the window if we got any hits
    if ([[listController arrangedObjects] count] > 0) {
        [NSApp activateIgnoringOtherApps:YES];
        [NSApp runModalForWindow:mainWindow];
    }
    
    // Clear the whitelist if the trash is empty, i.e an "Empty trash"
    // operation was just finished
    if ([self numberOfVisibleItemsInTrash] == 0)
        [whitelist removeAllObjects];
}

- (int)numberOfVisibleItemsInTrash
{
    int count = 0;
    NSDirectoryEnumerator *e = [[NSFileManager defaultManager] enumeratorAtPath:pathToTrash];
    NSString *currentObject = nil;
    
    // See the method applicationsInTrash for an explanation of this technique
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    while ((currentObject = [e nextObject])) {
        if (![currentObject hasPrefix:@"."])
            count++;
        
        [pool release];
        pool = [[NSAutoreleasePool alloc] init];
    }
    
    [pool release];
    pool = nil;
    
    return count;
}

// Part of code from http://www.borkware.com/quickies/single?id=130
// TODO: Seems like were leaking NSConcreteTask and NSConcretePipe here, needs to be investigated
- (NSArray *)matchesForFilename:(NSString *)filename atPath:(NSString *)path
{
	NSLog(@"filename: %@", filename);
    if (!filename || !path)
        return [NSArray array];
    
    // Do not ever allow empty strings
    if ([filename isEqualToString:@""] || [path isEqualToString:@""])
        return [NSArray array];
    
    // Find all the matching files at the given path
    NSString *command = [NSString stringWithFormat:@"find '%@' -name '%@' -maxdepth 1", [path stringByExpandingTildeInPath], filename];
    
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath: @"/bin/sh"];
    [task setArguments: [NSArray arrayWithObjects:@"-c", command, nil]];
    
    NSPipe *pipe  = [NSPipe pipe];
    [task setStandardOutput: pipe];
    NSFileHandle *file = [pipe fileHandleForReading];
    
    [task launch];
    
    NSData *data = [file readDataToEndOfFile];
    NSString *string = [[NSString alloc] initWithData:data
                                             encoding:NSUTF8StringEncoding];
    NSArray *matches = [string componentsSeparatedByString:@"\n"];
    
    [task waitUntilExit];
    [task release];
    [string release];
    
    return matches;
}

- (IBAction)moveCurrentItemsToTrash:(id)sender
{
    // Close the window
    [NSApp stopModal];
    [mainWindow orderOut:self];
    
    // First, unregister for further notifications until done
    [self unregisterForWriteNotifications];
    
    id currentItem = nil;
    NSLog(@"listController before: %@ \n\n", [listController arrangedObjects]);
    while ([[listController arrangedObjects] count] > 0) {
        // Pick the first object in the list
        currentItem = [[listController arrangedObjects] objectAtIndex:0];
		NSLog(@"currentItem: %@", currentItem);
		NSLog(@"currentItem class: %@", [currentItem class]);
        
        // Check if this item should be removed
        if ([[currentItem valueForKey:@"shouldBeRemoved"] boolValue] == YES) {
            // Move the item to the trash
            NSString *sourcePath = [currentItem valueForKey:@"fullPath"];
            NSString *source = [sourcePath stringByDeletingLastPathComponent];
            NSArray *files = [NSArray arrayWithObject:[sourcePath lastPathComponent]];
			NSInteger tag;
            [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
                                                         source:source
                                                    destination:pathToTrash
                                                          files:files
                                                            tag:&tag];
            
            if (tag >= 0)
                NSLog(@"Successfully moved %@ to trash", sourcePath);
            else
                NSLog(@"Couldn't move %@ to trash (tag = %i)", sourcePath, tag);
        }
        
        // Remove the item from the list
        [listController removeObjectAtArrangedObjectIndex:0];
		
		NSLog(@"listController after: %@ \n\n", [listController arrangedObjects]);
    }
    
    // Now, register for notifications again
    [self registerForWriteNotifications];
}

- (IBAction)cancel:(id)sender
{
    // Empty the list of candidates
    [listController removeObjects:[listController arrangedObjects]];
    
    // Close the window
    [NSApp stopModal];
    [mainWindow orderOut:self];
}

#pragma mark -
#pragma mark Update Checking

- (void)startAutomaticallyCheckingForUpdates {
	NSLog(@"startAutomaticallyCheckingForUpdates");
	[atUpdateChecker checkForUpdate];
}

//Called via the distributed notification system, when the Automatically Check for Updates
//checkbox is clicked
- (void)automaticallyCheckForUpdates:(NSNotification*)notification {
	NSLog(@"automaticallyCheckForUpdates:");
	NSDictionary *userInfo = [notification userInfo];
	NSLog(@"shouldAutomaticallyCheckForUpdates: %d", [[userInfo objectForKey:ATShouldAutomaticallyCheckForUpdates] boolValue]);
	
	if ([[userInfo objectForKey:ATShouldAutomaticallyCheckForUpdates] boolValue]) {
		[atUpdateChecker checkForUpdate];
	} else {
		[atUpdateChecker stopCheckForUpdate];
	}
}

#pragma mark -
#pragma mark Window resizing

// TODO: This stuff is just plain ugly and probably error prone

- (IBAction)toggleFilelist:(id)sender
{
    // Show/hide the filelist
    [self setExpanded:([sender state] == NSOnState)];
}

- (void)extendMainWindowBy:(int)amount
{
    // Extends the main window vertically by the amount (which can be negative)
    NSRect newFrame = [mainWindow frame];
    newFrame.size.height += amount;
    newFrame.origin.y -= amount;
    
    [mainWindow setFrame:newFrame display:YES animate:YES];
}

- (void)setExpanded:(BOOL)flag
{
    // Expand or contract the window
    if (isExpanded != flag) {
        isExpanded = flag;
        
        if (isExpanded)
            [self extendMainWindowBy:kWindowExpansionAmount];
        else
            [self extendMainWindowBy:-kWindowExpansionAmount];
    }
}

#pragma mark -
#pragma mark Application delegate methods

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Add any applications already in the trash to the whitelist to avoid confusion
    [whitelist addObjectsFromArray:[self applicationsInTrash]];
    
    // Post distributed notification for the prefpane
    NSDistributedNotificationCenter *nc = [NSDistributedNotificationCenter defaultCenter];
    [nc postNotificationName:ATApplicationFinishedLaunchingNotification
                      object:nil
                    userInfo:nil
          deliverImmediately:YES];
}

- (void)terminateAppTrap:(NSNotification *)aNotification
{
    // The prefpane wants us to quit, so let's quit
    [[NSApplication sharedApplication] terminate:self];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    // Post distributed notification for the prefpane
    NSDistributedNotificationCenter *nc = [NSDistributedNotificationCenter defaultCenter];
    [nc postNotificationName:ATApplicationTerminatedNotification
                      object:nil
                    userInfo:nil
          deliverImmediately:YES];
}

@end
