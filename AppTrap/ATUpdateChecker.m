//
//  ATUpdateChecker.m
//  AppTrap
//
//  Created by Kumaran Vijayan on 09-12-29.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "ATUpdateChecker.h"


@implementation ATUpdateChecker

- (id)init {
	if (self = [super init]) {
		updateTimerTimeInterval = 5;
	}
	return self;
}

- (void)awakeFromNib {
	NSLog(@"awakeFromNib");
}

- (void)checkForUpdate {
	NSLog(@"checkForUpdate");
	NSDate *date = [NSDate date];
	NSLog(@"%@", [date description]);
	[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:ATPreferencesLastUpdateCheck];
	
	//Actual update checking code goes here...
	NSLog(@"Beginning update check...");
	
//	NSDictionary *dict = [[NSBundle mainBundle] infoDictionary];
//	NSString *path = [dict objectForKey:@"AppTrapAutomaticUpdateCheckURL"];
	NSString *path = @"http://onnati.net/apptrap/AppTrapUpdateTesting.xml";
	NSURL *fileURL = [NSURL URLWithString:path];
	NSXMLDocument *xmlDocument = [[NSXMLDocument alloc] initWithContentsOfURL:fileURL 
																	  options:NSXMLDocumentTidyXML
																		error:nil];
	
	NSXMLElement *root = [xmlDocument rootElement];
	NSXMLNode *tempNode = root;
	BOOL newerVersionExists = NO;
	NSInteger versionNumber = [self getVersionNumber];
	NSArray *systemVersion = [self getSystemVersion];
	
	while (tempNode = [tempNode nextNode]) {
		if ([[tempNode name] isEqualToString:@"enclosure"]) {
			NSEnumerator *attributeEnum = [[(NSXMLElement*)tempNode attributes] objectEnumerator];
			NSXMLNode *attribute;
			
			while (attribute = [attributeEnum nextObject]) {
				if ([[attribute name] isEqualToString:@"sparkle:version"]) {
					NSLog(@"%@", [attribute stringValue]);
					if ([[attribute stringValue] integerValue] > versionNumber) {
						NSLog(@"Newer version exists");
						newerVersionExists = YES;
					}
				}
			}
		}
		
		if ([[tempNode name] isEqualToString:@"sparkle:releaseNotesLink"] && newerVersionExists) {
			NSLog(@"sparkle:releaseNotesLink:");
			NSLog(@"%@", [tempNode stringValue]);
			NSString *releaseNotesURL = [tempNode stringValue];
			newerVersionExists = NO;
			
			NSLog(@"TEST");
			NSURL *url = [NSURL URLWithString:releaseNotesURL];
			NSLog(@"TEST2");
			NSURLRequest *urlRequest = [NSURLRequest requestWithURL:url];
			NSLog(@"TEST3");
			NSLog(@"webView mainFrame: %@", [webView mainFrame]);
			[[webView mainFrame] loadRequest:urlRequest];
			[updateWindow makeKeyAndOrderFront:nil];
			continue;
		}
	}
}

- (void)stopCheckForUpdate {
	NSLog(@"stopCheckForUpdate");
	[updateTimer invalidate];
}

- (NSInteger)getVersionNumber {
	NSLog(@"getVersionNumber");
	NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
	NSString *versionString = [infoDictionary objectForKey:@"CFBundleVersion"];
	NSInteger versionInteger = [versionString integerValue];
	return versionInteger;
}

- (NSArray*)getSystemVersion {
	static SInt32 major, minor, bugfix;
	Gestalt(gestaltSystemVersionMajor, &major);
	Gestalt(gestaltSystemVersionMinor, &minor);
	Gestalt(gestaltSystemVersionBugFix, &bugfix);
	NSNumber *majorNumber = [[NSNumber alloc] initWithInt:major];
	NSNumber *minorNumber = [[NSNumber alloc] initWithInt:minor];
	NSNumber *bugfixNumber = [[NSNumber alloc] initWithInt:bugfix];
	NSArray *array = [[NSArray alloc] initWithObjects:majorNumber, minorNumber, bugfixNumber, nil];
	return array;
}

#pragma mark -
#pragma mark Interface Actions

- (IBAction)cancel:(id)sender {
	NSLog(@"cancel:");
	[updateWindow close];
}

- (IBAction)skipUpdate:(id)sender {
	NSLog(@"skipUpdate:");
	[updateWindow close];
}

- (IBAction)installUpdate:(id)sender {
	NSLog(@"installUpdate:");
	[updateWindow close];
}

@end
