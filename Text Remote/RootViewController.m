//
//  RootViewController.m
//  Text Remote
//
//  Created by Spencer Whyte on 11-05-09.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "RootViewController.h"

@implementation RootViewController

- (void)viewDidLoad
{
    server = [[HTTPServer alloc] init];
    [server setType:@"_http._tcp."];
    [server setName:@"Text Remote"];
    [server setDocumentRoot:[NSURL URLWithString:@"/"]];
    [server setRootViewController:self];
    //	[server setDelegate:self];
    
    NSError *startError = nil;
    if (![server start:&startError] ) {
        NSLog(@"Error starting server: %@", startError);
    } else {
        NSLog(@"Starting server on port %d", [server port]);
    }
	code[0] = rand()%9+1;
    code[1] = rand()%9+1;
    code[2] = rand()%9+1;
    code[3] = rand()%9+1;
    toList = [[NSMutableArray alloc] init];
    messageList = [[NSMutableArray alloc] init];

    switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
    [switchView setOn:NO animated:NO];
    [switchView addTarget:self action:@selector(securityChanged:) forControlEvents:UIControlEventValueChanged];


    
    
    
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
  
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

-(void)securityChanged:(id)sender{

    if(!switchView.on){
         NSMutableArray * stuff= [[NSMutableArray alloc] init];
         NSIndexPath * path = [NSIndexPath indexPathForRow:1 inSection:0];
           [stuff addObject:path];
         [self.tableView deleteRowsAtIndexPaths:stuff withRowAnimation:UITableViewRowAnimationTop];
    }else{
        NSMutableArray * stuff= [[NSMutableArray alloc] init];
        NSIndexPath * path = [NSIndexPath indexPathForRow:1 inSection:0];
        [stuff addObject:path];
        [self.tableView insertRowsAtIndexPaths:stuff withRowAnimation:UITableViewRowAnimationTop];

    }
   
    
    
}

-(BOOL)securityEnabled{
    return switchView.on;
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result{
    [toList removeObjectAtIndex:0];
    [messageList removeObjectAtIndex:0];
    if([toList count] != 0){
          [controller dismissModalViewControllerAnimated:NO]; 
    }else{
        [controller dismissModalViewControllerAnimated:YES];   
    }
    if([toList count]!=0){

        MFMessageComposeViewController *controller2 = [[[MFMessageComposeViewController alloc] init] autorelease];
        if([MFMessageComposeViewController canSendText])
        {
       
            controller2.body = [messageList objectAtIndex:0];
            
            controller2.recipients = [[toList objectAtIndex:0] componentsSeparatedByString:@","];
            controller2.messageComposeDelegate = self;
            [self presentModalViewController:controller2 animated:YES];
      
            
        }

    }
}




-(void)sendMessage:(NSString*)to andMessage:(NSString*)message{
    
    if([toList count] == 0){
        MFMessageComposeViewController *controller = [[[MFMessageComposeViewController alloc] init] autorelease];
        if([MFMessageComposeViewController canSendText])
        {
            controller.body = message;
            controller.recipients = [to componentsSeparatedByString:@","];
            controller.messageComposeDelegate = self;
            [self presentModalViewController:controller animated:YES];
        
        }
    }
    [toList addObject:to];
    [messageList addObject:message];

}
- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

/*
 // Override to allow orientations other than the default portrait orientation.
 - (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
 // Return YES for supported orientations.
 return (interfaceOrientation == UIInterfaceOrientationPortrait);
 }
 */

// Customize the number of sections in the table view.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if(section==0){
        if(switchView.on){
            return 2;
        }else{
            return 1;
        }
    }else{
        return 1;
    }
}

-(NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    if(section == 0){
    return @"Access code";
    }
    return @"Web Address";
}

-(int*)getPointerToCode{
    return code;
}
// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    static NSString *CellIdentifier2 = @"Cell2";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
      UITableViewCell *cell2 = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    if (cell2 == nil) {
        cell2 = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier2] autorelease];
    }
    if([indexPath indexAtPosition:0] == 0){
        if([indexPath indexAtPosition:1] == 1){
        cell2.textLabel.text = [NSString stringWithFormat:@"%d%d%d%d", code[0],code[1],code[2],code[3]];
  
        
        cell2.detailTextLabel.text = @"Tap to change";
            
            return cell2;
        }else if([indexPath indexAtPosition:1] == 0){
            cell.textLabel.text=@"Security Code:";

            cell.accessoryView = switchView;
            return cell;
        }
    }else{
    
        cell.textLabel.text = [NSString stringWithFormat:@"http://%@:%d", [server getIP], [server port]];
        cell.textLabel.textAlignment = UITextAlignmentCenter;
        [cell setUserInteractionEnabled:NO];
    }
    return cell;

}

/*
 // Override to support conditional editing of the table view.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
 {
 // Return NO if you do not want the specified item to be editable.
 return YES;
 }
 */

/*
 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
 {
 if (editingStyle == UITableViewCellEditingStyleDelete) {
 // Delete the row from the data source.
 [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
 } else if (editingStyle == UITableViewCellEditingStyleInsert) {
 // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
 }   
 }
 */

/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
 {
 }
 */

/*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
 {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    code[0] = rand()%9+1;
    code[1] = rand()%9+1;
    code[2] = rand()%9+1;
    code[3] = rand()%9+1;
    [tableView reloadData];
    
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
}

- (void)dealloc {
    
    [super dealloc];
}

@end
