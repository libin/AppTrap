//
//  ATSUUpdater.h
//  AppTrapPreferencePane
//
//  Created by Kumaran Vijayan on 13/07/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Sparkle/Sparkle.h>

@interface ATSUUpdater : SUUpdater {

}
+(id)sharedUpdater;
-(id)init;
@end
