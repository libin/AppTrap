//
//  ATSUUpdater.m
//  AppTrapPreferencePane
//
//  Created by Kumaran Vijayan on 13/07/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "ATSUUpdater.h"


@implementation ATSUUpdater
+(id)sharedUpdater {
	return [self updaterForBundle:[NSBundle bundleForClass:[self class]]];
}

-(id)init {
	return [self initForBundle:[NSBundle bundleForClass:[self class]]];
}
@end
