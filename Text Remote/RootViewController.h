//
//  RootViewController.h
//  Text Remote
//
//  Created by Spencer Whyte on 11-05-09.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HTTPServer.h"

#import <MessageUI/MFMessageComposeViewController.h>
@class HTTPServer;
@interface RootViewController : UITableViewController<MFMessageComposeViewControllerDelegate> {
@private

    HTTPServer *server;
 

    int code[4];
    
    NSMutableArray * toList;
    NSMutableArray * messageList;
    UISwitch *switchView ;
    
}

-(BOOL)securityEnabled;
-(int*)getPointerToCode;
-(void)sendMessage:(NSString*)to andMessage:(NSString*)message;
- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result;
@end
