//
//  StaffDetailTableViewController.m
//  StaffRoster
//
//  Created by yavuz on 5/23/13.
//  Copyright (c) 2013 redhat. All rights reserved.
//

#import "StaffDetailTableViewController.h"
#import "StaffRosterAPIClient.h"
#import "EmployeeSearchViewController.h"

@interface StaffDetailTableViewController ()

@end

@implementation StaffDetailTableViewController {
    NSArray *_response_employee;
    bool _load_mutex;
    NSInteger numOfDreports;
}

@synthesize person;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _load_mutex = true;
    numOfDreports = 0;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(popToRoot:)];
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    UISwipeGestureRecognizer *fingerSwipeLeft = [[UISwipeGestureRecognizer alloc]
                                                     initWithTarget:self
                                                     action:@selector(fingerSwipeLeft:)];
    [fingerSwipeLeft setDirection:UISwipeGestureRecognizerDirectionLeft];
    [[self view] addGestureRecognizer:fingerSwipeLeft];
    
    UISwipeGestureRecognizer *fingerSwipeRight = [[UISwipeGestureRecognizer alloc]
                                                 initWithTarget:self
                                                 action:@selector(fingerSwipeRight:)];
    [fingerSwipeRight setDirection:UISwipeGestureRecognizerDirectionRight];
    [[self view] addGestureRecognizer:fingerSwipeRight];
    
    
    UISwipeGestureRecognizer *fingerSwipeUp = [[UISwipeGestureRecognizer alloc]
                                                 initWithTarget:self
                                                 action:@selector(fingerSwipeUp:)];
    [fingerSwipeUp setNumberOfTouchesRequired:2];
    [fingerSwipeUp setDirection:UISwipeGestureRecognizerDirectionRight];
    [[self view] addGestureRecognizer:fingerSwipeUp];
    
    
    UISwipeGestureRecognizer *fingerSwipeDown = [[UISwipeGestureRecognizer alloc]
                                                 initWithTarget:self
                                                 action:@selector(fingerSwipeDown:)];
    [fingerSwipeDown setNumberOfTouchesRequired:2];
    [fingerSwipeDown setDirection:UISwipeGestureRecognizerDirectionLeft];
    [[self view] addGestureRecognizer:fingerSwipeDown];
    
    
    // load number of direct reports, no need to hold lock
    [self loadNumberOfDReports];
}

- (void)loadNumberOfDReports {
    [[StaffRosterAPIClient sharedInstance].dreportsPipe readWithParams:[[NSMutableDictionary alloc] initWithDictionary:@{@"dreport": [person objectForKey:@"cn"], @"count":@"req"}] success:^(id responseObject) {
        NSLog(@"Response dreports count: %@", responseObject);
        numOfDreports = ([[responseObject objectAtIndex:0] objectForKey:@"count"] != [NSNull null])?[[[responseObject objectAtIndex:0] objectForKey:@"count"] integerValue]:0;
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
    } failure:^(NSError *error) {
        NSLog(@"An error has occured during read! \n%@", error);
    }];
}

- (IBAction)popToRoot:(id)sender {
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)fingerSwipeLeft:(UITapGestureRecognizer *)recognizer {
    // Insert your own code to handle swipe left
    NSUInteger touches = recognizer.numberOfTouches;
    switch (touches) {
        case 1:
            break;
        case 2:
            break;
        case 3:
            break;
        default:
            break;
    }
    [self loadDReports];
    NSLog(@"swiped left. %d touches.", touches);
}

- (void)fingerSwipeRight:(UITapGestureRecognizer *)recognizer {
    // Insert your own code to handle swipe left
    NSUInteger touches = recognizer.numberOfTouches;
    switch (touches) {
        case 1:
            break;
        case 2:
            break;
        case 3:
            break;
        default:
            break;
    }
    [self loadManager];
    NSLog(@"swiped right. %d touches.", touches);
}

- (void)fingerSwipeUp:(UITapGestureRecognizer *)recognizer {
    // Insert your own code to handle swipe left
    NSUInteger touches = recognizer.numberOfTouches;
    switch (touches) {
        case 1:
            break;
        case 2:
            break;
        case 3:
            break;
        default:
            break;
    }
    [self loadColleagues:kCATransitionFromLeft];
    NSLog(@"swiped up. %d touches.", touches);
}

- (void)fingerSwipeDown:(UITapGestureRecognizer *)recognizer {
    // Insert your own code to handle swipe left
    NSUInteger touches = recognizer.numberOfTouches;
    switch (touches) {
        case 1:
            break;
        case 2:
            break;
        case 3:
            break;
        default:
            break;
    }
    [self loadColleagues:kCATransitionFromRight];
    NSLog(@"swiped down. %d touches.", touches);
}

