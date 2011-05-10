//
//  Text_RemoteAppDelegate.h
//  Text Remote
//
//  Created by Spencer Whyte on 11-05-09.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface Text_RemoteAppDelegate : NSObject <UIApplicationDelegate> {
@private

    UINavigationController *navigationController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;

@property (nonatomic, retain) IBOutlet UINavigationController *navigationController;

@end