- (void)loadManager {
    if (!_load_mutex) {
        return;
    }
    _load_mutex = false;
    if (!person) {
        _load_mutex = true;
        return;
    }
    // fetch the data
    [[StaffRosterAPIClient sharedInstance].managerPipe readWithParams:[[NSMutableDictionary alloc] initWithDictionary:@{@"manager": [person objectForKey:@"cn"]}] success:^(id responseObject) {
        _response_employee = responseObject;
        NSLog(@"Response manager: %@", _response_employee);
        // update table with the newly fetched data
        if ([_response_employee count]) {
            CATransition* transition = [CATransition animation];
            transition.duration = 0.4f;
            transition.type = kCATransitionMoveIn;
            transition.subtype = kCATransitionFromBottom;
            [self.navigationController.view.layer addAnimation:transition
                                                        forKey:kCATransition];
            
            StaffDetailTableViewController *detailViewController = [[StaffDetailTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
            detailViewController.person = [_response_employee objectAtIndex:0];
            
            /*[UIView animateWithDuration:0.75
                             animations:^{
                                 [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
                                 [self.navigationController pushViewController:detailViewController animated:NO];
                                 [UIView setAnimationTransition:UIViewAnimationTransitionCurlDown forView:self.navigationController.view cache:NO];
                             }];*/
            [self.navigationController pushViewController:detailViewController animated:NO];
            _load_mutex = true;
        } else {
            UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Oops!"
                                                              message:@"No manager found..."
                                                             delegate:nil
                                                    cancelButtonTitle:@"OK"
                                                    otherButtonTitles:nil];
            [message show];
        }
        
    } failure:^(NSError *error) {
        NSLog(@"An error has occured during read! \n%@", error);
        _load_mutex = true;
    }];

}

- (void)loadColleagues:(NSString *)subtype {
    if (!_load_mutex) {
        return;
    }
    _load_mutex = false;
    if (!person) {
        _load_mutex = true;
        return;
    }
    // fetch the data
    [[StaffRosterAPIClient sharedInstance].colleaguesPipe readWithParams:[[NSMutableDictionary alloc] initWithDictionary:@{@"colleague": [person objectForKey:@"cn"]}] success:^(id responseObject) {
        NSLog(@"Response colleagues: %@", responseObject);
        CATransition* transition = [CATransition animation];
        transition.duration = 0.4f;
        transition.type = kCATransitionReveal;
        transition.subtype = subtype;
        [self.navigationController.view.layer addAnimation:transition
                                                    forKey:kCATransition];
        EmployeeSearchViewController *detailViewController = [[EmployeeSearchViewController alloc] initWithStyle:UITableViewStyleGrouped];
        detailViewController.employees = responseObject;
        detailViewController.titleName = [person objectForKey:@"cn"];
        detailViewController.pageType = kEmployeeSearchViewPageTypeColleagues;
        detailViewController.load_with_no_search_bar = true;
        [self.navigationController pushViewController:detailViewController animated:NO];
        _load_mutex = true;
    } failure:^(NSError *error) {
        NSLog(@"An error has occured during read! \n%@", error);
        _load_mutex = true;
    }];
    
}

- (void)loadDReports {
    if (!_load_mutex) {
        return;
    }
    _load_mutex = false;
    if (!person) {
        _load_mutex = true;
        return;
    }
    // fetch the data
    [[StaffRosterAPIClient sharedInstance].dreportsPipe readWithParams:[[NSMutableDictionary alloc] initWithDictionary:@{@"dreport": [person objectForKey:@"cn"]}] success:^(id responseObject) {
        NSLog(@"Response dreports: %@", responseObject);
        CATransition* transition = [CATransition animation];
        transition.duration = 0.4f;
        transition.type = kCATransitionMoveIn;
        transition.subtype = kCATransitionFromTop;
        [self.navigationController.view.layer addAnimation:transition
                                                    forKey:kCATransition];
        EmployeeSearchViewController *detailViewController = [[EmployeeSearchViewController alloc] initWithStyle:UITableViewStyleGrouped];
        detailViewController.employees = responseObject;
        detailViewController.titleName = [person objectForKey:@"cn"];
        detailViewController.pageType = kEmployeeSearchViewPageTypeDReports;
        detailViewController.load_with_no_search_bar = true;
        /*[UIView animateWithDuration:0.75
                         animations:^{
                             [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
                             [self.navigationController pushViewController:detailViewController animated:NO];
                             [UIView setAnimationTransition:UIViewAnimationTransitionCurlUp forView:self.navigationController.view cache:NO];
                         }];*/
        [self.navigationController pushViewController:detailViewController animated:NO];
        _load_mutex = true;
    } failure:^(NSError *error) {
        NSLog(@"An error has occured during read! \n%@", error);
        _load_mutex = true;
    }];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return ([person objectForKey:@"telephonenumber"] != [NSNull null])?(([person objectForKey:@"title"] != [NSNull null])?5:4):(([person objectForKey:@"title"] != [NSNull null])?4:3);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0 && numOfDreports > 0) {
        return [[NSString alloc] initWithFormat:@"%d direct reports", numOfDreports];
    }
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0:
            return @"Name:";
            break;
            
        case 1:
            return ([person objectForKey:@"title"] != [NSNull null])?@"Title:":@"Location:";
            break;
            
        case 2:
            return ([person objectForKey:@"title"] != [NSNull null])?@"Location:":@"e-Mail:";
            break;
            
        case 3:
            return ([person objectForKey:@"title"] != [NSNull null])?@"e-Mail:":@"Phone:";
            break;
            
        case 4:
            return @"Phone:";
            break;
            
        default:
            return @"";
            break;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [self.navigationController setNavigationBarHidden:NO animated:YES];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell...
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if (!person) {
        cell.textLabel.text = @"ERROR";
        return cell;
    }
    
    switch (indexPath.section) {
        case 0:
            cell.textLabel.text =  [person objectForKey:@"cn"];
            break;
            
        case 1:
            cell.textLabel.text =  ([person objectForKey:@"title"] != [NSNull null])?[person objectForKey:@"title"]:[person objectForKey:@"rhatlocation"];
            break;
            
        case 2:
            cell.textLabel.text =  ([person objectForKey:@"title"] != [NSNull null])?[person objectForKey:@"rhatlocation"]:[person objectForKey:@"mail"];
            break;
            
        case 3:
            cell.textLabel.text =  ([person objectForKey:@"title"] != [NSNull null])?[person objectForKey:@"mail"]:[person objectForKey:@"telephonenumber"];
            break;
            
        case 4:
            cell.textLabel.text =  [person objectForKey:@"telephonenumber"];
            break;
            
        default:
            break;
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
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
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

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
}

@end
